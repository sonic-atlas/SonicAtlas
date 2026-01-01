#include <stdio.h>

#include "internal.h"

ma_context context;
int isContextInitialized = 0;

FFI_PLUGIN_EXPORT int sonic_recorder_init_context() {
  if (isContextInitialized) return 0;

  ma_backend backends[] = {ma_backend_alsa, ma_backend_pulseaudio,
                           ma_backend_wasapi};

  ma_context_config config = ma_context_config_init();
  config.threadPriority = ma_thread_priority_realtime;

  if (ma_context_init(backends, sizeof(backends) / sizeof(backends[0]), &config,
                      &context) != MA_SUCCESS) {
    if (ma_context_init(NULL, 0, NULL, &context) != MA_SUCCESS) {
      printf("SonicRecorder Error: Failed to initialize context\n");
      return -1;
    }
  }

  printf(
      "SonicRecorder: Context initialized. Backend: %d (ALSA=%d, Pulse=%d, "
      "WASAPI=%d)\n",
      context.backend, ma_backend_alsa, ma_backend_pulseaudio,
      ma_backend_wasapi);

  isContextInitialized = 1;
  return 0;
}
