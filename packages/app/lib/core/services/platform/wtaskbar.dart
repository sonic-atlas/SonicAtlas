import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

import '../playback/audio.dart';

class WTaskbarService {
  static final WTaskbarService _instance = WTaskbarService._internal();
  factory WTaskbarService() => _instance;
  WTaskbarService._internal();

  bool _initialised = false;
  late AudioService _audioService;

  void setup(AudioService audioService) async {
    if (!Platform.isWindows) return;
    if (_initialised) return;
    _initialised = true;

    _audioService = audioService;

    _updateToolbar();
  }

  void _updateToolbar() async {
    /**
     * TODO: Swap between play/pause depending on audioService.isPlaying
     * TODO: Use mode: ThumbnailToolbarButtonMode.disabled | ThumbnailToolbarButtonMode.dismissionClick for skip next/previous if !audioService.hasNext & !audioService.hasPrevious respectively
     */

    try {
      await WindowsTaskbar.setThumbnailToolbar([
        ThumbnailToolbarButton(
          ThumbnailToolbarAssetIcon('assets/wtaskbar/skip_previous.ico'),
          'Previous',
          _audioService.skipPrevious,
        ),
        ThumbnailToolbarButton(
          ThumbnailToolbarAssetIcon('assets/wtaskbar/play.ico'),
          'Play',
          _audioService.play,
        ),
        ThumbnailToolbarButton(
          ThumbnailToolbarAssetIcon('assets/wtaskbar/pause.ico'),
          'Pause',
          _audioService.pause,
        ),
        ThumbnailToolbarButton(
          ThumbnailToolbarAssetIcon('assets/wtaskbar/skip_next.ico'),
          'Next',
          _audioService.skipNext,
        ),
      ]);
    } catch (e) {
      if (kDebugMode) print('Failed to set thumbnail toolbar: $e');
    }
  }
}
