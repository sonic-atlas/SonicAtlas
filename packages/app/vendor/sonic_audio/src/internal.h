#ifndef SONIC_AUDIO_INTERNAL_H
#define SONIC_AUDIO_INTERNAL_H

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswresample/swresample.h>
#include <pthread.h>

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

  pthread_t thread;
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
  pthread_mutex_t lock;
} SonicContext;

extern SonicContext g_sonic;

int sonic_audio_init_context(void);
void sonic_audio_dispose_context(void);

#endif