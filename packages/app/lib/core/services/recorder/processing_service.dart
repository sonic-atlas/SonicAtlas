import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../../models/recorder.dart';
import '../../models/release.dart';
import '../network/api.dart';

export '../../models/recorder.dart';

class ProcessingService extends ChangeNotifier {
  final ApiService _apiService;

  ProcessingService(this._apiService);

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  double? _progress = 0.0;
  double? get progress => _progress;

  String? _error;
  String? get error => _error;

  Future<List<String>> splitAndTranscode(
    String wavPath,
    List<TrackSplit> splits,
    Release metadata, {
    int discNumber = 1,
    bool upload = true,
  }) async {
    _isProcessing = true;
    _progress = 0.0;
    _error = null;
    notifyListeners();

    final generatedFiles = <String>[];

    try {
      final dir = path.dirname(wavPath);
      final folderName = '${metadata.primaryArtist} - ${metadata.title}'
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final outputDir = Directory(path.join(dir, folderName));

      if (!await outputDir.exists()) {
        await outputDir.create();
      }

      for (var i = 0; i < splits.length; i++) {
        final track = splits[i];
        final nextTrack = (i < splits.length - 1) ? splits[i + 1] : null;

        notifyListeners();

        final safeTitle = track.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
        final outName =
            '${discNumber.toString()}-${track.number.toString().padLeft(2, '0')} - $safeTitle.flac';
        final outPath = path.join(outputDir.path, outName);
        generatedFiles.add(outPath);

        final args = [
          '-y',
          '-i',
          wavPath,
          '-ss',
          _formatDuration(track.start),
        ];

        if (track.end != null) {
          args.add('-to');
          args.add(_formatDuration(track.end!));
        } else if (nextTrack != null) {
          args.add('-to');
          args.add(_formatDuration(nextTrack.start));
        }

        args.addAll([
          '-metadata',
          'artist=${track.artist ?? metadata.primaryArtist}',
          '-metadata',
          'album=${metadata.title}',
          '-metadata',
          'title=${track.title}',
          '-metadata',
          'track=${track.number}',
          '-metadata',
          'disc=$discNumber',
        ]);
        if (metadata.year != null) {
          args.addAll(['-metadata', 'date=${metadata.year}']);
        }
        if (metadata.genre != null) {
          args.addAll(['-metadata', 'genre=${metadata.genre}']);
        }

        args.addAll(['-c:a', 'flac', '-compression_level', '8', outPath]);

        debugPrint('Processing Track: $args');
        final process = await Process.start('ffmpeg', args);
        final exitCode = await process.exitCode;

        if (exitCode != 0) {
          throw 'FFmpeg failed for track ${track.number}';
        }

        _progress = (i + 1) / splits.length;
        notifyListeners();
      }

      if (upload) {
        await uploadAll(generatedFiles, metadata);
      }

      return generatedFiles;
    } catch (e) {
      _error = e.toString();
      debugPrint('Processing Error: $e');
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> uploadAll(List<String> files, Release metadata) async {
    _progress = null;
    notifyListeners();

    await _apiService.uploadRelease(
      files,
      metadata.coverArtPath,
      metadata.title,
      metadata.primaryArtist ?? 'Unknown Artist',
      metadata.year?.toString() ?? '',
      metadata.releaseType ?? 'album',
      false,
      null,
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String threeDigits(int n) => n.toString().padLeft(3, '0');

    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    String threeDigitMillis = threeDigits(d.inMilliseconds.remainder(1000));
    return '${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds.$threeDigitMillis';
  }
}
