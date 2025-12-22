import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' as media_kit;
import 'package:sonic_atlas/core/services/playback/media_handler.dart';

import '../../models/quality.dart';
import '../../models/track.dart' as models;
import '../network/api.dart';
import '../auth/auth.dart';
import '../config/settings.dart';

class AudioService with ChangeNotifier {
  final media_kit.Player _player;

  media_kit.Player get player => _player;

  final ApiService _apiService;
  final AuthService _authService;
  final SettingsService _settingsService;
  late final MediaSessionHandler _audioHandler;

  models.Track? _currentTrack;

  models.Track? get currentTrack => _currentTrack;

  List<models.Track> _queue = [];

  List<models.Track> get queue => _queue;
  int _currentIndex = -1;
  int _retryCount = 0;

  int get currentIndex => _currentIndex;

  Quality get quality => _settingsService.audioQuality;
  Quality? _currentTrackQuality;

  Quality? get currentTrackQuality => _currentTrackQuality;

  bool get isPlaying => _player.state.playing;

  Stream<bool> get playingStream => _player.stream.playing;

  Stream<Duration> get positionStream =>
      _player.stream.position.map((p) => _optimisticPosition ?? p);

  Stream<bool> get bufferingStream => _player.stream.buffering;

  bool get isBuffering => _player.state.buffering;

  Duration get duration => _optimisticDuration ?? _player.state.duration;

  Duration? _optimisticPosition;
  Duration? _optimisticDuration;

  Duration _lastKnownPosition = Duration.zero;
  Duration _lastKnownDuration = Duration.zero;

  bool _isRecovering = false;
  bool _recoveryInProgress = false;
  bool _userPaused = false;
  String? _lastError;

  bool get hasNext => _currentIndex < _queue.length - 1;

  bool get hasPrevious => _currentIndex > 0;

  static final _playTrackController =
      StreamController<models.Track>.broadcast();
  static final _playController = StreamController<AudioService>.broadcast();
  static final _pauseController = StreamController<AudioService>.broadcast();
  static final _seekController = StreamController<Duration>.broadcast();

  static Stream<models.Track> get onPlayTrack => _playTrackController.stream;
  static Stream<AudioService> get onPlay => _playController.stream;
  static Stream<AudioService> get onPause => _pauseController.stream;
  static Stream<Duration> get onSeek => _seekController.stream;

  AudioService._internal(
    this._apiService,
    this._authService,
    this._settingsService,
  ) : _player = media_kit.Player(
        configuration: const media_kit.PlayerConfiguration(
          bufferSize: 32 * 1024 * 1024,
        ),
      ) {
    _init();
    _settingsService.addListener(_onSettingsChanged);
  }

  static AudioService create(
    ApiService api,
    AuthService auth,
    SettingsService settings,
  ) {
    return AudioService._internal(api, auth, settings);
  }

  void setAudioHandler(MediaSessionHandler handler) {
    _audioHandler = handler;
  }

  Future<void> _init() async {
    try {
      _player.stream.error.listen((error) {
        _lastError = error;

        final errorStr = error.toString().toLowerCase();
        final isRecoverableError =
            errorStr.contains('connection') ||
            errorStr.contains('refused') ||
            errorStr.contains('failed to open') ||
            errorStr.contains('tcp') ||
            errorStr.contains('network') ||
            errorStr.contains('timeout');

        if (isRecoverableError) {
          if (kDebugMode) {
            print('Player error (recoverable): $error');
          }
          _attemptRecovery();
        }
      });

      _player.stream.playing.listen((isPlaying) {
        if (isPlaying) {
          _playController.add(this);
        } else {
          _pauseController.add(this);

          if (_currentTrack != null && !_isRecovering && !_userPaused) {
            final position = _lastKnownPosition;
            final duration = _lastKnownDuration;
            final notNearEnd =
                duration.inSeconds > 0 && (duration - position).inSeconds > 10;

            if (notNearEnd && position.inSeconds > 5) {
              if (kDebugMode) {
                print(
                  'Unexpected stop detected at ${position.inSeconds}s/${duration.inSeconds}s. Attempting recovery.',
                );
              }
              Future.delayed(const Duration(seconds: 1), () {
                if (!_player.state.playing && _currentTrack != null) {
                  _attemptRecovery();
                }
              });
            }
          }
        }
        notifyListeners();
      });

      _player.stream.buffering.listen((isBuffering) {
        notifyListeners();
      });

      if (kDebugMode) {
        print('AudioService initialized (media_kit)');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error initializing AudioService: $e');
        print('Stack trace: $stackTrace');
      }
    }

    _player.stream.position.listen((p) {
      if (_isRecovering && _optimisticPosition != null) {
        if (_player.state.playing &&
            !_player.state.buffering &&
            p.inSeconds >= (_optimisticPosition!.inSeconds - 2)) {
          if (kDebugMode) {
            print(
              'Recovery complete. Player at ${p.inSeconds}s, target was ${_optimisticPosition!.inSeconds}s',
            );
          }
          _isRecovering = false;
          _optimisticPosition = null;
          _optimisticDuration = null;
        }
        return;
      }

      if (_player.state.playing &&
          !_player.state.buffering &&
          p != Duration.zero) {
        _lastKnownPosition = p;

        final duration = _player.state.duration;
        final durationIsStable =
            _lastKnownDuration.inSeconds > 0 &&
            (duration.inSeconds - _lastKnownDuration.inSeconds).abs() < 3;

        if (durationIsStable && duration.inSeconds > 0 && p.inSeconds > 0) {
          final remaining = duration.inSeconds - p.inSeconds;
          if (remaining <= 1 && remaining >= 0) {
            _handleTrackEnd();
          }
        }
      }
    });

    _player.stream.duration.listen((d) {
      if (!_isRecovering && d != Duration.zero) {
        _lastKnownDuration = d;
      }
    });
  }

  void _onSettingsChanged() async {
    final newQuality = _settingsService.audioQuality;
    if (newQuality != _currentTrackQuality && _currentTrack != null) {
      if (kDebugMode) {
        print('Quality setting changed to: ${newQuality.value}');
      }
    }
    notifyListeners();
  }

  Future<void> playTrack(
    models.Track track, {
    List<models.Track>? queue,
    bool preserveIndex = false,
    bool isRecovery = false,
  }) async {
    try {
      if (kDebugMode) {
        print(
          'playTrack called. isRecovery: $isRecovery, track: ${track.title}',
        );
      }
      final qualityInfo = await _apiService.getTrackQuality(track.id);
      final List<Quality> availableQualities =
          qualityInfo['availableQualities'];

      Quality desiredQuality = _settingsService.audioQuality;
      Quality? selectedQuality;

      if (desiredQuality == Quality.auto && availableQualities.isNotEmpty) {
        selectedQuality = Quality.auto;
      } else if (availableQualities.contains(desiredQuality)) {
        selectedQuality = desiredQuality;
      } else {
        final qualityOrder = [
          Quality.hires,
          Quality.cd,
          Quality.high,
          Quality.efficiency,
        ];
        final desiredIndex = qualityOrder.indexOf(desiredQuality);

        for (int i = desiredIndex; i < qualityOrder.length; i++) {
          if (availableQualities.contains(qualityOrder[i])) {
            selectedQuality = qualityOrder[i];
            if (kDebugMode) {
              print(
                'Quality ${desiredQuality.value} unavailable, using ${selectedQuality.value}',
              );
            }
            break;
          }
        }

        if (selectedQuality == null && availableQualities.isNotEmpty) {
          selectedQuality = availableQualities.first;
          if (kDebugMode) {
            print('Using fallback quality: ${selectedQuality.value}');
          }
        }
      }

      if (selectedQuality == null) {
        throw Exception('No available quality found for track');
      }

      _currentTrackQuality = selectedQuality;

      final url = _apiService.getStreamUrl(track.id, selectedQuality);
      final token = _authService.token;

      if (kDebugMode) {
        print('Playing: ${track.title}');
        print('Stream URL: $url');
        print('Quality: ${selectedQuality.value}');
      }

      _currentTrack = track;

      if (queue != null) {
        _queue = queue;
        if (!preserveIndex) {
          _currentIndex = _queue.indexOf(track);
        }
      } else {
        _queue = [track];
        _currentIndex = 0;
      }

      if (!isRecovery) {
        _retryCount = 0;
        _isRecovering = false;
        _userPaused = false;
        _optimisticPosition = null;
        _optimisticDuration = null;
        _lastKnownPosition = Duration.zero;
        _lastKnownDuration = Duration.zero;
      }

      String albumArtUri = _apiService.getAlbumArtUrl(track.id);
      _audioHandler.updateItem(track, albumArtUri);

      _playTrackController.add(track);
      notifyListeners();

      _lastError = null;

      await _player.open(
        media_kit.Media(url, httpHeaders: {'Authorization': 'Bearer $token'}),
        play: false,
      );

      if (isRecovery &&
          _optimisticPosition != null &&
          _optimisticPosition!.inSeconds > 0) {
        if (kDebugMode) {
          print(
            'Waiting for stream to load before seeking to ${_optimisticPosition!.inSeconds}s...',
          );
        }

        bool streamReady = false;
        for (int i = 0; i < 100; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          if (_lastError != null) {
            if (kDebugMode) {
              print('Stream load aborted due to error: $_lastError');
            }
            throw Exception('Stream failed to load: $_lastError');
          }
          if (_player.state.duration.inSeconds > 0) {
            streamReady = true;
            break;
          }
        }

        if (streamReady) {
          if (kDebugMode) {
            print(
              'Stream loaded. Seeking to ${_optimisticPosition!.inSeconds}s...',
            );
          }
          await _player.seek(_optimisticPosition!);
        } else {
          if (kDebugMode) {
            print('Warning: Timeout waiting for stream, seeking anyway...');
          }
          await _player.seek(_optimisticPosition!);
        }
      }

      await _player.play();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error playing track: $e');
        print('Stack trace: $stackTrace');
      }
      rethrow;
    }
  }

  void addToQueue(models.Track track) {
    _queue.add(track);
    notifyListeners();
  }

  void addNextToQueue(models.Track track) {
    if (_currentIndex >= 0 && _currentIndex < _queue.length - 1) {
      _queue.insert(_currentIndex + 1, track);
    } else {
      _queue.add(track);
    }
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index >= 0 && index < _queue.length && index != _currentIndex) {
      _queue.removeAt(index);
      if (index < _currentIndex) {
        _currentIndex--;
      }
      notifyListeners();
    }
  }

  void clearQueue() {
    _optimisticPosition = null;
    _optimisticDuration = null;
    _queue.clear();
    _currentIndex = -1;
    _currentTrack = null;
    _player.stop();
    notifyListeners();
  }

  Future<void> skipNext() async {
    if (hasNext) {
      _currentIndex++;
      await playTrack(
        _queue[_currentIndex],
        queue: _queue,
        preserveIndex: true,
      );
    }
  }

  Future<void> skipPrevious() async {
    if (hasPrevious) {
      _currentIndex--;
      await playTrack(
        _queue[_currentIndex],
        queue: _queue,
        preserveIndex: true,
      );
    }
  }

  void play() {
    _userPaused = false;
    _audioHandler.play();
    notifyListeners();
  }

  void pause() {
    _userPaused = true;
    _audioHandler.pause();
    notifyListeners();
  }

  bool _trackEndHandled = false;

  void _handleTrackEnd() async {
    if (_trackEndHandled) return;
    _trackEndHandled = true;

    if (hasNext) {
      await skipNext();
    } else if (_queue.isNotEmpty) {
      _currentIndex = 0;
      await playTrack(_queue[0], queue: _queue, preserveIndex: true);
    }

    Future.delayed(const Duration(seconds: 3), () {
      _trackEndHandled = false;
    });
  }

  void seek(Duration position) {
    _player.setPlaylistMode(media_kit.PlaylistMode.single);
    _audioHandler.seek(position);
    _seekController.add(position);
    notifyListeners();
  }

  Future<void> restartCurrentTrack({bool isRecovery = false}) async {
    if (_currentTrack != null) {
      if (isRecovery) {
        _isRecovering = true;
      }

      if (isRecovery && _optimisticPosition == null) {
        _optimisticPosition = _lastKnownPosition;
        _optimisticDuration = _lastKnownDuration;
        if (kDebugMode) {
          print('Freezing UI at position: ${_optimisticPosition!.inSeconds}s');
        }
      }

      await playTrack(
        _currentTrack!,
        queue: _queue,
        preserveIndex: true,
        isRecovery: isRecovery,
      );
    }
  }

  Future<void> _attemptRecovery() async {
    if (_recoveryInProgress) {
      if (kDebugMode) {
        print('Recovery already in progress, skipping...');
      }
      return;
    }
    _recoveryInProgress = true;
    _isRecovering = true;

    if (_currentTrack == null) {
      _recoveryInProgress = false;
      return;
    }

    _retryCount++;
    if (kDebugMode) {
      print('Attempting recovery #$_retryCount...');
    }

    await Future.delayed(const Duration(seconds: 2));

    if (_currentTrack == null) {
      _recoveryInProgress = false;
      return;
    }

    try {
      await restartCurrentTrack(isRecovery: true);
      _recoveryInProgress = false;
    } catch (e) {
      if (kDebugMode) {
        print('Recovery attempt failed: $e');
      }
      _recoveryInProgress = false;
      _attemptRecovery();
    }
  }

  @override
  void dispose() {
    _settingsService.removeListener(_onSettingsChanged);
    _player.dispose();
    super.dispose();
  }
}
