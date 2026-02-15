/*import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../models/recorder.dart';

class MonitoringService {
  Process? _monitorProcess;
  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;

  Future<void> start(int sampleRate, RecordingBitDepth bitDepth) async {
    if (_isMonitoring) return;
    _isMonitoring = true;

    try {
      String format = 's16le';
      if (bitDepth == RecordingBitDepth.int24 ||
          bitDepth == RecordingBitDepth.int32) {
        format = 's32le';
      }

      debugPrint('Starting Monitor at ${sampleRate}Hz ($format)');

      if (Platform.isLinux) {
        String aplayFormat = 'S16_LE';
        if (bitDepth == RecordingBitDepth.int24 ||
            bitDepth == RecordingBitDepth.int32) {
          aplayFormat = 'S32_LE';
        }

        _monitorProcess = await Process.start('aplay', [
          '-t',
          'raw',
          '-f',
          aplayFormat,
          '-r',
          sampleRate.toString(),
          '-c',
          '2',
          '-',
          '--buffer-size',
          '2048',
        ]);
      } else {
        _monitorProcess = await Process.start('ffplay', [
          '-nodisp',
          '-loglevel',
          'warning',
          '-nostats',
          '-f',
          format,
          '-ar',
          sampleRate.toString(),
          '-ch_layout',
          'stereo',
          '-i',
          'pipe:0',
          '-fflags',
          'nobuffer',
          '-flags',
          'low_delay',
          '-framedrop',
          '-probesize',
          '32',
          '-analyzeduration',
          '0',
        ]);
      }

      _monitorProcess?.stderr.listen((data) {
        debugPrint('Monitor stderr: ${String.fromCharCodes(data)}');
      });

      _monitorProcess?.exitCode.then((code) {
        debugPrint('Monitor process exited with code $code');
        if (_isMonitoring) {
          _isMonitoring = false;
        }
      });
    } catch (e) {
      debugPrint('Failed to start monitor: $e');
      _isMonitoring = false;
      rethrow;
    }
  }

  void stop() {
    if (_monitorProcess != null) {
      _monitorProcess!.kill();
      _monitorProcess = null;
    }
    _isMonitoring = false;
  }

  void write(Uint8List data) {
    if (_isMonitoring && _monitorProcess != null) {
      try {
        _monitorProcess!.stdin.add(data);
      } catch (e) {
        // Ignore
      }
    }
  }
}
*/