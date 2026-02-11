#ifndef SONIC_AUDIO_INTERNAL_H
#define SONIC_AUDIO_INTERNAL_H

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswresample/swresample.h>

#include "vendor/miniaudio.h"

#ifdef __ANDROID__
#include <android/log.h>
#define LOG_TAG "SonicAudio"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#else
#define LOGI(...) printf(__VA_ARGS__)
#define LOGE(...) printf(__VA_ARGS__)
#endif

#ifdef _WIN32
#include <windows.h>
#else
#include <unistd.h>
#endif

static inline void sa_sleep(int64_t ms) {
#ifdef _WIN32
  Sleep((DWORD)ms);
#else
  usleep((useconds_t)(ms * 1000));
#endif
}

#define SA_TRUNCATE -1
static inline int sa_strncpy(char* dest, size_t dest_size, const char* src,
                             size_t count) {
  // Code courtesy of miniaudio.h line 12561-12-5-90
  size_t max;
  size_t i;

  if (dest == 0) {
    return 22;
  }
  if (dest_size == 0) {
    return 34;
  }
  if (src == 0) {
    dest[0] = '\0';
    return 22;
  }

  max = count;
  if (count == ((size_t)-1) || count >= dest_size) {        /* -1 = _TRUNCATE */
    max = dest_size - 1;
  }

  for (i = 0; i < max && src[i] != '\0'; ++i) {
    dest[i] = src[i];
  }

  if (src[i] == '\0' || i == count || count == ((size_t)-1)) {
    dest[i] = '\0';
    return 0;
  }

  dest[0] = '\0';
  return 34;
}

#include "sonic_thread_types.h"

typedef enum {
  SONIC_STATE_IDLE = 0,
  SONIC_STATE_BUFFERING = 1,
  SONIC_STATE_PLAYING = 2,
  SONIC_STATE_PAUSED = 3,
  SONIC_STATE_ENDED = 4,
  SONIC_STATE_ERROR = 5
} SonicPlayerState;

typedef struct {
  AVFormatContext* fmt_ctx;
  AVCodecContext* codec_ctx;
  SwrContext* swr_ctx;
  int audio_stream_idx;
  double duration;
  int64_t current_pts;  // pts = presentation timestamp

  sa_thread_t thread;
  volatile int should_stop;
  volatile int is_running;
  volatile int is_eof;
} DecoderState;

typedef struct {
  ma_device device;
  int is_initialized;
  SonicPlayerState state;
  ma_pcm_rb pcm_buffer;
  DecoderState decoder;
  float volume;
  double position;

  int sample_rate;
  int channels;
  ma_format format;

  int has_selected_device;
  ma_device_id selected_device_id;

  int use_native_sample_rate;
  int use_exclusive_audio;
  float start_threshold_seconds;
  float total_buffer_seconds;

  int ring_buffer_size_frames;
  int start_threshold_frames;

  volatile int seek_request;
  volatile int seek_in_progress;
  volatile double seek_target;
} PlayerState;

typedef struct {
  ma_device device;
  int is_initialized;
  ma_pcm_rb capture_buffer;
  ma_format format;
  int sample_rate;
  int channels;
} RecorderState;

typedef struct {
  ma_context ma_ctx;
  int is_initialized;
  PlayerState player;
  RecorderState recorder;
  sa_thread_mutex_t lock;
} SonicContext;

extern SonicContext g_sonic;

int sonic_audio_init_context(void);
void sonic_audio_dispose_context(void);

#endif