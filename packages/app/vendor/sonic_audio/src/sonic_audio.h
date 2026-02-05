#ifndef SONIC_AUDIO_H
#define SONIC_AUDIO_H

#include <stdint.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT __attribute__((visibility("default")))
#endif

FFI_PLUGIN_EXPORT int sonic_audio_init(void);
FFI_PLUGIN_EXPORT void sonic_audio_dispose(void);

FFI_PLUGIN_EXPORT int sonic_audio_player_load(const char* url,
                                              const char* headers);
FFI_PLUGIN_EXPORT void sonic_audio_player_play(void);
FFI_PLUGIN_EXPORT void sonic_audio_player_pause(void);
FFI_PLUGIN_EXPORT void sonic_audio_player_stop(void);
FFI_PLUGIN_EXPORT void sonic_audio_player_seek(double seconds);
FFI_PLUGIN_EXPORT void sonic_audio_player_set_volume(float volume);
FFI_PLUGIN_EXPORT int sonic_audio_player_set_output_device(int index);

FFI_PLUGIN_EXPORT void sonic_audio_player_set_buffer_duration(float seconds);
FFI_PLUGIN_EXPORT void sonic_audio_player_set_native_rate_enabled(int enabled);
FFI_PLUGIN_EXPORT void sonic_audio_player_set_exclusive_audio_enabled(
    int enabled);

FFI_PLUGIN_EXPORT int sonic_audio_player_get_state(void);
FFI_PLUGIN_EXPORT double sonic_audio_player_get_position(void);
FFI_PLUGIN_EXPORT double sonic_audio_player_get_duration(void);

typedef struct {
  char name[256];
  char id[256];
  int is_default;
  int backend;
} SonicDeviceInfo;

FFI_PLUGIN_EXPORT int sonic_audio_get_playback_device_count(void);
FFI_PLUGIN_EXPORT void sonic_audio_get_playback_device_info(
    int index, SonicDeviceInfo* info);

FFI_PLUGIN_EXPORT int sonic_audio_get_capture_device_count(void);
FFI_PLUGIN_EXPORT void sonic_audio_get_capture_device_info(
    int index, SonicDeviceInfo* info);

FFI_PLUGIN_EXPORT int sonic_audio_recorder_start(int device_index,
                                                 int sample_rate, int channels,
                                                 int bit_depth);
FFI_PLUGIN_EXPORT int sonic_audio_recorder_stop(void);
FFI_PLUGIN_EXPORT int sonic_audio_recorder_read_s16(int16_t* output,
                                                    int frame_count);
FFI_PLUGIN_EXPORT int sonic_audio_recorder_read_s32(int32_t* output,
                                                    int frame_count);

#endif