#include <stdio.h>
#include <string.h>

#include "decoder.h"
#include "internal.h"
#include "sonic_audio.h"
#include "thread/sonic_thread.h"

static void player_unload_stream(PlayerState* player);
static void* decoder_thread_func(void* arg);
static void playback_callback(ma_device* device, void* output, const void* input, ma_uint32 frame_count);

static int player_init_ring_buffer(PlayerState* player) {
  ma_audio_ring_buffer_config cfg =
      ma_audio_ring_buffer_config_init(player->format, player->channels, 0, (ma_uint32)player->ring_buffer_size_frames);
  return (int)ma_audio_ring_buffer_init(&cfg, &player->pcm_buffer);
}

static void player_unload_stream(PlayerState* player) {
  player->state = SONIC_STATE_IDLE;
  player->decoder.should_stop = 1;

  if (!player->is_initialized) return;

  if (player->decoder.is_running) {
    sa_thread_join(&player->decoder.thread, NULL);
    player->decoder.is_running = 0;
  }

  ma_audio_ring_buffer_uninit(&player->pcm_buffer);
  decoder_close(&player->decoder);
  player->is_initialized = 0;
  player->position = 0.0;
}

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

        int was_playing = (player->state == SONIC_STATE_PLAYING || player->state == SONIC_STATE_BUFFERING);
        player->state = SONIC_STATE_BUFFERING;

        if (player->device_ever_initialized) {
          ma_device_stop(&player->device);
        }

        ma_audio_ring_buffer_uninit(&player->pcm_buffer);
        player_init_ring_buffer(player);
        player->position = target;
        g_sonic.player.seek_in_progress = 0;
        player->decoder.is_eof = 0;

        if (was_playing && player->device_ever_initialized) {
          ma_device_start(&player->device);
        }

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

    ma_uint32 available_write =
        ma_ring_buffer_capacity(&player->pcm_buffer.rb) - ma_ring_buffer_length(&player->pcm_buffer.rb);

    if (player->decoder.is_eof) {
      sa_sleep(10);
      continue;
    }

    if (available_write > 4800) {
      ma_uint32 to_read = available_write;
      if (to_read > 48000) to_read = 48000;

      int frames_decoded = decoder_read_frames(&player->decoder, &player->pcm_buffer, to_read);

      if (frames_decoded == -2) {
        LOGI("SonicAudio Player: End of stream\n");
        player->decoder.is_eof = 1;
      } else if (frames_decoded == -3) {
        LOGI(
            "SonicAudio Player: Discontinuity detected. Stopping decoder "
            "to prevent loop.\n");
        player->decoder.is_eof = 1;
      } else if (frames_decoded < 0) {
        LOGE("SonicAudio Player: Decoder error: %d. Stopping playback.\n", frames_decoded);
        sa_thread_mutex_lock(&g_sonic.lock);
        player->state = SONIC_STATE_ERROR;
        sa_thread_mutex_unlock(&g_sonic.lock);
        player->decoder.should_stop = 1;
      }

    } else {
      sa_sleep(10);
    }

    ma_uint32 available_read = 0;
    ma_audio_ring_buffer_get_length_in_pcm_frames(&player->pcm_buffer, &available_read);

    if (player->state == SONIC_STATE_BUFFERING && available_read >= (ma_uint32)player->start_threshold_frames) {
      LOGI(
          "SonicAudio Player: Buffering complete. Buffered %d frames (%.2fs) "
          ">= Threshold %d frames (%.2fs)\n",
          available_read, (float)available_read / player->sample_rate, player->start_threshold_frames,
          player->start_threshold_seconds);
      player->state = SONIC_STATE_PLAYING;
    }
  }

  player->decoder.is_running = 0;
  LOGI("SonicAudio Player: Decoder thread stopped\n");

  return NULL;
}

static void playback_callback(ma_device* device, void* output, const void* input, ma_uint32 frame_count) {
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

    ma_uint32 mapped = ma_audio_ring_buffer_map_consume(&player->pcm_buffer, frames_to_read, &read_buffer);

    if (mapped > 0) {
      if (device->playback.format == ma_format_f32) {
        float* out_ptr = (float*)output;
        float* in = (float*)read_buffer;
        float volume = player->volume;
        for (ma_uint32 i = 0; i < mapped * device->playback.channels; i++) {
          out_ptr[i] = in[i] * volume;
        }
        output = (char*)output + (mapped * device->playback.channels * sizeof(float));

      } else if (device->playback.format == ma_format_s16) {
        int16_t* out_ptr = (int16_t*)output;
        int16_t* in = (int16_t*)read_buffer;
        float volume = player->volume;
        for (ma_uint32 i = 0; i < mapped * device->playback.channels; i++) {
          out_ptr[i] = (int16_t)(in[i] * volume);
        }
        output = (char*)output + (mapped * device->playback.channels * sizeof(int16_t));

      } else if (device->playback.format == ma_format_s32) {
        int32_t* out_ptr = (int32_t*)output;
        int32_t* in = (int32_t*)read_buffer;
        float volume = player->volume;
        for (ma_uint32 i = 0; i < mapped * device->playback.channels; i++) {
          out_ptr[i] = (int32_t)(in[i] * volume);
        }
        output = (char*)output + (mapped * device->playback.channels * sizeof(int32_t));
      }

      ma_audio_ring_buffer_unmap_consume(&player->pcm_buffer, mapped);

      if (player->sample_rate > 0 && !player->seek_in_progress) {
        player->position += (double)mapped / player->sample_rate;
      }

      total_frames_processed += mapped;
    } else {
      break;
    }
  }

  if (total_frames_processed < frame_count) {
    ma_uint32 frames_remaining = frame_count - total_frames_processed;
    size_t sample_size = (device->playback.format == ma_format_s32)   ? 4
                         : (device->playback.format == ma_format_s16) ? 2
                                                                      : 4;
    memset(output, 0, frames_remaining * device->playback.channels * sample_size);

    if (player->state == SONIC_STATE_PLAYING) {
      if (player->decoder.is_eof) {
        player->state = SONIC_STATE_ENDED;
      } else {
        player->state = SONIC_STATE_BUFFERING;
      }
    }
  }
}

FFI_PLUGIN_EXPORT int sonic_audio_player_load(const char* url, const char* headers) {
  if (!url) return -1;

  if (!g_sonic.is_initialized) {
    if (sonic_audio_init_context() != 0) return -2;
  }

  PlayerState* player = &g_sonic.player;

  if (player->is_initialized) {
    player->state = SONIC_STATE_IDLE;
    ma_device_stop(&player->device);
  }

  int use_fixed_rate = !player->use_native_sample_rate && !player->use_exclusive_audio;

  if (player->device_ever_initialized) {
    ma_device_stop(&player->device);
  }

  player_unload_stream(player);

  sa_thread_mutex_lock(&g_sonic.lock);

  player->state = SONIC_STATE_BUFFERING;

  if (player->total_buffer_seconds <= 1.0f) {
    player->total_buffer_seconds = 30.0f;
  }
  if (player->start_threshold_seconds <= 0.1f) {
    player->start_threshold_seconds = 2.0f;
  }

  player->channels = 2;

  if (use_fixed_rate) {
    player->format = ma_format_f32;
    player->sample_rate = 48000;
  } else {
    if (player->use_exclusive_audio || player->use_native_sample_rate) {
      player->format = ma_format_s16;
    } else {
      player->format = ma_format_f32;
    }
  }

  int target_rate = use_fixed_rate ? 48000 : -1;

  int ret = decoder_open(&player->decoder, url, headers, target_rate, player->channels, (int)player->format);
  if (ret != 0) {
    LOGE("SonicAudio Player: Failed to open decoder for %s (Error code: %d)\n", url, ret);
    sa_thread_mutex_unlock(&g_sonic.lock);
    return ret;
  }

  if (!use_fixed_rate) {
    enum AVSampleFormat native_fmt = player->decoder.codec_ctx->sample_fmt;
    int native_bits = av_get_bytes_per_sample(native_fmt) * 8;

    if (native_bits > 16) {
      player->format = ma_format_s32;
    } else {
      player->format = ma_format_s16;
    }

    int initial_format_req = (int)player->format;
    if (player->format != ma_format_s16) {
      LOGI("SonicAudio Player: Upgrading decoder format to S32 for Hi-Res audio.\n");
      if (decoder_change_format(&player->decoder, (int)player->format) != 0) {
        LOGE("SonicAudio Player: Failed to upgrade decoder format. Reverting player format.\n");
        player->format = ma_format_s16;
      }
    }
    (void)initial_format_req;

    player->sample_rate = player->decoder.codec_ctx ? player->decoder.codec_ctx->sample_rate : 48000;
  }

  player->ring_buffer_size_frames = (int)(player->sample_rate * player->total_buffer_seconds);
  player->start_threshold_frames = (int)(player->sample_rate * player->start_threshold_seconds);

  LOGI(
      "SonicAudio Player: Buffer Config -> Capacity: %.1fs (%d frames), Start "
      "Threshold: %.1fs (%d frames)\n",
      player->total_buffer_seconds, player->ring_buffer_size_frames, player->start_threshold_seconds,
      player->start_threshold_frames);

  ret = player_init_ring_buffer(player);
  if (ret != MA_SUCCESS) {
    LOGE("SonicAudio Player: Failed to initialize ring buffer\n");
    decoder_close(&player->decoder);
    sa_thread_mutex_unlock(&g_sonic.lock);
    return -4;
  }

  int device_format_ok = player->device_ever_initialized && player->device.playback.format == player->format &&
                         player->device.sampleRate == (ma_uint32)player->sample_rate;
  int needs_device_init = !device_format_ok;

  if (needs_device_init) {
    if (player->device_ever_initialized) {
      ma_device_uninit(&player->device);
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
      ma_audio_ring_buffer_uninit(&player->pcm_buffer);
      decoder_close(&player->decoder);
      sa_thread_mutex_unlock(&g_sonic.lock);
      return -5;
    }

    player->device_ever_initialized = 1;
    player->is_initialized = 1;

    const char* fmt_str = "unknown";
    int bit_depth = 0;
    if (player->device.playback.format == ma_format_s16) {
      fmt_str = "s16";
      bit_depth = 16;
    } else if (player->device.playback.format == ma_format_f32) {
      fmt_str = "f32";
      bit_depth = 32;
    } else if (player->device.playback.format == ma_format_s32) {
      fmt_str = "s32";
      bit_depth = 32;
    } else if (player->device.playback.format == ma_format_s24) {
      fmt_str = "s24";
      bit_depth = 24;
    }

    LOGI("SonicAudio Player: Device Initialized. Rate: %d, %d bit, %s, Shared: %s\n", player->device.sampleRate,
         bit_depth, fmt_str, player->device.playback.shareMode == ma_share_mode_exclusive ? "EXCLUSIVE" : "SHARED");
  } else {
    const char* fmt_str = "unknown";
    int bit_depth = 0;
    if (player->format == ma_format_s16) {
      fmt_str = "s16";
      bit_depth = 16;
    } else if (player->format == ma_format_f32) {
      fmt_str = "f32";
      bit_depth = 32;
    } else if (player->format == ma_format_s32) {
      fmt_str = "s32";
      bit_depth = 32;
    } else if (player->format == ma_format_s24) {
      fmt_str = "s24";
      bit_depth = 24;
    }

    LOGI("SonicAudio Player: Reusing audio device. Rate: %d, %d bit, %s\n", player->sample_rate, bit_depth, fmt_str);
    player->is_initialized = 1;
  }

  player->state = SONIC_STATE_BUFFERING;
  player->position = 0.0;
  player->decoder.is_eof = 0;
  player->decoder.should_stop = 0;
  player->decoder.is_running = 1;

  ret = sa_thread_create(&player->decoder.thread, decoder_thread_func, player);
  if (ret != 0) {
    LOGE("SonicAudio Player: Failed to start decoder thread\n");
    player->decoder.is_running = 0;
    if (needs_device_init) {
      ma_device_uninit(&player->device);
      player->device_ever_initialized = 0;
    }
    ma_audio_ring_buffer_uninit(&player->pcm_buffer);
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
    if (needs_device_init) {
      ma_device_uninit(&player->device);
      player->device_ever_initialized = 0;
    }
    ma_audio_ring_buffer_uninit(&player->pcm_buffer);
    decoder_close(&player->decoder);
    player->is_initialized = 0;
    sa_thread_mutex_unlock(&g_sonic.lock);
    return -7;
  }

  LOGI("SonicAudio Player: Loaded %s\n", url);
  sa_thread_mutex_unlock(&g_sonic.lock);

  return 0;
}

typedef struct {
  char url[4096];
  char headers[4096];
  int generation;
} AsyncLoadTask;

static void* load_thread_func(void* arg) {
  AsyncLoadTask* task = (AsyncLoadTask*)arg;

  sa_thread_mutex_lock(&g_sonic.load_mutex);

  if (g_sonic.player.load_generation != task->generation) {
    LOGI("SonicAudio Player: Dropping stale load task for %s\n", task->url);
    sa_thread_mutex_unlock(&g_sonic.load_mutex);
    free(task);
    return NULL;
  }

  g_sonic.player.should_interrupt = 0;

  int result = sonic_audio_player_load(task->url, task->headers[0] != '\0' ? task->headers : NULL);

  if (g_sonic.player.load_generation == task->generation) {
    g_sonic.player.load_status = (result == 0) ? SA_LOAD_OK : SA_LOAD_ERR;
    LOGI("SonicAudio Player: Async load finished with status %d (raw result %d)\n", g_sonic.player.load_status, result);
  } else {
    LOGI(
        "SonicAudio Player: Interrupted async load finished (result %d) but ignoring status update because newer task "
        "is active.\n",
        result);
  }

  sa_thread_mutex_unlock(&g_sonic.load_mutex);
  free(task);
  return NULL;
}

FFI_PLUGIN_EXPORT void sonic_audio_player_load_async(const char* url, const char* headers) {
  if (!url) return;

  AsyncLoadTask* task = malloc(sizeof(AsyncLoadTask));
  if (!task) return;

  sa_strncpy(task->url, sizeof(task->url), url, SA_TRUNCATE);
  if (headers && headers[0] != '\0') {
    sa_strncpy(task->headers, sizeof(task->headers), headers, SA_TRUNCATE);
  } else {
    task->headers[0] = '\0';
  }

  g_sonic.player.load_generation++;
  g_sonic.player.should_interrupt = 1;
  task->generation = g_sonic.player.load_generation;

  g_sonic.player.load_status = SA_LOAD_RUNNING;

  sa_thread_t async_thread;
  sa_thread_create(&async_thread, load_thread_func, task);
  sa_thread_detach(&async_thread);
}

FFI_PLUGIN_EXPORT int sonic_audio_player_get_load_status(void) { return g_sonic.player.load_status; }

FFI_PLUGIN_EXPORT void sonic_audio_player_play(void) {
  if (!g_sonic.player.is_initialized) return;

  if (g_sonic.player.state == SONIC_STATE_PAUSED) {
    g_sonic.player.state = SONIC_STATE_PLAYING;
    ma_device_start(&g_sonic.player.device);
  }
}

FFI_PLUGIN_EXPORT void sonic_audio_player_pause(void) {
  if (!g_sonic.player.is_initialized) return;

  if (g_sonic.player.state == SONIC_STATE_PLAYING || g_sonic.player.state == SONIC_STATE_BUFFERING) {
    g_sonic.player.state = SONIC_STATE_PAUSED;
    ma_device_stop(&g_sonic.player.device);
  }
}

FFI_PLUGIN_EXPORT void sonic_audio_player_stop(void) {
  PlayerState* player = &g_sonic.player;

  player->state = SONIC_STATE_IDLE;

  if (player->device_ever_initialized) {
    ma_device_stop(&player->device);
  }

  ma_device_uninit(&player->device);
  memset(&player->device, 0, sizeof(ma_device));

  sa_thread_mutex_lock(&g_sonic.load_mutex);
  player_unload_stream(player);

  if (!player->is_initialized) {
    sa_thread_mutex_unlock(&g_sonic.load_mutex);
    return;
  }

  player->device_ever_initialized = 0;
  player->is_initialized = 0;

  LOGI("SonicAudio Player: Stopped\n");
  sa_thread_mutex_unlock(&g_sonic.load_mutex);
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
  ma_device_id* pDeviceID = NULL;
  ma_device_id deviceID;

  if (index >= 0) {
    ma_device_info* pPlaybackInfos;
    ma_uint32 playbackCount;
    ma_device_info* pCaptureInfos;
    ma_uint32 captureCount;

    if (ma_context_get_devices(&g_sonic.ma_ctx, &pPlaybackInfos, &playbackCount, &pCaptureInfos, &captureCount) ==
        MA_SUCCESS) {
      if (index < (int)playbackCount) {
        deviceID = pPlaybackInfos[index].id;
        pDeviceID = &deviceID;
      } else {
        return -1;
      }
    } else {
      return -1;
    }
  }

  if (pDeviceID) {
    g_sonic.player.has_selected_device = 1;
    g_sonic.player.selected_device_id = deviceID;
  } else {
    g_sonic.player.has_selected_device = 0;
  }

  if (g_sonic.player.device_ever_initialized) {
    int was_playing = (g_sonic.player.state == SONIC_STATE_PLAYING);

    ma_device_stop(&g_sonic.player.device);
    ma_device_uninit(&g_sonic.player.device);
    g_sonic.player.device_ever_initialized = 0;

    if (g_sonic.player.is_initialized) {
      ma_device_config config = ma_device_config_init(ma_device_type_playback);
      config.playback.format = g_sonic.player.format;
      config.playback.channels = g_sonic.player.channels;
      config.sampleRate = g_sonic.player.sample_rate;
      config.dataCallback = playback_callback;
      config.pUserData = &g_sonic.player;
      config.playback.pDeviceID = pDeviceID;

      if (ma_device_init(&g_sonic.ma_ctx, &config, &g_sonic.player.device) != MA_SUCCESS) {
        LOGE("SonicAudio Player: Failed to re-initialize playback device\n");
        config.playback.pDeviceID = NULL;
        if (ma_device_init(&g_sonic.ma_ctx, &config, &g_sonic.player.device) != MA_SUCCESS) {
          g_sonic.player.is_initialized = 0;
          return -2;
        }
      }

      g_sonic.player.device_ever_initialized = 1;

      if (was_playing) {
        ma_device_start(&g_sonic.player.device);
      }
    }
  }

  return 0;
}

FFI_PLUGIN_EXPORT int sonic_audio_player_get_state(void) { return (int)g_sonic.player.state; }

FFI_PLUGIN_EXPORT double sonic_audio_player_get_position(void) { return g_sonic.player.position; }

FFI_PLUGIN_EXPORT double sonic_audio_player_get_duration(void) { return decoder_get_duration(&g_sonic.player.decoder); }

FFI_PLUGIN_EXPORT void sonic_audio_player_set_buffer_duration(float seconds) {
  if (seconds < 0.1f) seconds = 0.1f;
  if (seconds > 30.0f) seconds = 30.0f;

  sa_thread_mutex_lock(&g_sonic.lock);
  g_sonic.player.start_threshold_seconds = seconds;
  if (g_sonic.player.sample_rate > 0) {
    g_sonic.player.start_threshold_frames = (int)(g_sonic.player.sample_rate * seconds);
  }
  sa_thread_mutex_unlock(&g_sonic.lock);
}

FFI_PLUGIN_EXPORT void sonic_audio_player_set_native_rate_enabled(int enabled) {
  g_sonic.player.use_native_sample_rate = enabled;
}

FFI_PLUGIN_EXPORT void sonic_audio_player_set_exclusive_audio_enabled(int enabled) {
  g_sonic.player.use_exclusive_audio = enabled;
}
