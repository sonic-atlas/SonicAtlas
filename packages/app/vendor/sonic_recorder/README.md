# Sonic Recorder

A native Flutter audio recording plugin built on top of `miniaudio`.

## Features
- **Low Latency Recording**: Direct access to ALSA/PulseAudio/WASAPI.
- **Detailed Device Info**: Explicit backend identification (ALSA vs Pulse).
- **Ring Buffer**: Thread-safe audio capture using miniaudio's lock-free ring buffer.

## Structure
- `src/`: Native C implementation.
  - `context.c`: Miniaudio context initialization.
  - `discovery.c`: Device enumeration.
  - `capture.c`: Recording logic and callback.
  - `internal.h`: Shared state.
- `lib/`: Dart FFI bindings (manually implemented for cleaner API).

## Usage
Calling `start()` begins capturing audio to an internal ring buffer. 
Use `read()` to pull floating-point PCM samples from the buffer.
