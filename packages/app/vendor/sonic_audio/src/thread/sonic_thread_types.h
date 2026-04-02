#ifndef SONIC_THREAD_TYPES_H
#define SONIC_THREAD_TYPES_H

#ifdef _WIN32
#include <windows.h>
#else
#include <pthread.h>
#endif

// Threading

typedef enum {
  SA_THREAD_OK = 0,
  SA_THREAD_ERR_INVALID,
  SA_THREAD_ERR_NOMEM,
  SA_THREAD_ERR_CREATE,
  SA_THREAD_ERR_JOIN,
  SA_THREAD_ERR_UNKNOWN
} sa_thread_result_t;

typedef void* (*sa_thread_fn)(void*);

typedef struct {
#ifdef _WIN32
  HANDLE handle;
#else
  pthread_t handle;
#endif
} sa_thread_t;

// Mutex

typedef struct {
#ifdef _WIN32
  CRITICAL_SECTION cs;
#else
  pthread_mutex_t m;
#endif
} sa_thread_mutex_t;

#endif