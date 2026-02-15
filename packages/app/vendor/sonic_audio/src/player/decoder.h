#ifndef SONIC_AUDIO_DECODER_H
#define SONIC_AUDIO_DECODER_H

#include "../internal.h"

int decoder_open(DecoderState* state, const char* url, const char* headers,
                 int target_sample_rate, int target_channels,
                 int target_format);

int decoder_change_format(DecoderState* state, int target_format);

int decoder_read_frames(DecoderState* state, ma_pcm_rb* buffer, int max_frames);

int decoder_seek(DecoderState* state, double seconds);

double decoder_get_position(DecoderState* state);

double decoder_get_duration(DecoderState* state);

void decoder_close(DecoderState* state);

#endif
