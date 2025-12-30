#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#if _WIN32
#include <windows.h>
#else
#include <pthread.h>
#include <unistd.h>
#endif

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

typedef struct {
  char name[256];
  char id[256];
  int isDefault;
  int backend;
} SonicDeviceInfo;

FFI_PLUGIN_EXPORT int sonic_recorder_init_context();
FFI_PLUGIN_EXPORT int sonic_recorder_get_device_count();
FFI_PLUGIN_EXPORT void sonic_recorder_get_device_info(int index,
                                                      SonicDeviceInfo* info);

FFI_PLUGIN_EXPORT int sonic_recorder_start(int deviceIndex, int sampleRate,
                                           int channels, int bitDepth);
FFI_PLUGIN_EXPORT int sonic_recorder_stop();
FFI_PLUGIN_EXPORT int sonic_recorder_read(short* pOutput, int frameCount);
FFI_PLUGIN_EXPORT int sonic_recorder_read_s32(int* pOutput, int frameCount);
