import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:sonic_audio/sonic_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sonic_atlas/core/models/track.dart';

class MediaSessionHandler extends BaseAudioHandler with SeekHandler {
  final SonicPlayer player;
  final Future<void> Function() onSkipNext;
  final Future<void> Function() onSkipPrevious;
  Future<void> Function()? onPlay;
  Future<void> Function()? onPause;
  Future<void> Function(Duration)? onSeek;

  final BehaviorSubject<bool> _playing = BehaviorSubject.seeded(false);
  final BehaviorSubject<Duration> _duration = BehaviorSubject.seeded(
    Duration.zero,
  );

  Timer? _idleDebouncer;

  MediaSessionHandler(
    this.player, {
    required this.onSkipNext,
    required this.onSkipPrevious,
  }) {
    player.stateStream.listen((state) {
      _idleDebouncer?.cancel();

      if (state == PlayerState.idle ||
          state == PlayerState.buffering ||
          state == PlayerState.error) {
        playbackState.add(
          playbackState.value.copyWith(
            processingState: AudioProcessingState.buffering,
            playing: _playing.value,
          ),
        );

        _idleDebouncer = Timer(const Duration(seconds: 5), () {
          if (player.state == PlayerState.idle) {
            _broadcastState();
          }
        });
      } else {
        final isPlaying = state == PlayerState.playing;
        _playing.add(isPlaying);
        _broadcastState();
      }
    });

    player.durationStream.listen((duration) {
      _duration.add(duration);
      _updateMediaItemDuration(duration);
    });

    player.positionStream.listen((pos) {
      playbackState.add(playbackState.value.copyWith(updatePosition: pos));
    });
  }

  void _updateMediaItemDuration(Duration duration) {
    if (mediaItem.value != null) {
      mediaItem.add(mediaItem.value!.copyWith(duration: duration));
    }
  }

  PlaybackState _mapPlayerStateToPlaybackState(Duration? overridePosition) {
    AudioProcessingState processingState;
    switch (player.state) {
      case PlayerState.buffering:
        processingState = AudioProcessingState.buffering;
        break;
      case PlayerState.playing:
      case PlayerState.paused:
        processingState = AudioProcessingState.ready;
        break;
      case PlayerState.ended:
        processingState = AudioProcessingState.completed;
        break;
      case PlayerState.error:
        processingState = AudioProcessingState.buffering;
        break;
      case PlayerState.idle:
        processingState = AudioProcessingState.idle;
        break;
    }

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
      processingState: processingState,
      playing: _playing.value,
      updatePosition: overridePosition ?? player.position,
      bufferedPosition: Duration.zero,
      speed: 1.0,
    );
  }

  void _broadcastState([Duration? overridePosition]) {
    playbackState.add(_mapPlayerStateToPlaybackState(overridePosition));
  }

  void updateItem(Track track, String artUri) {
    mediaItem.add(
      MediaItem(
        id: track.id,
        album: track.album,
        title: track.title,
        artist: track.artist,
        duration: player.duration,
        artUri: Uri.parse(artUri),
      ),
    );

    _broadcastState();
  }

  @override
  Future<void> play() async {
    if (onPlay != null) {
      await onPlay!();
    } else {
      player.play();
    }
    _broadcastState();
  }

  @override
  Future<void> pause() async {
    if (onPause != null) {
      await onPause!();
    } else {
      player.pause();
    }
    _broadcastState();
  }

  @override
  Future<void> seek(Duration position) async {
    if (onSeek != null) {
      await onSeek!(position);
    } else {
      player.seek(position);
    }
    _broadcastState(position);
  }

  @override
  Future<void> stop() async {
    player.stop();
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
