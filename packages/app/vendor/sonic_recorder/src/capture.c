#include <stdio.h>
#include <string.h>

#include "internal.h"

ma_device device;
int isDeviceInitialized = 0;
ma_pcm_rb rb;
int isRbInitialized = 0;
ma_format captureFormat = ma_format_s16;

FFI_PLUGIN_EXPORT int sonic_recorder_stop();

void data_callback(ma_device* pDevice, void* pOutput, const void* pInput,
                   ma_uint32 frameCount) {
  if (!isRbInitialized) return;

  void* pWriteBuffer;
  ma_uint32 framesToWrite = frameCount;

  while (framesToWrite > 0) {
    ma_uint32 framesThisChunk = framesToWrite;
    if (ma_pcm_rb_acquire_write(&rb, &framesThisChunk, &pWriteBuffer) !=
        MA_SUCCESS) {
      break;
    }

    size_t sampleSize = (captureFormat == ma_format_s32) ? 4 : 2;
    memcpy(pWriteBuffer, pInput, framesThisChunk * rb.channels * sampleSize);

    ma_pcm_rb_commit_write(&rb, framesThisChunk);
    framesToWrite -= framesThisChunk;

    pInput = (const char*)pInput + (framesThisChunk * rb.channels * sampleSize);

    if (framesThisChunk == 0) break;
  }
}

FFI_PLUGIN_EXPORT int sonic_recorder_start(int deviceIndex, int sampleRate,
                                           int channels, int bitDepth) {
  if (!isContextInitialized) {
    if (sonic_recorder_init_context() != 0) return -1;
  }

  if (isDeviceInitialized) {
    sonic_recorder_stop();
  }

  if (bitDepth == 24 || bitDepth == 32) {
    captureFormat = ma_format_s32;
  } else {
    captureFormat = ma_format_s16;
  }

  if (!isRbInitialized) {
    ma_uint32 bufferSizeInFrames = sampleRate * 0.5;
    if (ma_pcm_rb_init(captureFormat, channels, bufferSizeInFrames, NULL, NULL,
                       &rb) != MA_SUCCESS) {
      printf("SonicRecorder Error: Failed to init Ring Buffer\n");
      return -2;
    }
    isRbInitialized = 1;
  }

  ma_device_config deviceConfig = ma_device_config_init(ma_device_type_capture);
  deviceConfig.capture.format = captureFormat;
  deviceConfig.capture.channels = channels;
  deviceConfig.sampleRate = sampleRate;
  deviceConfig.periodSizeInFrames = 0;
  deviceConfig.dataCallback = data_callback;

  ma_device_info* pPlaybackInfos;
  ma_uint32 playbackCount;
  ma_device_info* pCaptureInfos;
  ma_uint32 captureCount;

  if (ma_context_get_devices(&context, &pPlaybackInfos, &playbackCount,
                             &pCaptureInfos, &captureCount) == MA_SUCCESS) {
    if (deviceIndex >= 0 && deviceIndex < (int)captureCount) {
      deviceConfig.capture.pDeviceID = &pCaptureInfos[deviceIndex].id;
    }
  }

  if (ma_device_init(&context, &deviceConfig, &device) != MA_SUCCESS) {
    printf("SonicRecorder Error: Failed to init device\n");
    return -3;
  }
  isDeviceInitialized = 1;

  if (ma_device_start(&device) != MA_SUCCESS) {
    printf("SonicRecorder Error: Failed to start device\n");
    ma_device_uninit(&device);
    isDeviceInitialized = 0;
    return -4;
  }

  printf("SonicRecorder: Started recording on device %d (%s)\n", deviceIndex,
         (captureFormat == ma_format_s32) ? "S32" : "S16");
  return 0;
}

FFI_PLUGIN_EXPORT int sonic_recorder_stop() {
  if (isDeviceInitialized) {
    ma_device_uninit(&device);
    isDeviceInitialized = 0;
  }

  if (isRbInitialized) {
    ma_pcm_rb_uninit(&rb);
    isRbInitialized = 0;
  }
  return 0;
}

FFI_PLUGIN_EXPORT int sonic_recorder_read(short* pOutput, int frameCount) {
  if (!isRbInitialized || captureFormat != ma_format_s16) return 0;

  void* pReadBuffer;
  ma_uint32 framesRead = frameCount;

  if (ma_pcm_rb_acquire_read(&rb, &framesRead, &pReadBuffer) == MA_SUCCESS) {
    ma_uint32 channels = rb.channels;
    memcpy(pOutput, pReadBuffer, framesRead * channels * sizeof(short));
    ma_pcm_rb_commit_read(&rb, framesRead);
    return (int)framesRead;
  }
  return 0;
}

FFI_PLUGIN_EXPORT int sonic_recorder_read_s32(int* pOutput, int frameCount) {
  if (!isRbInitialized || captureFormat != ma_format_s32) return 0;

  void* pReadBuffer;
  ma_uint32 framesRead = frameCount;

  if (ma_pcm_rb_acquire_read(&rb, &framesRead, &pReadBuffer) == MA_SUCCESS) {
    ma_uint32 channels = rb.channels;
    memcpy(pOutput, pReadBuffer, framesRead * channels * sizeof(int));
    ma_pcm_rb_commit_read(&rb, framesRead);
    return (int)framesRead;
  }
  return 0;
}
