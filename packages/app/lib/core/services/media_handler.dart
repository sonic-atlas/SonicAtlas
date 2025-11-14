import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' as media_kit;
import 'package:rxdart/rxdart.dart';
import 'package:sonic_atlas/core/models/track.dart';

class MediaSessionHandler extends BaseAudioHandler with SeekHandler {
  final media_kit.Player player;
  final Future<void> Function() onSkipNext;
  final Future<void> Function() onSkipPrevious;

  final BehaviorSubject<bool> _playing = BehaviorSubject.seeded(false);
  final BehaviorSubject<Duration> _duration = BehaviorSubject.seeded(Duration.zero);

  MediaSessionHandler(this.player, {required this.onSkipNext, required this.onSkipPrevious}) {
    player.stream.playing.listen((isPlaying) {
      _playing.add(isPlaying);
      _broadcastState();
    });

    player.stream.duration.listen((duration) {
      _duration.add(duration);
      _updateMediaItemDuration(duration);
    });

    player.stream.position.listen((pos) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: pos,
      ));
    });
  }

  void _updateMediaItemDuration(Duration duration) {
    if (mediaItem.value != null) {
      mediaItem.add(mediaItem.value!.copyWith(duration: duration));
    }
  }

  PlaybackState _mapPlayerStateToPlaybackState() {
    return PlaybackState(
      controls: [
        if (_playing.value) MediaControl.pause else MediaControl.play,
        MediaControl.skipToPrevious,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: AudioProcessingState.ready,
      playing: _playing.value,
      updatePosition: player.state.position,
      bufferedPosition: player.state.buffer,
      speed: player.state.rate,
    );
  }

  void _broadcastState() {
    playbackState.add(_mapPlayerStateToPlaybackState());
  }

  void updateItem(Track track, String artUri) {
    mediaItem.add(MediaItem(
      id: track.id,
      album: track.album,
      title: track.title,
      artist: track.artist,
      duration: player.state.duration,
      artUri: Uri.parse(artUri)
    ));

    _broadcastState();
  }

  @override
  Future<void> play() async {
    await player.play();
    _broadcastState();
  }

  @override
  Future<void> pause() async {
    await player.pause();
    _broadcastState();
  }

  @override
  Future<void> seek(Duration position) async {
    await player.seek(position);
    _broadcastState();
  }

  @override
  Future<void> stop() async {
    await player.stop();
    _broadcastState();
  }

  @override
  Future<void> skipToNext() async {
    await onSkipNext();
    _broadcastState();
  }

  @override
  Future<void> skipToPrevious() async {
    await onSkipPrevious();
    _broadcastState();
  }
}