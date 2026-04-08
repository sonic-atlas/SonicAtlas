#include <stdio.h>

#include "internal.h"
#include "sonic_audio.h"
#include "thread/sonic_thread.h"

SonicContext g_sonic = {0};

static int get_backend_id(ma_device_backend_vtable* pVTable) {
#ifdef MA_ENABLE_ALSA
  if (pVTable == ma_device_backend_alsa) return 1;
#endif
#ifdef MA_ENABLE_PULSEAUDIO
  if (pVTable == ma_device_backend_pulseaudio) return 2;
#endif
#ifdef MA_ENABLE_WASAPI
  if (pVTable == ma_device_backend_wasapi) return 3;
#endif
#ifdef MA_HAS_AAUDIO
  if (pVTable == ma_device_backend_aaudio) return 4;
#endif
#ifdef MA_HAS_OPENSL
  if (pVTable == ma_device_backend_opensl) return 5;
#endif
#ifdef MA_ENABLE_PIPEWIRE
  if (pVTable == ma_device_backend_pipewire) return 6;
#endif
  return 0;
}

int sonic_audio_init_context(void) {
  if (g_sonic.is_initialized) return 0;

  if (sa_thread_mutex_init(&g_sonic.lock) != SA_THREAD_OK) {
    printf("SonicAudio Error: Failed to initialize mutex\n");
    return -1;
  }
  if (sa_thread_mutex_init(&g_sonic.load_mutex) != SA_THREAD_OK) {
    printf("SonicAudio Error: Failed to initialize load mutex\n");
    sa_thread_mutex_destroy(&g_sonic.lock);
    return -1;
  }

#ifdef __ANDROID__
  ma_device_backend_config backends[] = {
      {ma_device_backend_aaudio, NULL},
      {ma_device_backend_opensl, NULL},
  };
#else
  ma_device_backend_config backends[] = {
      {ma_device_backend_pipewire, NULL},
      {ma_device_backend_alsa, NULL},
      {ma_device_backend_pulseaudio, NULL},
      {ma_device_backend_wasapi, NULL},
  };
#endif

  ma_context_config config = ma_context_config_init();
  config.threadPriority = ma_thread_priority_realtime;

  ma_result result = ma_context_init(backends, sizeof(backends) / sizeof(backends[0]), &config, &g_sonic.ma_ctx);
  if (result != MA_SUCCESS) {
    result = ma_context_init(NULL, 0, NULL, &g_sonic.ma_ctx);
    if (result != MA_SUCCESS) {
      printf("SonicAudio Error: Failed to initialize context\n");
      sa_thread_mutex_destroy(&g_sonic.lock);
      return -1;
    }
  }

  printf("SonicAudio: Context initialized. Backend: %d\n", get_backend_id(g_sonic.ma_ctx.pVTable));

  g_sonic.player.state = SONIC_STATE_IDLE;
  g_sonic.player.volume = 1.0f;
  g_sonic.player.is_initialized = 0;

  g_sonic.recorder.is_initialized = 0;

  g_sonic.is_initialized = 1;
  return 0;
}

void sonic_audio_dispose_context(void) {
  if (!g_sonic.is_initialized) return;

  sonic_audio_player_stop();

  sonic_audio_recorder_stop();

  ma_context_uninit(&g_sonic.ma_ctx);

  sa_thread_mutex_destroy(&g_sonic.lock);
  sa_thread_mutex_destroy(&g_sonic.load_mutex);
  g_sonic.is_initialized = 0;
  printf("SonicAudio: Context disposed\n");
}

FFI_PLUGIN_EXPORT int sonic_audio_init(void) { return sonic_audio_init_context(); }

FFI_PLUGIN_EXPORT void sonic_audio_dispose(void) { sonic_audio_dispose_context(); }
