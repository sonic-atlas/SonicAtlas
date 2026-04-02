import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sonic_atlas/core/services/utils/logger.dart';
import 'package:sonic_audio/sonic_audio.dart';
import 'package:sonic_atlas/core/services/playback/media_handler.dart';

import '../../models/quality.dart';
import '../../models/track.dart' as models;
import '../network/api.dart';
import '../auth/auth.dart';
import '../config/settings.dart';

class AudioService with ChangeNotifier {
  final SonicPlayer _player;

  SonicPlayer get player => _player;

  final ApiService _apiService;
  final AuthService _authService;
  final SettingsService _settingsService;
  late final MediaSessionHandler _audioHandler;

  models.Track? _currentTrack;

  models.Track? get currentTrack => _currentTrack;

  final _trackController = StreamController<models.Track?>.broadcast();
  Stream<models.Track?> get trackStream => _trackController.stream;

  List<models.Track> _queue = [];

  List<models.Track> get queue => _queue;
  int _currentIndex = -1;
  int _retryCount = 0;

  int get currentIndex => _currentIndex;

  Quality get quality => _settingsService.audioQuality;
  Quality? _currentTrackQuality;

  Quality? get currentTrackQuality => _currentTrackQuality;

  double get volume => _settingsService.audioVolume;

  bool get isPlaying => _player.state == PlayerState.playing;

  Duration get position => _optimisticPosition ?? _player.position;

  Stream<Duration> get positionStream =>
      _player.stream.position.map((p) => _optimisticPosition ?? p);
  Duration get currentPosition => _player.state.position;

  Stream<bool> get playingStream => _player.stateStream.map((s) => s == PlayerState.playing);

  Stream<Duration> get positionStream => _player.positionStream.map((p) => _optimisticPosition ?? p);

  Stream<bool> get bufferingStream => _player.stateStream.map((s) => s == PlayerState.buffering);

  bool get isBuffering => _player.isBuffering;

  Duration get duration => _optimisticDuration ?? _player.duration;

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

  static final _playTrackController = StreamController<models.Track>.broadcast();
  static final _playController = StreamController<AudioService>.broadcast();
  static final _pauseController = StreamController<AudioService>.broadcast();
  static final _seekController = StreamController<Duration>.broadcast();
  static final _restartController = StreamController<models.Track>.broadcast();
  static final _trackStartController = StreamController<models.Track>.broadcast();

  static Stream<models.Track> get onPlayTrack => _playTrackController.stream;
  static Stream<AudioService> get onPlay => _playController.stream;
  static Stream<AudioService> get onPause => _pauseController.stream;
  static Stream<Duration> get onSeek => _seekController.stream;
  static Stream<models.Track> get onRestart => _restartController.stream;
  static Stream<models.Track> get onTrackStart => _trackStartController.stream;

  void setCurrentTrack(models.Track? track) {
    _currentTrack = track;
    _trackController.add(track);
  }

  AudioService._internal(
    this._apiService,
    this._authService,
    this._settingsService,
  ) : _player = SonicPlayer() {
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
    _audioHandler.onPlay = () async => play();
    _audioHandler.onPause = () async => pause();
    _audioHandler.onSeek = (position) async => seek(position);
  }

  Future<void> _init() async {
    try {
      _player.stateStream.listen((state) {
        if (state == PlayerState.playing) {
          _playController.add(this);
        } else if (state == PlayerState.paused) {
          _pauseController.add(this);
        } else if (state == PlayerState.ended) {
          _handleTrackEnd();
        } else if (state == PlayerState.error) {
          logger.w('Player error state detected. Attempting recovery...');
          if (_currentTrack != null && !_isRecovering) {
            Future.delayed(const Duration(seconds: 2), () {
              if (_currentTrack != null && !_userPaused) {
                _attemptRecovery();
              }
            });
          }
        }

        if (state != PlayerState.playing &&
            _currentTrack != null &&
            !_isRecovering &&
            !_userPaused &&
            state != PlayerState.ended &&
            state != PlayerState.buffering &&
            state != PlayerState.error) {
          final position = _lastKnownPosition;
          final duration = _lastKnownDuration;
          final notNearEnd = duration.inSeconds > 0 && (duration - position).inSeconds > 5;

          if (notNearEnd && position.inSeconds > 2) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_player.state != PlayerState.playing && !_userPaused && !_isRecovering && _currentTrack != null) {
                logger.w('Unexpected stop confirmed. Attempting recovery...');
                _attemptRecovery();
              }
            });
          }
        }

        notifyListeners();
      });

      logger.i('AudioService initialised');

      _player.setBufferDuration(_settingsService.audioBufferDuration);
      _player.setNativeRateEnabled(_settingsService.useNativeSampleRate);
      _player.setExclusiveAudioEnabled(_settingsService.useExclusiveAudio);
      _player.setVolume(_settingsService.audioVolume);

      final savedDevice = _settingsService.selectedAudioDeviceIndex;
      if (savedDevice >= 0) {
        _player.setOutputDevice(savedDevice);
      }
    } catch (e, stackTrace) {
      logger.f('Error initialising AudioService', error: e, stackTrace: stackTrace);
    }

    _player.positionStream.listen((p) {
      if (_isRecovering && _optimisticPosition != null) {
        if (_player.isPlaying && !_player.isBuffering && p.inSeconds >= (_optimisticPosition!.inSeconds - 2)) {
          logger.i('Recovery complete. Player at ${p.inSeconds}s, target was ${_optimisticPosition!.inSeconds}s');
          _isRecovering = false;
          _optimisticPosition = null;
          _optimisticDuration = null;
        }
        return;
      }

      if (_player.isPlaying && !_player.isBuffering && p != Duration.zero) {
        _lastKnownPosition = p;
      }
    });

    _player.durationStream.listen((d) {
      if (!_isRecovering && d != Duration.zero) {
        _lastKnownDuration = d;
      }
    });
  }

  void _onSettingsChanged() async {
    _player.setBufferDuration(_settingsService.audioBufferDuration);
    _player.setNativeRateEnabled(_settingsService.useNativeSampleRate);
    _player.setExclusiveAudioEnabled(_settingsService.useExclusiveAudio);
    _player.setVolume(_settingsService.audioVolume);

    final savedDevice = _settingsService.selectedAudioDeviceIndex;
    if (savedDevice >= 0) {
      _player.setOutputDevice(savedDevice);
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
      logger.d('playTrack called. isRecovery: $isRecovery, track: ${track.title}');
      final qualityInfo = await _apiService.getTrackQuality(track.id);
      final List<Quality> availableQualities = qualityInfo['availableQualities'];

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
            logger.i('Quality ${desiredQuality.value} unavailable, using ${selectedQuality.value}');
            break;
          }
        }

        if (selectedQuality == null && availableQualities.isNotEmpty) {
          selectedQuality = availableQualities.first;
          logger.i('Using fallback quality: ${selectedQuality.value}');
        }
      }

      if (selectedQuality == null) {
        throw Exception('No available quality found for track');
      }

      _currentTrackQuality = selectedQuality;

      final token = _authService.token;
      final url = _apiService.getStreamUrl(track.id, selectedQuality);

      logger.i('''
Playing: ${track.title}
Stream URL: $url
Quality: ${selectedQuality.value}''');

      setCurrentTrack(track);

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

      await _player.load(
        url,
        headers: 'Authorization: Bearer $token\r\n',
      );
      
      _trackStartController.add(track);

      if (isRecovery && _optimisticPosition != null && _optimisticPosition!.inSeconds > 0) {
        logger.d('Waiting for stream to load before seeking to ${_optimisticPosition!.inSeconds}...');


        bool streamReady = false;
        for (int i = 0; i < 100; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          if (_lastError != null) {
            logger.e('Stream load aborted due to error', error: _lastError);
            throw Exception('Stream failed to load: $_lastError');
          }
          if (_player.duration.inSeconds > 0) {
            streamReady = true;
            break;
          }
        }

        if (streamReady) {
          logger.i('Stream loaded. Seeking to ${_optimisticPosition!.inSeconds}...');
          _player.seek(_optimisticPosition!);
        } else {
          logger.w('Timeout waiting for stream, seeking anyway...');
          _player.seek(_optimisticPosition!);
        }
      }

      _player.play();
    } catch (e, stackTrace) {
      logger.e('Error playing track', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  void addToQueue(models.Track track) {
    _queue.add(track);
    notifyListeners();
  }

  void addAllToQueue(List<models.Track> tracks) {
    _queue.addAll(tracks);
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
    setCurrentTrack(null);
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
    _player.play();
    notifyListeners();
  }

  void pause() {
    _userPaused = true;
    _player.pause();
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
    _player.seek(position);
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
        logger.d('Freezing UI at position: ${_optimisticPosition!.inSeconds}s');
      }

      await playTrack(
        _currentTrack!,
        queue: _queue,
        preserveIndex: true,
        isRecovery: isRecovery,
      );

      _restartController.add(_currentTrack!);
      notifyListeners();
    }
  }

  Future<void> _attemptRecovery() async {
    if (_recoveryInProgress) {
      logger.d('Recovery already in progress, skipping...');
      return;
    }
    _recoveryInProgress = true;
    _isRecovering = true;

    if (_currentTrack == null) {
      _recoveryInProgress = false;
      return;
    }

    _retryCount++;
    logger.i('Attempting recovery #$_retryCount...');

    await Future.delayed(const Duration(seconds: 2));

    if (_currentTrack == null) {
      _recoveryInProgress = false;
      return;
    }

    try {
      await restartCurrentTrack(isRecovery: true);
      _recoveryInProgress = false;
    } catch (e) {
      logger.w('Recovery attempt failed', error: e);
      _recoveryInProgress = false;
      _attemptRecovery();
    }
  }

  void setVolume(double volume) {
    _player.setVolume(volume);
    _settingsService.setAudioVolume(volume);
  }

  void setOutputDevice(AudioDevice device) {
    logger.i('Setting output device to: ${device.name}');
    _player.setOutputDevice(device.index);
    _settingsService.setSelectedAudioDeviceIndex(device.index);
  }

  Future<List<AudioDevice>> getPlaybackDevices() async {
    return SonicPlayer.getAvailableDevices();
  }

  @override
  void dispose() {
    _settingsService.removeListener(_onSettingsChanged);
    _player.dispose();
    _trackController.close();
    super.dispose();
  }
}
