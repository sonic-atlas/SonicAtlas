import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:ffi/ffi.dart';
import 'package:sonic_recorder/sonic_recorder.dart';
import '../../models/recorder.dart';

class AudioChunk {
  final Uint8List pcmBytes;
  final double rms;
  final int sampleCount;

  AudioChunk(this.pcmBytes, this.rms, this.sampleCount);
}

class AudioEngine {
  final SonicRecorder _recorder = SonicRecorder();
  Timer? _readTimer;

  final _audioController = StreamController<AudioChunk>.broadcast();
  Stream<AudioChunk> get audioStream => _audioController.stream;

  Pointer<Int16>? _readBuffer;
  Pointer<Int32>? _readBufferS32;
  // pretty large buffer but ensures smoothness (for me at least)
  static const int _readBufferSize = 16384;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  Future<void> init() async {
    final result = _recorder.init();
    if (result != 0) {
      throw 'Failed to initialize miniaudio context (Error: $result)';
    }
  }

  List<AudioDevice> getDevices() {
    return _recorder.getDevices();
  }

  void start(int deviceIndex, int sampleRate, RecordingBitDepth bitDepth) {
    if (_isRecording) return;

    int formatId = 16;
    int bytesPerSample = 2;

    if (bitDepth == RecordingBitDepth.int24) {
      formatId = 24;
      bytesPerSample = 4;
    } else if (bitDepth == RecordingBitDepth.int32) {
      formatId = 32;
      bytesPerSample = 4;
    }

    final result = _recorder.start(deviceIndex, sampleRate, 2, formatId);
    if (result != 0) {
      throw 'Failed to start recording (Error: $result)';
    }

    _isRecording = true;

    if (bytesPerSample == 4) {
      _readBufferS32 = calloc<Int32>(_readBufferSize * 2);
    } else {
      _readBuffer = calloc<Int16>(_readBufferSize * 2);
    }

    _readTimer = Timer.periodic(
      const Duration(milliseconds: 20),
      (_) => _readLoop(),
    );
  }

  void stop() {
    if (!_isRecording) return;
    _recorder.stop();
    _isRecording = false;
    _readTimer?.cancel();
    _readTimer = null;

    if (_readBuffer != null) {
      calloc.free(_readBuffer!);
      _readBuffer = null;
    }
    if (_readBufferS32 != null) {
      calloc.free(_readBufferS32!);
      _readBufferS32 = null;
    }
  }

  void _readLoop() {
    if (!_isRecording) return;

    if (_readBuffer != null) {
      _readLoopS16();
    } else if (_readBufferS32 != null) {
      _readLoopS32();
    }
  }

  void _readLoopS16() {
    final framesRead = _recorder.read(_readBuffer!, _readBufferSize);
    if (framesRead > 0) {
      double sumSquares = 0.0;
      final totalSamples = framesRead * 2;
      final pcmBytes = _readBuffer!.cast<Uint8>().asTypedList(totalSamples * 2);

      for (var i = 0; i < totalSamples; i++) {
        final samplePcm = _readBuffer![i];
        final sampleFloat = samplePcm / 32768.0;
        sumSquares += sampleFloat * sampleFloat;
      }

      final rms = (totalSamples > 0)
          ? math.sqrt(sumSquares / totalSamples)
          : 0.0;
      _audioController.add(AudioChunk(pcmBytes, rms, totalSamples));
    }
  }

  void _readLoopS32() {
    final framesRead = _recorder.readS32(_readBufferS32!, _readBufferSize);
    if (framesRead > 0) {
      double sumSquares = 0.0;
      final totalSamples = framesRead * 2;
      final pcmBytes = _readBufferS32!.cast<Uint8>().asTypedList(
        totalSamples * 4,
      );

      for (var i = 0; i < totalSamples; i++) {
        final samplePcm = _readBufferS32![i];
        final sampleFloat = samplePcm / 2147483648.0;
        sumSquares += sampleFloat * sampleFloat;
      }

      final rms = (totalSamples > 0)
          ? math.sqrt(sumSquares / totalSamples)
          : 0.0;
      _audioController.add(AudioChunk(pcmBytes, rms, totalSamples));
    }
  }
}
