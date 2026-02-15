#include "decoder.h"

#include <libavutil/time.h>
#include <stdio.h>
#include <string.h>
#include <inttypes.h>

#include "internal.h"

#ifdef __ANDROID__
#include <android/log.h>
#endif

#define RESAMPLE_BUFFER_SIZE (256 * 1024)
static uint8_t resample_buffer[RESAMPLE_BUFFER_SIZE];

static int interrupt_cb(void* ctx) {
  DecoderState* state = (DecoderState*)ctx;
  if (state && state->should_stop) {
    return 1;
  }
  return 0;
}

static void log_callback(void* ptr, int level, const char* fmt, va_list vl) {
  if (level > AV_LOG_WARNING) return;

#ifdef __ANDROID__
  int android_level = ANDROID_LOG_DEBUG;
  if (level <= AV_LOG_ERROR)
    android_level = ANDROID_LOG_ERROR;
  else if (level <= AV_LOG_WARNING)
    android_level = ANDROID_LOG_WARN;
  else if (level <= AV_LOG_INFO)
    android_level = ANDROID_LOG_INFO;

  __android_log_vprint(android_level, "SonicAudioFFmpeg", fmt, vl);
#else
  vprintf(fmt, vl);
#endif
}

static int g_log_callback_registered = 0;

int decoder_open(DecoderState* state, const char* url, const char* headers,
                 int target_sample_rate, int target_channels,
                 int target_format) {
  if (!state || !url) return -1;

  memset(state, 0, sizeof(DecoderState));
  state->audio_stream_idx = -1;

  if (!g_log_callback_registered) {
    av_log_set_callback(log_callback);
    g_log_callback_registered = 1;
  }

  state->fmt_ctx = avformat_alloc_context();
  if (!state->fmt_ctx) return -1;

  state->fmt_ctx->interrupt_callback.callback = interrupt_cb;
  state->fmt_ctx->interrupt_callback.opaque = state;

  AVDictionary* options = NULL;
  if (headers && strlen(headers) > 0) {
    av_dict_set(&options, "headers", headers, 0);
  }
  av_dict_set(&options, "reconnect", "1", 0);
  av_dict_set(&options, "reconnect_streamed", "1", 0);
  av_dict_set(&options, "reconnect_on_network_error", "1", 0);
  av_dict_set(&options, "reconnect_delay_max", "5", 0);
  av_dict_set(&options, "probesize", "10000000", 0);       // 10MB
  av_dict_set(&options, "analyzeduration", "5000000", 0);  // 5s
  av_dict_set(&options, "rw_timeout", "20000000", 0);      // 20s timeout

  int ret = avformat_open_input(&state->fmt_ctx, url, NULL, &options);
  av_dict_free(&options);

  if (ret < 0) {
    char errbuf[128];
    av_strerror(ret, errbuf, sizeof(errbuf));
    av_strerror(ret, errbuf, sizeof(errbuf));
    LOGE("SonicAudio Decoder: Failed to open input: %s\n", errbuf);
    return -1;
  }

  ret = avformat_find_stream_info(state->fmt_ctx, NULL);
  if (ret < 0) {
    LOGE("SonicAudio Decoder: Failed to find stream info\n");
    decoder_close(state);
    return -2;
  }

  for (unsigned int i = 0; i < state->fmt_ctx->nb_streams; i++) {
    if (state->fmt_ctx->streams[i]->codecpar->codec_type ==
        AVMEDIA_TYPE_AUDIO) {
      state->audio_stream_idx = i;
      break;
    }
  }

  if (state->audio_stream_idx < 0) {
    LOGE("SonicAudio Decoder: No audio stream found\n");
    decoder_close(state);
    return -3;
  }

  AVStream* audio_stream = state->fmt_ctx->streams[state->audio_stream_idx];
  AVCodecParameters* codecpar = audio_stream->codecpar;

  const AVCodec* codec = avcodec_find_decoder(codecpar->codec_id);
  if (!codec) {
    LOGE("SonicAudio Decoder: Unsupported codec\n");
    decoder_close(state);
    return -4;
  }

  state->codec_ctx = avcodec_alloc_context3(codec);
  if (!state->codec_ctx) {
    LOGE("SonicAudio Decoder: Failed to allocate codec context\n");
    decoder_close(state);
    return -5;
  }

  ret = avcodec_parameters_to_context(state->codec_ctx, codecpar);
  if (ret < 0) {
    LOGE("SonicAudio Decoder: Failed to copy codec parameters\n");
    decoder_close(state);
    return -6;
  }

  ret = avcodec_open2(state->codec_ctx, codec, NULL);
  if (ret < 0) {
    LOGE("SonicAudio Decoder: Failed to open codec\n");
    decoder_close(state);
    return -7;
  }

  int effective_sample_rate = target_sample_rate > 0
                                  ? target_sample_rate
                                  : state->codec_ctx->sample_rate;

  AVChannelLayout out_ch_layout;
  av_channel_layout_default(&out_ch_layout, target_channels);

  enum AVSampleFormat output_fmt = AV_SAMPLE_FMT_FLT;
  if (target_format == ma_format_s16) {
    output_fmt = AV_SAMPLE_FMT_S16;
  } else if (target_format == ma_format_s32) {
    output_fmt = AV_SAMPLE_FMT_S32;
  }

  ret = swr_alloc_set_opts2(&state->swr_ctx, &out_ch_layout, output_fmt,
                            effective_sample_rate, &state->codec_ctx->ch_layout,
                            state->codec_ctx->sample_fmt,
                            state->codec_ctx->sample_rate, 0, NULL);
  if (ret < 0 || !state->swr_ctx) {
    LOGE("SonicAudio Decoder: Failed to create resampler\n");
    decoder_close(state);
    return -8;
  }

  ret = swr_init(state->swr_ctx);
  if (ret < 0) {
    LOGE("SonicAudio Decoder: Failed to initialize resampler\n");
    decoder_close(state);
    return -9;
  }

  if (state->fmt_ctx->duration != AV_NOPTS_VALUE) {
    state->duration = (double)state->fmt_ctx->duration / AV_TIME_BASE;
  } else if (audio_stream->duration != AV_NOPTS_VALUE) {
    state->duration =
        (double)audio_stream->duration * av_q2d(audio_stream->time_base);
  } else {
    state->duration = 0.0;
  }

  LOGI("SonicAudio Decoder: Opened %s (duration: %.2fs, %dHz, %d ch)\n", url,
       state->duration, state->codec_ctx->sample_rate,
       state->codec_ctx->ch_layout.nb_channels);

  return 0;
}

int decoder_read_frames(DecoderState* state, ma_pcm_rb* buffer,
                        int max_frames) {
  if (!state || !state->fmt_ctx || !buffer) return -1;

  AVPacket* packet = av_packet_alloc();
  AVFrame* frame = av_frame_alloc();
  if (!packet || !frame) {
    av_packet_free(&packet);
    av_frame_free(&frame);
    return -1;
  }

  int total_frames_written = 0;

  while (total_frames_written < max_frames && !state->should_stop) {
    int ret = av_read_frame(state->fmt_ctx, packet);
    if (ret < 0) {
      if (ret == AVERROR_EOF) {
        av_packet_free(&packet);
        av_frame_free(&frame);
        return -2;
      }
      continue;
    }

    if (packet->stream_index != state->audio_stream_idx) {
      av_packet_unref(packet);
      continue;
    }

    ret = avcodec_send_packet(state->codec_ctx, packet);
    av_packet_unref(packet);

    if (ret < 0) {
      continue;
    }

    while (ret >= 0) {
      ret = avcodec_receive_frame(state->codec_ctx, frame);
      if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
        break;
      }
      if (ret < 0) {
        continue;
      }

      if (frame->pts != AV_NOPTS_VALUE) {
        AVStream* stream = state->fmt_ctx->streams[state->audio_stream_idx];

        if (state->current_pts != AV_NOPTS_VALUE) {
          double current_sec = state->current_pts * av_q2d(stream->time_base);
          double new_sec = frame->pts * av_q2d(stream->time_base);

          if (new_sec < current_sec - 0.5) {
            LOGI(
                "SonicAudio Decoder: Backward timestamp detected: %.3f -> %.3f "
                "(Diff: %.3f). Raw: %" PRId64 " -> %" PRId64 "\n",
                current_sec, new_sec, new_sec - current_sec, state->current_pts,
                frame->pts);

            if (new_sec < current_sec - 0.5) {
              LOGI("SonicAudio Decoder: Triggering WRAP error.\n");
              av_frame_unref(frame);
              av_packet_free(&packet);
              av_frame_free(&frame);
              return -3;
            }
          }
        }

        state->current_pts = frame->pts;
      }

      int out_samples = swr_get_out_samples(state->swr_ctx, frame->nb_samples);
      if (out_samples > 0) {
        uint8_t* out_buffer = resample_buffer;
        int converted = swr_convert(state->swr_ctx, &out_buffer, out_samples,
                                    (const uint8_t**)frame->extended_data,
                                    frame->nb_samples);

        if (converted > 0) {
          ma_uint32 frames_remaining = converted;
          ma_uint32 frames_offset = 0;

          while (frames_remaining > 0) {
            void* write_ptr;
            ma_uint32 frames_to_write = frames_remaining;

            if (ma_pcm_rb_acquire_write(buffer, &frames_to_write, &write_ptr) ==
                MA_SUCCESS) {
              if (frames_to_write > 0) {
                size_t bytes_per_frame =
                    ma_get_bytes_per_frame(buffer->format, buffer->channels);

                memcpy(write_ptr,
                       out_buffer + (frames_offset * bytes_per_frame),
                       frames_to_write * bytes_per_frame);

                ma_pcm_rb_commit_write(buffer, frames_to_write);

                total_frames_written += frames_to_write;
                frames_remaining -= frames_to_write;
                frames_offset += frames_to_write;
              } else {
                av_usleep(1000);
              }
            } else {
              av_usleep(1000);
            }
          }
        }
      }

      av_frame_unref(frame);
    }
  }

  av_packet_free(&packet);
  av_frame_free(&frame);

  return total_frames_written;
}

int decoder_seek(DecoderState* state, double seconds) {
  if (!state || !state->fmt_ctx) return -1;

  int stream_index = state->audio_stream_idx;
  int64_t timestamp;
  int ret;

  if (stream_index >= 0) {
    AVStream* stream = state->fmt_ctx->streams[stream_index];
    timestamp = av_rescale_q((int64_t)(seconds * AV_TIME_BASE), AV_TIME_BASE_Q,
                             stream->time_base);
    ret = av_seek_frame(state->fmt_ctx, stream_index, timestamp,
                        AVSEEK_FLAG_BACKWARD);
  } else {
    stream_index = -1;
    timestamp = (int64_t)(seconds * AV_TIME_BASE);
    ret = av_seek_frame(state->fmt_ctx, -1, timestamp, AVSEEK_FLAG_BACKWARD);
  }

  if (ret < 0 && stream_index >= 0) {
    timestamp = (int64_t)(seconds * AV_TIME_BASE);
    ret = av_seek_frame(state->fmt_ctx, -1, timestamp, AVSEEK_FLAG_BACKWARD);
  }

  if (ret < 0) {
    LOGE("SonicAudio Decoder: Seek failed\n");
    return -1;
  }

  avcodec_flush_buffers(state->codec_ctx);

  state->current_pts = AV_NOPTS_VALUE;

  return 0;
}

double decoder_get_position(DecoderState* state) {
  if (!state || !state->fmt_ctx) return 0.0;

  if (state->current_pts != AV_NOPTS_VALUE && state->audio_stream_idx >= 0) {
    AVStream* stream = state->fmt_ctx->streams[state->audio_stream_idx];
    return (double)state->current_pts * av_q2d(stream->time_base);
  }
  return 0.0;
}

double decoder_get_duration(DecoderState* state) {
  if (!state) return 0.0;
  return state->duration;
}

void decoder_close(DecoderState* state) {
  if (!state) return;

  state->should_stop = 1;

  if (state->swr_ctx) {
    swr_free(&state->swr_ctx);
    state->swr_ctx = NULL;
  }

  if (state->codec_ctx) {
    avcodec_free_context(&state->codec_ctx);
    state->codec_ctx = NULL;
  }

  if (state->fmt_ctx) {
    avformat_close_input(&state->fmt_ctx);
    state->fmt_ctx = NULL;
  }

  state->audio_stream_idx = -1;
  state->duration = 0.0;
  state->current_pts = 0;
}

int decoder_change_format(DecoderState* state, int target_format) {
  if (!state || !state->swr_ctx || !state->codec_ctx) return -1;

  enum AVSampleFormat output_fmt = AV_SAMPLE_FMT_FLT;
  if (target_format == ma_format_s16) {
    output_fmt = AV_SAMPLE_FMT_S16;
  } else if (target_format == ma_format_s32) {
    output_fmt = AV_SAMPLE_FMT_S32;
  }

  swr_free(&state->swr_ctx);

  int effective_sample_rate = state->codec_ctx->sample_rate;

  AVChannelLayout out_ch_layout;
  av_channel_layout_default(&out_ch_layout,
                            state->codec_ctx->ch_layout.nb_channels);

  int ret = swr_alloc_set_opts2(
      &state->swr_ctx, &out_ch_layout, output_fmt, effective_sample_rate,
      &state->codec_ctx->ch_layout, state->codec_ctx->sample_fmt,
      state->codec_ctx->sample_rate, 0, NULL);

  if (ret < 0 || !state->swr_ctx) {
    LOGE("SonicAudio Decoder: Failed to recreate resampler for new format\n");
    return -1;
  }

  ret = swr_init(state->swr_ctx);
  if (ret < 0) {
    LOGE("SonicAudio Decoder: Failed to re-initialize resampler\n");
    return -2;
  }

  LOGI("SonicAudio Decoder: Output format changed to %s\n",
       (output_fmt == AV_SAMPLE_FMT_S16)   ? "S16"
       : (output_fmt == AV_SAMPLE_FMT_S32) ? "S32"
                                           : "Float");

  return 0;
}
