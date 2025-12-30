import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../../models/recorder.dart';

class FileWriterService {
  Process? _ffmpegProcess;
  String? _currentPath;
  String? get currentPath => _currentPath;

  Future<void> start(String path, int sampleRate, RecordingBitDepth bitDepth) async {
    _currentPath = path;
    
    String ffmpegFormat = 's16le';
    if (bitDepth == RecordingBitDepth.int24 || bitDepth == RecordingBitDepth.int32) {
      ffmpegFormat = 's32le';
    }

    final args = [
      '-y',
      '-f', ffmpegFormat,
      '-ar', sampleRate.toString(),
      '-ac', '2',
      '-i', 'pipe:0',
    ];

    if (bitDepth == RecordingBitDepth.int24) {
      args.addAll(['-c:a', 'pcm_s24le']);
    }

    args.add(path);

    debugPrint('Starting FFmpeg writer to $path');
    _ffmpegProcess = await Process.start('ffmpeg', args);

    _ffmpegProcess!.stderr.listen((data) {
      debugPrint('FFmpeg stderr: ${String.fromCharCodes(data)}');
    });
  }

  Future<void> stop() async {
    if (_ffmpegProcess != null) {
      try {
        await _ffmpegProcess!.stdin.close();
        final exitCode = await _ffmpegProcess!.exitCode;
        debugPrint('FFmpeg writer exited with code $exitCode');
        if (exitCode != 0) {
          throw 'FFmpeg exited with error code $exitCode';
        }
      } catch (e) {
        debugPrint('Error finalizing FFmpeg: $e');
        rethrow;
      } finally {
        _ffmpegProcess = null;
      }
    }
  }

  void write(Uint8List data) {
    if (_ffmpegProcess != null) {
      _ffmpegProcess!.stdin.add(data);
    }
  }
}
