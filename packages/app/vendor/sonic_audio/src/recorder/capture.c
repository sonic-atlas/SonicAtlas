#include <stdio.h>
#include <string.h>

#include "internal.h"
#include "sonic_audio.h"

#define CAPTURE_BUFFER_SIZE(sr) ((sr) / 2)

static void capture_callback(ma_device* device, void* output, const void* input,
                             ma_uint32 frame_count) {
  (void)output;

  RecorderState* recorder = (RecorderState*)device->pUserData;
  if (!recorder || !recorder->is_initialized) return;

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
}

FFI_PLUGIN_EXPORT int sonic_audio_recorder_start(int device_index,
                                                 int sample_rate, int channels,
                                                 int bit_depth) {
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

  if (ma_device_start(&recorder->device) != MA_SUCCESS) {
    LOGE("SonicAudio Recorder: Failed to start capture device\n");
    ma_device_uninit(&recorder->device);
    ma_pcm_rb_uninit(&recorder->capture_buffer);
    return -4;
  }

  recorder->is_initialized = 1;
  LOGI("SonicAudio Recorder: Started (device %d, %dHz, %dch, %s)\n",
       device_index, sample_rate, channels,
       recorder->format == ma_format_s32 ? "S32" : "S16");

  return 0;
}

FFI_PLUGIN_EXPORT int sonic_audio_recorder_stop(void) {
  RecorderState* recorder = &g_sonic.recorder;

  if (!recorder->is_initialized) return 0;

  ma_device_uninit(&recorder->device);
  ma_pcm_rb_uninit(&recorder->capture_buffer);

  recorder->is_initialized = 0;
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
