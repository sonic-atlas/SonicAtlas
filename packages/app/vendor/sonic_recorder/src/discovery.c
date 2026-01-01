#include <string.h>

#include "internal.h"

FFI_PLUGIN_EXPORT int sonic_recorder_get_device_count() {
  if (!isContextInitialized) {
    if (sonic_recorder_init_context() != 0) return -1;
  }

  ma_device_info* pPlaybackInfos;
  ma_uint32 playbackCount;
  ma_device_info* pCaptureInfos;
  ma_uint32 captureCount;

  if (ma_context_get_devices(&context, &pPlaybackInfos, &playbackCount,
                             &pCaptureInfos, &captureCount) != MA_SUCCESS) {
    return -1;
  }

  return (int)captureCount;
}

FFI_PLUGIN_EXPORT void sonic_recorder_get_device_info(int index,
                                                      SonicDeviceInfo* info) {
  if (!isContextInitialized || !info) return;

  ma_device_info* pPlaybackInfos;
  ma_uint32 playbackCount;
  ma_device_info* pCaptureInfos;
  ma_uint32 captureCount;

  if (ma_context_get_devices(&context, &pPlaybackInfos, &playbackCount,
                             &pCaptureInfos, &captureCount) != MA_SUCCESS) {
    return;
  }

  if (index >= 0 && index < (int)captureCount) {
    strncpy(info->name, pCaptureInfos[index].name, 255);

    memcpy(info->id, &pCaptureInfos[index].id,
           sizeof(pCaptureInfos[index].id) > 256
               ? 256
               : sizeof(pCaptureInfos[index].id));

    info->isDefault = pCaptureInfos[index].isDefault;

    if (context.backend == ma_backend_alsa) {
      info->backend = 1;
    } else if (context.backend == ma_backend_pulseaudio) {
      info->backend = 2;
    } else if (context.backend == ma_backend_wasapi) {
      info->backend = 3;
    } else {
      info->backend = 0;
    }
  }
}
