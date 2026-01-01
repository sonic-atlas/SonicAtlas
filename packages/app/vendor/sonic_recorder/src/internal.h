#ifndef SONIC_INTERNAL_H
#define SONIC_INTERNAL_H

#include "../vendor/miniaudio.h"
#include "sonic_recorder.h"

extern ma_context context;
extern int isContextInitialized;

extern ma_device device;
extern int isDeviceInitialized;

extern ma_pcm_rb rb;
extern int isRbInitialized;

#endif
