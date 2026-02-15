#ifndef SONIC_THREAD_H
#define SONIC_THREAD_H

#include "sonic_thread_types.h"

#ifdef _WIN32
#include <process.h>
#include <windows.h>
#else
#include <errno.h>
#include <pthread.h>
#endif

#include <stdint.h>
#include <stdlib.h>

// Threading

#ifdef _WIN32

typedef struct {
  sa_thread_fn fn;
  void* arg;
} sa_thread_start_t;

static unsigned __stdcall sa_thread_trampoline(void* arg) {
  sa_thread_start_t start = *(sa_thread_start_t*)arg;
  free(arg);
  return (unsigned)(uintptr_t)start.fn(start.arg);
}

#endif

static sa_thread_result_t sa_thread_create(sa_thread_t* t, sa_thread_fn fn,
                                           void* arg) {
  if (!t || !fn) return SA_THREAD_ERR_INVALID;

#ifdef _WIN32
  sa_thread_start_t* start = (sa_thread_start_t*)malloc(sizeof(*start));
  if (!start) return SA_THREAD_ERR_NOMEM;

  start->fn = fn;
  start->arg = arg;

  uintptr_t h = _beginthreadex(NULL, 0, sa_thread_trampoline, start, 0, NULL);

  if (!h) {
    free(start);
    return SA_THREAD_ERR_CREATE;
  }

  t->handle = (HANDLE)h;
  return SA_THREAD_OK;
#else
  int rc = pthread_create(&t->handle, NULL, fn, arg);
  if (rc != 0) return SA_THREAD_ERR_CREATE;
  return SA_THREAD_OK;
#endif
}

static sa_thread_result_t sa_thread_join(sa_thread_t* t, void** retval) {
  if (!t) return SA_THREAD_ERR_INVALID;

#ifdef _WIN32
  DWORD rc = WaitForSingleObject(t->handle, INFINITE);
  if (rc != WAIT_OBJECT_0) return SA_THREAD_ERR_JOIN;

  if (retval) {
    DWORD code;
    if (GetExitCodeThread(t->handle, &code))
      *retval = (void*)(uintptr_t)code;
    else
      *retval = NULL;
  }

  CloseHandle(t->handle);
  return SA_THREAD_OK;
#else
  int rc = pthread_join(t->handle, retval);
  if (rc != 0) return SA_THREAD_ERR_JOIN;
  return SA_THREAD_OK;
#endif
}

// Mutex

static sa_thread_result_t sa_thread_mutex_init(sa_thread_mutex_t* mtx) {
  if (!mtx) return SA_THREAD_ERR_INVALID;

#ifdef _WIN32
  __try {
    InitializeCriticalSection(&mtx->cs);
  } __except (EXCEPTION_EXECUTE_HANDLER) {
    return SA_THREAD_ERR_NOMEM;
  }
  return SA_THREAD_OK;
#else
  int rc = pthread_mutex_init(&mtx->m, NULL);
  if (rc != 0) return SA_THREAD_ERR_CREATE;
  return SA_THREAD_OK;
#endif
}

static sa_thread_result_t sa_thread_mutex_destroy(sa_thread_mutex_t* mtx) {
  if (!mtx) return SA_THREAD_ERR_INVALID;

#ifdef _WIN32
  DeleteCriticalSection(&mtx->cs);
  return SA_THREAD_OK;
#else
  int rc = pthread_mutex_destroy(&mtx->m);
  if (rc != 0) return SA_THREAD_ERR_UNKNOWN;
  return SA_THREAD_OK;
#endif
}

static sa_thread_result_t sa_thread_mutex_lock(sa_thread_mutex_t* mtx) {
  if (!mtx) return SA_THREAD_ERR_INVALID;

#ifdef _WIN32
  EnterCriticalSection(&mtx->cs);
  return SA_THREAD_OK;
#else
  int rc = pthread_mutex_lock(&mtx->m);
  if (rc != 0) return SA_THREAD_ERR_UNKNOWN;
  return SA_THREAD_OK;
#endif
}

static sa_thread_result_t sa_thread_mutex_unlock(sa_thread_mutex_t* mtx) {
  if (!mtx) return SA_THREAD_ERR_INVALID;

#ifdef _WIN32
  LeaveCriticalSection(&mtx->cs);
  return SA_THREAD_OK;
#else
  int rc = pthread_mutex_unlock(&mtx->m);
  if (rc != 0) return SA_THREAD_ERR_UNKNOWN;
  return SA_THREAD_OK;
#endif
}

#endif