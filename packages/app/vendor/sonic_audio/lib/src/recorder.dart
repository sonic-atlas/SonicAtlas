import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'common.dart';

class SonicRecorder {
  final SonicAudioBindings _bindings;
  bool _isRecording = false;
  bool _isS32 = false;

  bool get isRecording => _isRecording;

  SonicRecorder() : _bindings = SonicAudioBridge.instance.bindings {
    _bindings.init();
  }

  List<AudioDevice> getCaptureDevices() {
    final count = _bindings.getCaptureDeviceCount();
    if (count <= 0) return [];

    final devices = <AudioDevice>[];
    final infoPtr = calloc<SonicDeviceInfo>();

    try {
      for (int i = 0; i < count; i++) {
        _bindings.getCaptureDeviceInfo(i, infoPtr);

        final namePtr = Pointer<Utf8>.fromAddress(infoPtr.address);
        final name = namePtr.toDartString();

        final backendId = infoPtr.ref.backend;
        final backend = _backendName(backendId);

        devices.add(
          AudioDevice(
            name: name,
            isDefault: infoPtr.ref.isDefault != 0,
            backend: backend,
            index: i,
          ),
        );
      }
    } finally {
      calloc.free(infoPtr);
    }

    return devices;
  }

  int start({
    int deviceIndex = -1,
    int sampleRate = 48000,
    int channels = 2,
    int bitDepth = 16,
  }) {
    if (_isRecording) stop();

    _isS32 = bitDepth == 24 || bitDepth == 32;

    final result = _bindings.recorderStart(
      deviceIndex,
      sampleRate,
      channels,
      bitDepth,
    );
    if (result == 0) {
      _isRecording = true;
    }
    return result;
  }

  int stop() {
    if (!_isRecording) return 0;

    final result = _bindings.recorderStop();
    _isRecording = false;
    return result;
  }

  int readS16(Pointer<Int16> buffer, int frameCount) {
    if (!_isRecording || _isS32) return 0;
    return _bindings.recorderReadS16(buffer, frameCount);
  }

  int readS32(Pointer<Int32> buffer, int frameCount) {
    if (!_isRecording || !_isS32) return 0;
    return _bindings.recorderReadS32(buffer, frameCount);
  }

  String _backendName(int id) {
    switch (id) {
      case 1:
        return 'ALSA';
      case 2:
        return 'PulseAudio';
      case 3:
        return 'WASAPI';
      case 4:
        return 'AAudio';
      case 5:
        return 'OpenSL';
      default:
        return 'Unknown';
    }
  }
}
