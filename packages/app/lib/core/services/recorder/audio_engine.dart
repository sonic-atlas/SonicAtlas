import 'dart:async';
import 'package:sonic_audio/sonic_audio.dart';
import '../../models/recorder.dart';

class AudioChunk {
  final double rms;
  AudioChunk(this.rms);
}

class AudioEngine {
  final SonicRecorder _recorder = SonicRecorder();
  SonicRecorder get recorder => _recorder;

  Timer? _readTimer;

  final _audioController = StreamController<AudioChunk>.broadcast();
  Stream<AudioChunk> get audioStream => _audioController.stream;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  Future<void> init() async {}

  List<AudioDevice> getDevices() {
    return _recorder.getCaptureDevices();
  }

  void start(
    int deviceIndex,
    int sampleRate,
    RecordingBitDepth bitDepth, {
    String? filePath,
  }) {
    if (_isRecording) return;

    int formatId = 16;
    if (bitDepth == RecordingBitDepth.int24 ||
        bitDepth == RecordingBitDepth.int32) {
      formatId = 32;
    }

    int result;
    if (filePath != null && filePath.isNotEmpty) {
      result = _recorder.startFile(
        filePath: filePath,
        deviceIndex: deviceIndex,
        sampleRate: sampleRate,
        channels: 2,
        bitDepth: formatId,
      );
    } else {
      result = _recorder.start(
        deviceIndex: deviceIndex,
        sampleRate: sampleRate,
        channels: 2,
        bitDepth: formatId,
      );
    }

    if (result != 0) {
      throw 'Failed to start recording (Error: $result)';
    }

    _isRecording = true;

    _readTimer = Timer.periodic(
      const Duration(milliseconds: 30),
      (_) => _readRms(),
    );
  }

  void stop() {
    if (!_isRecording) return;
    _recorder.stop();
    _isRecording = false;
    _readTimer?.cancel();
    _readTimer = null;
  }

  void _readRms() {
    if (!_isRecording) return;
    final rms = _recorder.getRms();
    _audioController.add(AudioChunk(rms));
  }
}
