import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sonic_recorder/sonic_recorder.dart';

import '../../models/recorder.dart';
import 'audio_engine.dart';
import 'monitoring_service.dart';
import 'file_writer_service.dart';

export '../../models/recorder.dart';

class SonicRecorderService extends ChangeNotifier {
  final AudioEngine _engine = AudioEngine();
  final MonitoringService _monitor = MonitoringService();
  final FileWriterService _writer = FileWriterService();

  RecordingBitDepth _bitDepth = RecordingBitDepth.int16;
  RecordingBitDepth get bitDepth => _bitDepth;

  void setBitDepth(RecordingBitDepth depth) {
    if (_isRecording) return;
    _bitDepth = depth;
    notifyListeners();
  }

  List<AudioDevice> _devices = [];
  List<AudioDevice> get devices => _devices;

  bool _isInitialized = false;
  String? _error;
  String? get error => _error;

  SonicRecorderService() {
    _init();
  }

  Future<void> _init() async {
    try {
      await _engine.init();
      _isInitialized = true;
      await refreshDevices();
      
      _engine.audioStream.listen(_onAudioChunk);
      
    } catch (e) {
      _error = 'Initialization error: $e';
      notifyListeners();
      debugPrint('SonicRecorderService Init Error: $e');
    }
  }

  Future<void> refreshDevices() async {
    if (!_isInitialized) return;
    try {
      _devices = _engine.getDevices();
      notifyListeners();
    } catch (e) {
      debugPrint('Device enumeration error: $e');
    }
  }

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  final _volumeController = StreamController<double>.broadcast();
  Stream<double> get volumeStream => _volumeController.stream;

  bool get isMonitoring => _monitor.isMonitoring;

  Timer? _durationTimer;
  Duration _recordDuration = Duration.zero;
  Duration get recordDuration => _recordDuration;

  final List<String> _sessionFiles = [];
  List<String> get sessionFiles => List.unmodifiable(_sessionFiles);

  void clearSession() {
    _sessionFiles.clear();
    notifyListeners();
  }

  Future<void> toggleMonitor({int sampleRate = 48000}) async {
    if (_monitor.isMonitoring) {
      _monitor.stop();
    } else {
      try {
        await _monitor.start(sampleRate, _bitDepth);
      } catch (e) {
        _error = 'Monitor error: $e';
      }
    }
    notifyListeners();
  }

  void stopMonitor() {
    if (_monitor.isMonitoring) {
      _monitor.stop();
      notifyListeners();
    }
  }

  Future<void> startRecording(AudioDevice device, {int sampleRate = 48000}) async {
    if (!_isInitialized || _isRecording) return;

    try {
      final parts = device.id.split(':');
      if (parts.length < 2) throw 'Invalid device ID format';
      final index = int.tryParse(parts.last) ?? 0;

      final dir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory(path.join(dir.path, 'SonicAtlas', 'Recordings'));
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final wavPath = path.join(recordingsDir.path, 'recording_$timestamp.wav');

      await _writer.start(wavPath, sampleRate, _bitDepth);

      _engine.start(index, sampleRate, _bitDepth);
      
      _isRecording = true;
      _error = null;
      _recordDuration = Duration.zero;

      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _recordDuration += const Duration(seconds: 1);
        notifyListeners();
      });

      notifyListeners();
    } catch (e) {
      _error = 'Start recording error: $e';
      notifyListeners();
      stopRecording();
    }
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;

    _engine.stop();
    await _writer.stop();
    
    if (_writer.currentPath != null) {
      _sessionFiles.add(_writer.currentPath!);
    }
    
    _isRecording = false;
    _durationTimer?.cancel();
    _durationTimer = null;

    notifyListeners();
  }

  void _onAudioChunk(AudioChunk chunk) {
    _volumeController.add(chunk.rms);

    _monitor.write(chunk.pcmBytes);

    if (_isRecording) {
      _writer.write(chunk.pcmBytes);
    }
  }

  @override
  void dispose() {
    stopRecording();
    _monitor.stop();
    super.dispose();
  }
}
