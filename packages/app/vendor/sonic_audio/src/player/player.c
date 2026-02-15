#include <stdio.h>
#include <string.h>

#include "decoder.h"
#include "internal.h"
#include "sonic_audio.h"
#include "thread/sonic_thread.h"

static void* decoder_thread_func(void* arg);
static void playback_callback(ma_device* device, void* output,
                              const void* input, ma_uint32 frame_count);

static void* decoder_thread_func(void* arg) {
  PlayerState* player = (PlayerState*)arg;
  player->decoder.is_running = 1;

  LOGI("SonicAudio Player: Decoder thread started\n");
  player->position = 0.0;
  player->decoder.is_eof = 0;

  while (!player->decoder.should_stop) {
    if (player->seek_request) {
      double target = player->seek_target;
      player->seek_request = 0;

      LOGI("SonicAudio Player: Seeking to %.2fs on decoder thread\n", target);

      if (decoder_seek(&player->decoder, target) == 0) {
        sa_thread_mutex_lock(&g_sonic.lock);
        ma_pcm_rb_reset(&player->pcm_buffer);
        player->position = target;
        player->state = SONIC_STATE_BUFFERING;
        g_sonic.player.seek_in_progress = 0;
        player->decoder.is_eof = 0;
        sa_thread_mutex_unlock(&g_sonic.lock);
      } else {
        LOGI("SonicAudio Player: Seek failed\n");
        g_sonic.player.seek_in_progress = 0;
        double actual_pos = decoder_get_position(&player->decoder);
        if (actual_pos > 0) {
          player->position = actual_pos;
        }
      }
    }

    ma_uint32 available_write = ma_pcm_rb_available_write(&player->pcm_buffer);

    if (player->decoder.is_eof) {
      sa_sleep(10);
      continue;
    }

    if (available_write > 4800) {
      ma_uint32 to_read = available_write;
      if (to_read > 48000) to_read = 48000;

      int frames_decoded =
          decoder_read_frames(&player->decoder, &player->pcm_buffer, to_read);

      if (frames_decoded == -2) {
        LOGI("SonicAudio Player: End of stream\n");
        player->decoder.is_eof = 1;
      } else if (frames_decoded == -3) {
        LOGI(
            "SonicAudio Player: Discontinuity detected. Stopping decoder "
            "to prevent loop.\n");
        player->decoder.is_eof = 1;
      } else if (frames_decoded < 0) {
        LOGE("SonicAudio Player: Decoder error: %d. Stopping playback.\n",
             frames_decoded);
        sa_thread_mutex_lock(&g_sonic.lock);
        player->state = SONIC_STATE_ERROR;
        sa_thread_mutex_unlock(&g_sonic.lock);
        player->decoder.should_stop = 1;
      }

    } else {
      sa_sleep(10);
    }

    ma_uint32 available_read = ma_pcm_rb_available_read(&player->pcm_buffer);

    if (player->state == SONIC_STATE_BUFFERING &&
        available_read >= (size_t)(player->start_threshold_frames)) {
      LOGI(
          "SonicAudio Player: Buffering complete. Buffered %d frames (%.2fs) "
          ">= Threshold %d frames (%.2fs)\n",
          available_read, (float)available_read / player->sample_rate,
          player->start_threshold_frames, player->start_threshold_seconds);
      player->state = SONIC_STATE_PLAYING;
    }
  }

  player->decoder.is_running = 0;
  LOGI("SonicAudio Player: Decoder thread stopped\n");

  return NULL;
}

static void playback_callback(ma_device* device, void* output,
                              const void* input, ma_uint32 frame_count) {
  (void)input;

  PlayerState* player = (PlayerState*)device->pUserData;
  if (!player || player->state != SONIC_STATE_PLAYING) {
    size_t sample_size = (device->playback.format == ma_format_s32)   ? 4
                         : (device->playback.format == ma_format_s16) ? 2
                                                                      : 4;
    memset(output, 0, frame_count * device->playback.channels * sample_size);
    return;
  }

  ma_uint32 total_frames_processed = 0;

  while (total_frames_processed < frame_count) {
    ma_uint32 frames_to_read = frame_count - total_frames_processed;
    void* read_buffer;

    ma_result result = ma_pcm_rb_acquire_read(&player->pcm_buffer,
                                              &frames_to_read, &read_buffer);

    if (result == MA_SUCCESS && frames_to_read > 0) {
      if (device->playback.format == ma_format_f32) {
        float* out_ptr = (float*)output;
        float* in = (float*)read_buffer;
        float volume = player->volume;
        for (ma_uint32 i = 0; i < frames_to_read * device->playback.channels;
             i++) {
          out_ptr[i] = in[i] * volume;
        }
        output = (char*)output +
                 (frames_to_read * device->playback.channels * sizeof(float));

      } else if (device->playback.format == ma_format_s16) {
        int16_t* out_ptr = (int16_t*)output;
        int16_t* in = (int16_t*)read_buffer;
        float volume = player->volume;
        for (ma_uint32 i = 0; i < frames_to_read * device->playback.channels;
             i++) {
          out_ptr[i] = (int16_t)(in[i] * volume);
        }
        output = (char*)output +
                 (frames_to_read * device->playback.channels * sizeof(int16_t));

      } else if (device->playback.format == ma_format_s32) {
        int32_t* out_ptr = (int32_t*)output;
        int32_t* in = (int32_t*)read_buffer;
        float volume = player->volume;
        for (ma_uint32 i = 0; i < frames_to_read * device->playback.channels;
             i++) {
          out_ptr[i] = (int32_t)(in[i] * volume);
        }
        output = (char*)output +
                 (frames_to_read * device->playback.channels * sizeof(int32_t));
      }

      ma_pcm_rb_commit_read(&player->pcm_buffer, frames_to_read);

      if (player->sample_rate > 0 && !player->seek_in_progress) {
        sa_thread_mutex_lock(&g_sonic.lock);
        player->position += (double)frames_to_read / player->sample_rate;
        sa_thread_mutex_unlock(&g_sonic.lock);
      }

      total_frames_processed += frames_to_read;
    } else {
      break;
    }
  }

  if (total_frames_processed < frame_count) {
    ma_uint32 frames_remaining = frame_count - total_frames_processed;
    size_t sample_size = (device->playback.format == ma_format_s32)   ? 4
                         : (device->playback.format == ma_format_s16) ? 2
                                                                      : 4;
    memset(output, 0,
           frames_remaining * device->playback.channels * sample_size);

    if (player->state == SONIC_STATE_PLAYING) {
      if (player->decoder.is_eof) {
        player->state = SONIC_STATE_ENDED;
      } else {
        player->state = SONIC_STATE_BUFFERING;
      }
    }
  }
}

FFI_PLUGIN_EXPORT int sonic_audio_player_load(const char* url,
                                              const char* headers) {
  if (!url) return -1;

  if (!g_sonic.is_initialized) {
    if (sonic_audio_init_context() != 0) return -2;
  }

  sonic_audio_player_stop();

  sa_thread_mutex_lock(&g_sonic.lock);

  PlayerState* player = &g_sonic.player;

  if (player->total_buffer_seconds <= 1.0f) {
    player->total_buffer_seconds = 30.0f;
  }
  if (player->start_threshold_seconds <= 0.1f) {
    player->start_threshold_seconds = 2.0f;
  }

  player->channels = 2;

  if (player->use_exclusive_audio || player->use_native_sample_rate) {
    player->format = ma_format_s16;
  } else {
    player->format = ma_format_f32;
  }

  int target_rate =
      (player->use_native_sample_rate || player->use_exclusive_audio) ? -1
                                                                      : 48000;
  if (!player->use_native_sample_rate && !player->use_exclusive_audio &&
      player->sample_rate <= 0) {
    player->sample_rate = 48000;
  }

  int initial_format_req = player->format;

  int ret = decoder_open(&player->decoder, url, headers, target_rate,
                         player->channels, initial_format_req);
  if (ret != 0) {
    LOGE("SonicAudio Player: Failed to open decoder for %s (Error code: %d)\n",
         url, ret);
    sa_thread_mutex_unlock(&g_sonic.lock);
    return -3;
  }

  int use_native_format =
      player->use_exclusive_audio || player->use_native_sample_rate;

  if (use_native_format) {
    enum AVSampleFormat native_fmt = player->decoder.codec_ctx->sample_fmt;
    int native_bits = av_get_bytes_per_sample(native_fmt) * 8;

    if (native_bits > 16) {
      player->format = ma_format_s32;
    } else {
      player->format = ma_format_s16;
    }

    if (player->format != initial_format_req) {
      LOGI(
          "SonicAudio Player: Upgrading decoder format to S32 for Hi-Res "
          "audio.\n");
      if (decoder_change_format(&player->decoder, player->format) != 0) {
        LOGE(
            "SonicAudio Player: Failed to upgrade decoder format. Reverting "
            "player format.\n");
        player->format = initial_format_req;
      }
    }
  }
  if (ret != 0) {
    LOGE("SonicAudio Player: Failed to open decoder for %s (Error code: %d)\n",
         url, ret);
    sa_thread_mutex_unlock(&g_sonic.lock);
    return -3;
  }

  if ((player->use_native_sample_rate || player->use_exclusive_audio) &&
      player->decoder.codec_ctx) {
    player->sample_rate = player->decoder.codec_ctx->sample_rate;
  } else {
    player->sample_rate = 48000;
  }

  player->ring_buffer_size_frames =
      (int)(player->sample_rate * player->total_buffer_seconds);
  player->start_threshold_frames =
      (int)(player->sample_rate * player->start_threshold_seconds);

  LOGI(
      "SonicAudio Player: Buffer Config -> Capacity: %.1fs (%d frames), Start "
      "Threshold: %.1fs (%d frames)\n",
      player->total_buffer_seconds, player->ring_buffer_size_frames,
      player->start_threshold_seconds, player->start_threshold_frames);

  ret = ma_pcm_rb_init(player->format, player->channels,
                       player->ring_buffer_size_frames, NULL, NULL,
                       &player->pcm_buffer);
  if (ret != MA_SUCCESS) {
    LOGE("SonicAudio Player: Failed to initialize ring buffer\n");
    decoder_close(&player->decoder);
    sa_thread_mutex_unlock(&g_sonic.lock);
    return -4;
  }

  ma_device_config config = ma_device_config_init(ma_device_type_playback);
  config.playback.format = player->format;
  config.playback.channels = player->channels;
  config.sampleRate = player->sample_rate;
  config.dataCallback = playback_callback;
  config.pUserData = player;

  if (player->has_selected_device) {
    config.playback.pDeviceID = &player->selected_device_id;
  }

  if (player->use_exclusive_audio) {
    config.playback.shareMode = ma_share_mode_exclusive;
    config.aaudio.usage = ma_aaudio_usage_media;
    config.aaudio.contentType = ma_aaudio_content_type_music;
  }

  ret = ma_device_init(&g_sonic.ma_ctx, &config, &player->device);
  if (ret != MA_SUCCESS) {
    LOGE("SonicAudio Player: Failed to initialize playback device\n");
    ma_pcm_rb_uninit(&player->pcm_buffer);
    decoder_close(&player->decoder);
    sa_thread_mutex_unlock(&g_sonic.lock);
    return -5;
  }

  LOGI(
      "SonicAudio Player: Device Initialized. Rate: %d (Requested: %d), "
      "Channels: %d, Format: %d, Shared: %s\n",
      player->device.sampleRate, player->sample_rate,
      player->device.playback.channels, player->device.playback.format,
      player->device.playback.shareMode == ma_share_mode_exclusive ? "EXCLUSIVE"
                                                                   : "SHARED");

  if (player->device.sampleRate != player->sample_rate) {
    LOGI(
        "SonicAudio Player: WARNING: Device rate mismatch! Requested %d, got "
        "%d. This may cause speed/pitch issues.\n",
        player->device.sampleRate, player->device.sampleRate);
  }

  player->is_initialized = 1;

  player->state = SONIC_STATE_BUFFERING;
  player->position = 0.0;
  player->decoder.is_eof = 0;

  player->decoder.should_stop = 0;
  ret = sa_thread_create(&player->decoder.thread, decoder_thread_func,
                       player);
  if (ret != 0) {
    LOGE("SonicAudio Player: Failed to start decoder thread\n");
    ma_device_uninit(&player->device);
    ma_pcm_rb_uninit(&player->pcm_buffer);
    decoder_close(&player->decoder);
    player->is_initialized = 0;
    sa_thread_mutex_unlock(&g_sonic.lock);
    return -6;
  }

  ret = ma_device_start(&player->device);
  if (ret != MA_SUCCESS) {
    LOGE("SonicAudio Player: Failed to start playback device\n");
    player->decoder.should_stop = 1;
    sa_thread_join(&player->decoder.thread, NULL);
    ma_device_uninit(&player->device);
    ma_pcm_rb_uninit(&player->pcm_buffer);
    decoder_close(&player->decoder);
    player->is_initialized = 0;
    sa_thread_mutex_unlock(&g_sonic.lock);
    return -7;
  }

  LOGI("SonicAudio Player: Loaded %s\n", url);
  sa_thread_mutex_unlock(&g_sonic.lock);

  return 0;
}

FFI_PLUGIN_EXPORT void sonic_audio_player_play(void) {
  if (!g_sonic.player.is_initialized) return;

  if (g_sonic.player.state == SONIC_STATE_PAUSED) {
    g_sonic.player.state = SONIC_STATE_PLAYING;
    ma_device_start(&g_sonic.player.device);
  }
}

FFI_PLUGIN_EXPORT void sonic_audio_player_pause(void) {
  if (!g_sonic.player.is_initialized) return;

  if (g_sonic.player.state == SONIC_STATE_PLAYING ||
      g_sonic.player.state == SONIC_STATE_BUFFERING) {
    g_sonic.player.state = SONIC_STATE_PAUSED;
    ma_device_stop(&g_sonic.player.device);
  }
}

FFI_PLUGIN_EXPORT void sonic_audio_player_stop(void) {
  PlayerState* player = &g_sonic.player;

  if (!player->is_initialized) return;

  player->decoder.should_stop = 1;

  if (player->decoder.is_running) {
    sa_thread_join(&player->decoder.thread, NULL);
    player->decoder.is_running = 0;
  }

  ma_device_stop(&player->device);

  ma_device_uninit(&player->device);
  memset(&player->device, 0, sizeof(ma_device));
  ma_pcm_rb_uninit(&player->pcm_buffer);
  decoder_close(&player->decoder);

  sa_sleep(50);

  player->is_initialized = 0;
  player->state = SONIC_STATE_IDLE;
  player->position = 0.0;

  LOGI("SonicAudio Player: Stopped\n");
}

FFI_PLUGIN_EXPORT void sonic_audio_player_seek(double seconds) {
  if (!g_sonic.player.is_initialized) return;

  sa_thread_mutex_lock(&g_sonic.lock);

  g_sonic.player.seek_target = seconds;
  g_sonic.player.seek_request = 1;
  g_sonic.player.seek_in_progress = 1;
  g_sonic.player.decoder.is_eof = 0;

  g_sonic.player.position = seconds;

  sa_thread_mutex_unlock(&g_sonic.lock);
}

FFI_PLUGIN_EXPORT void sonic_audio_player_set_volume(float volume) {
  if (volume < 0.0f) volume = 0.0f;
  if (volume > 1.0f) volume = 1.0f;
  g_sonic.player.volume = volume;
}

FFI_PLUGIN_EXPORT int sonic_audio_player_set_output_device(int index) {
  if (index < 0) return -1;

  ma_device_id* pDeviceID = NULL;
  ma_device_id deviceID;

  if (index >= 0) {
    ma_device_info* pPlaybackInfos;
    ma_uint32 playbackCount;
    ma_device_info* pCaptureInfos;
    ma_uint32 captureCount;

    if (ma_context_get_devices(&g_sonic.ma_ctx, &pPlaybackInfos, &playbackCount,
                               &pCaptureInfos, &captureCount) == MA_SUCCESS) {
      if (index < (int)playbackCount) {
        deviceID = pPlaybackInfos[index].id;
        pDeviceID = &deviceID;
      }
    }
  }

  if (g_sonic.player.is_initialized) {
    int was_playing = (g_sonic.player.state == SONIC_STATE_PLAYING);

    ma_device_stop(&g_sonic.player.device);
    ma_device_uninit(&g_sonic.player.device);

    ma_device_config config = ma_device_config_init(ma_device_type_playback);
    config.playback.format = g_sonic.player.format;
    config.playback.channels = g_sonic.player.channels;
    config.sampleRate = g_sonic.player.sample_rate;
    config.dataCallback = playback_callback;
    config.pUserData = &g_sonic.player;
    config.playback.pDeviceID = pDeviceID;

    if (ma_device_init(&g_sonic.ma_ctx, &config, &g_sonic.player.device) !=
        MA_SUCCESS) {
      LOGE("SonicAudio Player: Failed to re-initialize playback device\n");
      config.playback.pDeviceID = NULL;
      if (ma_device_init(&g_sonic.ma_ctx, &config, &g_sonic.player.device) !=
          MA_SUCCESS) {
        g_sonic.player.is_initialized = 0;
        return -2;
      }
    }

    if (was_playing) {
      ma_device_start(&g_sonic.player.device);
    }
  }

  if (pDeviceID) {
    g_sonic.player.has_selected_device = 1;
    g_sonic.player.selected_device_id = deviceID;
  } else {
    g_sonic.player.has_selected_device = 0;
  }

  return 0;
}

FFI_PLUGIN_EXPORT int sonic_audio_player_get_state(void) {
  return (int)g_sonic.player.state;
}

FFI_PLUGIN_EXPORT double sonic_audio_player_get_position(void) {
  return g_sonic.player.position;
}

FFI_PLUGIN_EXPORT double sonic_audio_player_get_duration(void) {
  return decoder_get_duration(&g_sonic.player.decoder);
}

FFI_PLUGIN_EXPORT void sonic_audio_player_set_buffer_duration(float seconds) {
  if (seconds < 0.1f) seconds = 0.1f;
  if (seconds > 30.0f) seconds = 30.0f;

  sa_thread_mutex_lock(&g_sonic.lock);
  g_sonic.player.start_threshold_seconds = seconds;
  if (g_sonic.player.sample_rate > 0) {
    g_sonic.player.start_threshold_frames =
        (int)(g_sonic.player.sample_rate * seconds);
  }
  if (g_sonic.player.sample_rate > 0) {
    g_sonic.player.start_threshold_frames =
        (int)(g_sonic.player.sample_rate * seconds);
  }
  sa_thread_mutex_unlock(&g_sonic.lock);
}

FFI_PLUGIN_EXPORT void sonic_audio_player_set_native_rate_enabled(int enabled) {
  g_sonic.player.use_native_sample_rate = enabled;
}

FFI_PLUGIN_EXPORT void sonic_audio_player_set_exclusive_audio_enabled(
    int enabled) {
  g_sonic.player.use_exclusive_audio = enabled;
}
