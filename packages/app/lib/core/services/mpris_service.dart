import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:sonic_atlas/core/services/audio.dart' as sa_audio;

class LinuxMprisManager {
  static const MethodChannel _channel = MethodChannel('sonic_atlas/mpris');
  final AudioHandler audioHandler;
  final sa_audio.AudioService? _audioService;

  LinuxMprisManager(this.audioHandler, [this._audioService]) {
    if (!Platform.isLinux) return;

    _channel.setMethodCallHandler(_handleMethodCall);

    audioHandler.playbackState.listen((state) {
      updateState(
        playing: state.playing,
        position: state.position.inMicroseconds,
        speed: state.speed,
      );
    });

    audioHandler.mediaItem.listen((item) {
      if (item != null) {
        updateMetadata(item);
      }
    });
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPlay':
        audioHandler.play();
        break;
      case 'onPause':
        audioHandler.pause();
        break;
      case 'onNext':
        audioHandler.skipToNext();
        break;
      case 'onPrevious':
        audioHandler.skipToPrevious();
        break;
      case 'onSeek':
        final int offsetUs = call.arguments;
        final currentPosition = audioHandler.playbackState.value.position;
        final newPosition = currentPosition + Duration(microseconds: offsetUs);
        if (_audioService != null) {
          _audioService.seek(newPosition);
        } else {
          audioHandler.seek(newPosition);
        }
        break;
      case 'onSetPosition':
        final int positionUs = call.arguments;
        if (_audioService != null) {
          _audioService.seek(Duration(microseconds: positionUs));
        } else {
          audioHandler.seek(Duration(microseconds: positionUs));
        }
        break;
    }
  }

  void updateState({
    required bool playing,
    required int position,
    required double speed,
  }) {
    _channel.invokeMethod('updateState', {
      'playing': playing,
      'position': position,
      'speed': speed,
    });
  }

  void updateMetadata(MediaItem item) {
    _channel.invokeMethod('updateMetadata', {
      'title': item.title,
      'artist': item.artist ?? '',
      'album': item.album ?? '',
      'artUrl': item.artUri?.toString() ?? '',
      'duration': item.duration?.inMicroseconds ?? 0,
    });
  }
}
