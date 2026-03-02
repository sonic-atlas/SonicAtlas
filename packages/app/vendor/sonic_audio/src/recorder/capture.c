#include <stdio.h>
#include <string.h>

#include "internal.h"
#include "sonic_audio.h"
#include "thread/sonic_thread.h"

#define CAPTURE_BUFFER_SIZE(sr) ((sr) * 2)

static void* encoder_thread_func(void* arg) {
  RecorderState* recorder = (RecorderState*)arg;

  void* read_ptr;
  ma_uint32 frames_to_read;
  int ret;

  AVFrame* frame = av_frame_alloc();
  frame->nb_samples = 4800;
  av_channel_layout_default(&frame->ch_layout, recorder->channels);
  frame->format = recorder->out_codec_ctx->sample_fmt;
  frame->sample_rate = recorder->sample_rate;
  av_frame_get_buffer(frame, 0);

  AVPacket* pkt = av_packet_alloc();

  int sample_size = (recorder->format == ma_format_s32) ? 4 : 2;
  int64_t pts = 0;

  while (!recorder->should_stop_encoder) {
    frames_to_read = 4800;
    if (ma_pcm_rb_acquire_read(&recorder->capture_buffer, &frames_to_read,
                               &read_ptr) == MA_SUCCESS) {
      if (frames_to_read > 0) {
        frame->nb_samples = frames_to_read;
        av_fast_malloc(&frame->data[0], (unsigned int*)&frame->linesize[0],
                       frames_to_read * recorder->channels * sample_size);
        memcpy(frame->data[0], read_ptr,
               frames_to_read * recorder->channels * sample_size);

        frame->pts = pts;
        pts += frames_to_read;

        ret = avcodec_send_frame(recorder->out_codec_ctx, frame);
        while (ret >= 0) {
          ret = avcodec_receive_packet(recorder->out_codec_ctx, pkt);
          if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) break;

          av_packet_rescale_ts(pkt, recorder->out_codec_ctx->time_base,
                               recorder->out_stream->time_base);
          pkt->stream_index = recorder->out_stream->index;
          av_interleaved_write_frame(recorder->out_fmt_ctx, pkt);
          av_packet_unref(pkt);
        }

        ma_pcm_rb_commit_read(&recorder->capture_buffer, frames_to_read);
      } else {
        sa_sleep(10);
      }
    } else {
      sa_sleep(10);
    }
  }

  frames_to_read = ma_pcm_rb_available_read(&recorder->capture_buffer);
  while (frames_to_read > 0) {
    ma_uint32 chunk = frames_to_read;
    if (chunk > 4800) chunk = 4800;

    if (ma_pcm_rb_acquire_read(&recorder->capture_buffer, &chunk, &read_ptr) ==
        MA_SUCCESS) {
      if (chunk > 0) {
        frame->nb_samples = chunk;
        memcpy(frame->data[0], read_ptr,
               chunk * recorder->channels * sample_size);
        frame->pts = pts;
        pts += chunk;

        ret = avcodec_send_frame(recorder->out_codec_ctx, frame);
        while (ret >= 0) {
          ret = avcodec_receive_packet(recorder->out_codec_ctx, pkt);
          if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) break;

          av_packet_rescale_ts(pkt, recorder->out_codec_ctx->time_base,
                               recorder->out_stream->time_base);
          pkt->stream_index = recorder->out_stream->index;
          av_interleaved_write_frame(recorder->out_fmt_ctx, pkt);
          av_packet_unref(pkt);
        }

        ma_pcm_rb_commit_read(&recorder->capture_buffer, chunk);
        frames_to_read -= chunk;
      } else {
        break;
      }
    } else {
      break;
    }
  }

  avcodec_send_frame(recorder->out_codec_ctx, NULL);
  while (1) {
    ret = avcodec_receive_packet(recorder->out_codec_ctx, pkt);
    if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) break;
    av_packet_rescale_ts(pkt, recorder->out_codec_ctx->time_base,
                         recorder->out_stream->time_base);
    pkt->stream_index = recorder->out_stream->index;
    av_interleaved_write_frame(recorder->out_fmt_ctx, pkt);
    av_packet_unref(pkt);
  }

  av_write_trailer(recorder->out_fmt_ctx);

  if (!(recorder->out_fmt_ctx->oformat->flags & AVFMT_NOFILE)) {
    avio_closep(&recorder->out_fmt_ctx->pb);
  }

  avcodec_free_context(&recorder->out_codec_ctx);
  avformat_free_context(recorder->out_fmt_ctx);

  av_frame_free(&frame);
  av_packet_free(&pkt);

  recorder->out_fmt_ctx = NULL;
  recorder->out_codec_ctx = NULL;

  return NULL;
}

static void monitor_callback(ma_device* device, void* output, const void* input,
                             ma_uint32 frame_count) {
  (void)input;
  RecorderState* recorder = (RecorderState*)device->pUserData;
  if (!recorder || !recorder->is_monitoring ||
      !recorder->is_monitor_initialized) {
    size_t sample_size = (device->playback.format == ma_format_s32) ? 4 : 2;
    memset(output, 0, frame_count * device->playback.channels * sample_size);
    return;
  }

  void* read_ptr;
  ma_uint32 frames_to_read = frame_count;
  size_t sample_size = (recorder->format == ma_format_s32) ? 4 : 2;

  while (frames_to_read > 0) {
    ma_uint32 chunk = frames_to_read;
    if (ma_pcm_rb_acquire_read(&recorder->monitor_buffer, &chunk, &read_ptr) ==
        MA_SUCCESS) {
      if (chunk > 0) {
        memcpy(output, read_ptr, chunk * recorder->channels * sample_size);
        ma_pcm_rb_commit_read(&recorder->monitor_buffer, chunk);
        frames_to_read -= chunk;
        output = (char*)output + (chunk * recorder->channels * sample_size);
      } else {
        break;
      }
    } else {
      break;
    }
  }

  if (frames_to_read > 0) {
    memset(output, 0, frames_to_read * recorder->channels * sample_size);
  }
}

static void capture_callback(ma_device* device, void* output, const void* input,
                             ma_uint32 frame_count) {
  (void)output;
  RecorderState* recorder = (RecorderState*)device->pUserData;
  if (!recorder || !recorder->is_initialized) return;

  double sum_squares = 0.0;
  ma_uint32 total_samples = frame_count * recorder->channels;
  if (recorder->format == ma_format_s16) {
    const int16_t* in16 = (const int16_t*)input;
    for (ma_uint32 i = 0; i < total_samples; i++) {
      float sample = in16[i] / 32768.0f;
      sum_squares += sample * sample;
    }
  } else if (recorder->format == ma_format_s32) {
    const int32_t* in32 = (const int32_t*)input;
    for (ma_uint32 i = 0; i < total_samples; i++) {
      float sample = in32[i] / 2147483648.0f;
      sum_squares += sample * sample;
    }
  }

  if (total_samples > 0) {
    recorder->current_rms = (float)sqrt(sum_squares / total_samples);
  } else {
    recorder->current_rms = 0.0f;
  }

  const void* original_input = input;

  void* write_ptr;
  ma_uint32 frames_to_write = frame_count;
  while (frames_to_write > 0) {
    ma_uint32 chunk_frames = frames_to_write;
    if (ma_pcm_rb_acquire_write(&recorder->capture_buffer, &chunk_frames,
                                &write_ptr) != MA_SUCCESS) {
      break;
    }
    if (chunk_frames == 0) break;

    size_t sample_size = (recorder->format == ma_format_s32) ? 4 : 2;
    memcpy(write_ptr, input, chunk_frames * recorder->channels * sample_size);
    ma_pcm_rb_commit_write(&recorder->capture_buffer, chunk_frames);
    frames_to_write -= chunk_frames;
    input =
        (const char*)input + (chunk_frames * recorder->channels * sample_size);
  }

  if (recorder->is_monitoring && recorder->is_monitor_initialized) {
    frames_to_write = frame_count;
    input = original_input;
    while (frames_to_write > 0) {
      ma_uint32 chunk_frames = frames_to_write;
      if (ma_pcm_rb_acquire_write(&recorder->monitor_buffer, &chunk_frames,
                                  &write_ptr) != MA_SUCCESS) {
        break;
      }
      if (chunk_frames == 0) break;

      size_t sample_size = (recorder->format == ma_format_s32) ? 4 : 2;
      memcpy(write_ptr, input, chunk_frames * recorder->channels * sample_size);
      ma_pcm_rb_commit_write(&recorder->monitor_buffer, chunk_frames);
      frames_to_write -= chunk_frames;
      input = (const char*)input +
              (chunk_frames * recorder->channels * sample_size);
    }
  }
}

FFI_PLUGIN_EXPORT void sonic_audio_recorder_set_monitor(int enable) {
  RecorderState* recorder = &g_sonic.recorder;

  sa_thread_mutex_lock(&g_sonic.lock);

  if (enable && !recorder->is_monitor_initialized && recorder->is_initialized) {
    ma_uint32 buffer_frames = CAPTURE_BUFFER_SIZE(recorder->sample_rate);
    if (ma_pcm_rb_init(recorder->format, recorder->channels, buffer_frames,
                       NULL, NULL, &recorder->monitor_buffer) == MA_SUCCESS) {
      ma_device_config config = ma_device_config_init(ma_device_type_playback);
      config.playback.format = recorder->format;
      config.playback.channels = recorder->channels;
      config.sampleRate = recorder->sample_rate;
      config.dataCallback = monitor_callback;
      config.pUserData = recorder;

      if (ma_device_init(&g_sonic.ma_ctx, &config, &recorder->monitor_device) ==
          MA_SUCCESS) {
        recorder->is_monitor_initialized = 1;
        ma_device_start(&recorder->monitor_device);
      } else {
        ma_pcm_rb_uninit(&recorder->monitor_buffer);
      }
    }
  } else if (!enable && recorder->is_monitor_initialized) {
    ma_device_stop(&recorder->monitor_device);
  } else if (enable && recorder->is_monitor_initialized) {
    ma_device_start(&recorder->monitor_device);
  }

  recorder->is_monitoring = enable;
  sa_thread_mutex_unlock(&g_sonic.lock);
}

FFI_PLUGIN_EXPORT float sonic_audio_recorder_get_rms(void) {
  return g_sonic.recorder.current_rms;
}

FFI_PLUGIN_EXPORT int sonic_audio_recorder_start_file(int device_index,
                                                      int sample_rate,
                                                      int channels,
                                                      int bit_depth,
                                                      const char* file_path) {
  if (!g_sonic.is_initialized) {
    if (sonic_audio_init_context() != 0) return -1;
  }

  sonic_audio_recorder_stop();

  RecorderState* recorder = &g_sonic.recorder;

  if (bit_depth == 24 || bit_depth == 32) {
    recorder->format = ma_format_s32;
  } else {
    recorder->format = ma_format_s16;
  }
  recorder->sample_rate = sample_rate;
  recorder->channels = channels;

  ma_uint32 buffer_frames = CAPTURE_BUFFER_SIZE(sample_rate);
  if (ma_pcm_rb_init(recorder->format, channels, buffer_frames, NULL, NULL,
                     &recorder->capture_buffer) != MA_SUCCESS) {
    LOGE("SonicAudio Recorder: Failed to init ring buffer\n");
    return -2;
  }

  ma_device_config config = ma_device_config_init(ma_device_type_capture);
  config.capture.format = recorder->format;
  config.capture.channels = channels;
  config.sampleRate = sample_rate;
  config.dataCallback = capture_callback;
  config.pUserData = recorder;

  ma_device_info* pPlaybackInfos;
  ma_uint32 playbackCount;
  ma_device_info* pCaptureInfos;
  ma_uint32 captureCount;

  if (ma_context_get_devices(&g_sonic.ma_ctx, &pPlaybackInfos, &playbackCount,
                             &pCaptureInfos, &captureCount) == MA_SUCCESS) {
    if (device_index >= 0 && device_index < (int)captureCount) {
      config.capture.pDeviceID = &pCaptureInfos[device_index].id;
    }
  }

  if (ma_device_init(&g_sonic.ma_ctx, &config, &recorder->device) !=
      MA_SUCCESS) {
    LOGE("SonicAudio Recorder: Failed to init capture device\n");
    ma_pcm_rb_uninit(&recorder->capture_buffer);
    return -3;
  }

  if (file_path != NULL && strlen(file_path) > 0) {
    AVFormatContext* fmt_ctx = NULL;
    avformat_alloc_output_context2(&fmt_ctx, NULL, "wav", file_path);
    if (!fmt_ctx) {
      LOGE(
          "SonicAudio Recorder: Failed to deduce output format from file "
          "extension\n");
      ma_device_uninit(&recorder->device);
      ma_pcm_rb_uninit(&recorder->capture_buffer);
      return -5;
    }

    enum AVCodecID codec_id = fmt_ctx->oformat->audio_codec;
    if (bit_depth == 24) {
      codec_id = AV_CODEC_ID_PCM_S24LE;
    } else if (bit_depth == 32) {
      codec_id = AV_CODEC_ID_PCM_S32LE;
    }
    const AVCodec* codec = avcodec_find_encoder(codec_id);
    if (!codec) {
      LOGE("SonicAudio Recorder: Audio codec %d not found\n", codec_id);
      avformat_free_context(fmt_ctx);
      ma_device_uninit(&recorder->device);
      ma_pcm_rb_uninit(&recorder->capture_buffer);
      return -5;
    }

    AVStream* stream = avformat_new_stream(fmt_ctx, NULL);
    if (!stream) {
      avformat_free_context(fmt_ctx);
      ma_device_uninit(&recorder->device);
      ma_pcm_rb_uninit(&recorder->capture_buffer);
      return -5;
    }

    AVCodecContext* codec_ctx = avcodec_alloc_context3(codec);
    av_channel_layout_default(&codec_ctx->ch_layout, channels);
    codec_ctx->sample_rate = sample_rate;
    if (bit_depth == 24) {
      codec_ctx->sample_fmt = AV_SAMPLE_FMT_S32;
    } else if (bit_depth == 32) {
      codec_ctx->sample_fmt = AV_SAMPLE_FMT_S32;
    } else {
      codec_ctx->sample_fmt = AV_SAMPLE_FMT_S16;
    }
    codec_ctx->time_base = (AVRational){1, sample_rate};

    if (avformat_query_codec(fmt_ctx->oformat, codec->id,
                             FF_COMPLIANCE_STRICT) != 1) {
      LOGI(
          "SonicAudio Recorder: Codec id %d not officially supported by "
          "format, but trying anyway.\n",
          codec->id);
    }

    stream->time_base = codec_ctx->time_base;

    if (avcodec_open2(codec_ctx, codec, NULL) < 0) {
      LOGE("SonicAudio Recorder: Failed to open codec\n");
      avcodec_free_context(&codec_ctx);
      avformat_free_context(fmt_ctx);
      ma_device_uninit(&recorder->device);
      ma_pcm_rb_uninit(&recorder->capture_buffer);
      return -5;
    }

    avcodec_parameters_from_context(stream->codecpar, codec_ctx);

    if (!(fmt_ctx->oformat->flags & AVFMT_NOFILE)) {
      if (avio_open(&fmt_ctx->pb, file_path, AVIO_FLAG_WRITE) < 0) {
        LOGE("SonicAudio Recorder: Failed to open output file\n");
        avcodec_free_context(&codec_ctx);
        avformat_free_context(fmt_ctx);
        ma_device_uninit(&recorder->device);
        ma_pcm_rb_uninit(&recorder->capture_buffer);
        return -5;
      }
    }

    if (avformat_write_header(fmt_ctx, NULL) < 0) {
      LOGE("SonicAudio Recorder: Failed to write header\n");
      if (!(fmt_ctx->oformat->flags & AVFMT_NOFILE)) avio_closep(&fmt_ctx->pb);
      avcodec_free_context(&codec_ctx);
      avformat_free_context(fmt_ctx);
      ma_device_uninit(&recorder->device);
      ma_pcm_rb_uninit(&recorder->capture_buffer);
      return -5;
    }

    recorder->out_fmt_ctx = fmt_ctx;
    recorder->out_codec_ctx = codec_ctx;
    recorder->out_stream = stream;

    recorder->is_recording_to_file = 1;
    recorder->should_stop_encoder = 0;

    if (sa_thread_create(&recorder->encoder_thread, encoder_thread_func,
                         recorder) != 0) {
      if (!(fmt_ctx->oformat->flags & AVFMT_NOFILE)) avio_closep(&fmt_ctx->pb);
      avcodec_free_context(&codec_ctx);
      avformat_free_context(fmt_ctx);
      recorder->out_fmt_ctx = NULL;

      recorder->is_recording_to_file = 0;
      ma_device_uninit(&recorder->device);
      ma_pcm_rb_uninit(&recorder->capture_buffer);
      return -6;
    }
  }

  if (ma_device_start(&recorder->device) != MA_SUCCESS) {
    LOGE("SonicAudio Recorder: Failed to start capture device\n");
    if (recorder->is_recording_to_file) {
      recorder->should_stop_encoder = 1;
      sa_thread_join(&recorder->encoder_thread, NULL);
      recorder->is_recording_to_file = 0;
    }
    ma_device_uninit(&recorder->device);
    ma_pcm_rb_uninit(&recorder->capture_buffer);
    return -4;
  }

  recorder->is_initialized = 1;
  LOGI("SonicAudio Recorder: Started (device %d, %dHz, %dch, %s)\n",
       device_index, sample_rate, channels,
       recorder->format == ma_format_s32 ? "S32" : "S16");

  if (recorder->is_monitoring) {
    sonic_audio_recorder_set_monitor(1);
  }

  return 0;
}

FFI_PLUGIN_EXPORT int sonic_audio_recorder_start(int device_index,
                                                 int sample_rate, int channels,
                                                 int bit_depth) {
  return sonic_audio_recorder_start_file(device_index, sample_rate, channels,
                                         bit_depth, NULL);
}

FFI_PLUGIN_EXPORT int sonic_audio_recorder_stop(void) {
  RecorderState* recorder = &g_sonic.recorder;

  if (!recorder->is_initialized) return 0;

  if (recorder->is_recording_to_file) {
    recorder->should_stop_encoder = 1;
    sa_thread_join(&recorder->encoder_thread, NULL);
    recorder->is_recording_to_file = 0;
    ma_device_uninit(&recorder->device);
    ma_pcm_rb_uninit(&recorder->capture_buffer);
  }

  if (recorder->is_monitor_initialized) {
    ma_device_uninit(&recorder->monitor_device);
    ma_pcm_rb_uninit(&recorder->monitor_buffer);
    recorder->is_monitor_initialized = 0;
  }

  recorder->is_initialized = 0;
  recorder->current_rms = 0.0f;
  LOGI("SonicAudio Recorder: Stopped\n");

  return 0;
}

FFI_PLUGIN_EXPORT int sonic_audio_recorder_read_s16(int16_t* output,
                                                    int frame_count) {
  RecorderState* recorder = &g_sonic.recorder;

  if (!recorder->is_initialized || recorder->format != ma_format_s16 ||
      !output) {
    return 0;
  }

  void* read_ptr;
  ma_uint32 frames_read = frame_count;

  if (ma_pcm_rb_acquire_read(&recorder->capture_buffer, &frames_read,
                             &read_ptr) == MA_SUCCESS) {
    if (frames_read > 0) {
      memcpy(output, read_ptr,
             frames_read * recorder->channels * sizeof(int16_t));
      ma_pcm_rb_commit_read(&recorder->capture_buffer, frames_read);
    }
    return (int)frames_read;
  }

  return 0;
}

FFI_PLUGIN_EXPORT int sonic_audio_recorder_read_s32(int32_t* output,
                                                    int frame_count) {
  RecorderState* recorder = &g_sonic.recorder;

  if (!recorder->is_initialized || recorder->format != ma_format_s32 ||
      !output) {
    return 0;
  }

  void* read_ptr;
  ma_uint32 frames_read = frame_count;

  if (ma_pcm_rb_acquire_read(&recorder->capture_buffer, &frames_read,
                             &read_ptr) == MA_SUCCESS) {
    if (frames_read > 0) {
      memcpy(output, read_ptr,
             frames_read * recorder->channels * sizeof(int32_t));
      ma_pcm_rb_commit_read(&recorder->capture_buffer, frames_read);
    }
    return (int)frames_read;
  }

  return 0;
}
