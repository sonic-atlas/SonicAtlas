#include <stdio.h>

#include "internal.h"
#include "sonic_audio.h"

SonicContext g_sonic = {0};

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
      // Pretty much redundant as all devices above android 8 support aaudio
    case ma_backend_opensl:
      return 5;
#endif
    default:
      return 0;
  }
}

int sonic_audio_init_context(void) {
  if (g_sonic.is_initialized) return 0;

  if (pthread_mutex_init(&g_sonic.lock, NULL) != 0) {
    printf("SonicAudio Error: Failed to initialize mutex\n");
    return -1;
  }

  ma_backend backends[] = {
#ifdef __ANDROID__
      ma_backend_aaudio,
      ma_backend_opensl,
#else
      ma_backend_alsa,
      ma_backend_wasapi,
      ma_backend_pulseaudio,
#endif
  };

  ma_context_config config = ma_context_config_init();
  config.threadPriority = ma_thread_priority_realtime;

  ma_result result =
      ma_context_init(backends, sizeof(backends) / sizeof(backends[0]), &config,
                      &g_sonic.ma_ctx);
  if (result != MA_SUCCESS) {
    result = ma_context_init(NULL, 0, NULL, &g_sonic.ma_ctx);
    if (result != MA_SUCCESS) {
      printf("SonicAudio Error: Failed to initialize context\n");
      pthread_mutex_destroy(&g_sonic.lock);
      return -1;
    }
  }

  printf("SonicAudio: Context initialized. Backend: %d\n",
         get_backend_id(g_sonic.ma_ctx.backend));

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

  pthread_mutex_destroy(&g_sonic.lock);

  g_sonic.is_initialized = 0;
  printf("SonicAudio: Context disposed\n");
}

FFI_PLUGIN_EXPORT int sonic_audio_init(void) {
  return sonic_audio_init_context();
}

FFI_PLUGIN_EXPORT void sonic_audio_dispose(void) {
  sonic_audio_dispose_context();
}
