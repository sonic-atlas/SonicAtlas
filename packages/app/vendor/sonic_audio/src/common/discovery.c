#include <string.h>

#include "internal.h"
#include "sonic_audio.h"

#ifndef MIN
#define MIN(a, b) ((a) < (b) ? (a) : (b))
#endif

static int get_backend_id(ma_backend const backend) {
  switch (backend) {
    case ma_backend_alsa:
      return 1;
    case ma_backend_pulseaudio:
      return 2;
    case ma_backend_wasapi:
      return 3;
#ifdef MA_HAS_AAUDIO
    case ma_backend_aaudio:
      return 4;
#endif
#ifdef MA_HAS_OPENSL
    case ma_backend_opensl:
      return 5;
#endif
    default:
      return 0;
  }
}

FFI_PLUGIN_EXPORT int sonic_audio_get_playback_device_count(void) {
  if (!g_sonic.is_initialized) {
    if (sonic_audio_init_context() != 0) return -1;
  }

  ma_device_info* pPlaybackInfos;
  ma_uint32 playbackCount;
  ma_device_info* pCaptureInfos;
  ma_uint32 captureCount;

  if (ma_context_get_devices(&g_sonic.ma_ctx, &pPlaybackInfos, &playbackCount,
                             &pCaptureInfos, &captureCount) != MA_SUCCESS) {
    return -1;
  }

  return (int)playbackCount;
}

FFI_PLUGIN_EXPORT void sonic_audio_get_playback_device_info(
    const int index, SonicDeviceInfo* info) {
  if (!g_sonic.is_initialized || !info) return;

  ma_device_info* pPlaybackInfos;
  ma_uint32 playbackCount;
  ma_device_info* pCaptureInfos;
  ma_uint32 captureCount;

  if (ma_context_get_devices(&g_sonic.ma_ctx, &pPlaybackInfos, &playbackCount,
                             &pCaptureInfos, &captureCount) != MA_SUCCESS) {
    return;
  }

  if (index >= 0 && index < (int)playbackCount) {
    sa_strncpy(info->name, sizeof(info->name), pPlaybackInfos[index].name,
               SA_TRUNCATE);

    memcpy(info->id, &pPlaybackInfos[index].id,
           MIN(sizeof(pPlaybackInfos[index].id), 256));

    info->is_default = pPlaybackInfos[index].isDefault ? 1 : 0;
    info->backend = get_backend_id(g_sonic.ma_ctx.backend);
  }
}

FFI_PLUGIN_EXPORT int sonic_audio_get_capture_device_count(void) {
  if (!g_sonic.is_initialized) {
    if (sonic_audio_init_context() != 0) return -1;
  }

  ma_device_info* pPlaybackInfos;
  ma_uint32 playbackCount;
  ma_device_info* pCaptureInfos;
  ma_uint32 captureCount;

  if (ma_context_get_devices(&g_sonic.ma_ctx, &pPlaybackInfos, &playbackCount,
                             &pCaptureInfos, &captureCount) != MA_SUCCESS) {
    return -1;
  }

  return (int)captureCount;
}

FFI_PLUGIN_EXPORT void sonic_audio_get_capture_device_info(
    const int index, SonicDeviceInfo* info) {
  if (!g_sonic.is_initialized || !info) return;

  ma_device_info* pPlaybackInfos;
  ma_uint32 playbackCount;
  ma_device_info* pCaptureInfos;
  ma_uint32 captureCount;

  if (ma_context_get_devices(&g_sonic.ma_ctx, &pPlaybackInfos, &playbackCount,
                             &pCaptureInfos, &captureCount) != MA_SUCCESS) {
    return;
  }

  if (index >= 0 && index < (int)captureCount) {
    sa_strncpy(info->name, sizeof(info->name), pCaptureInfos[index].name,
               SA_TRUNCATE);

    memcpy(info->id, &pCaptureInfos[index].id,
           MIN(sizeof(pCaptureInfos[index].id), 256));

    info->is_default = pCaptureInfos[index].isDefault ? 1 : 0;
    info->backend = get_backend_id(g_sonic.ma_ctx.backend);
  }
}
