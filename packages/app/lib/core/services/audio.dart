import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' as media_kit;
import 'package:sonic_atlas/core/services/media_handler.dart';

import '../models/quality.dart';
import '../models/track.dart' as models;
import 'api.dart';
import 'auth.dart';
import 'settings.dart';

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

  int get currentIndex => _currentIndex;

  Quality get quality => _settingsService.audioQuality;
  Quality? _currentTrackQuality;

  Quality? get currentTrackQuality => _currentTrackQuality;

  bool get isPlaying => _player.state.playing;

  Stream<bool> get playingStream => _player.stream.playing;

  Stream<Duration> get positionStream => _player.stream.position;

  Duration get duration => _player.state.duration;

  bool get hasNext => _currentIndex < _queue.length - 1;

  bool get hasPrevious => _currentIndex > 0;

  AudioService(this._apiService, this._authService, this._settingsService)
    : _player = media_kit.Player() {
    _init();
    _settingsService.addListener(_onSettingsChanged);
  }

  static final _playTrackController =
      StreamController<models.Track>.broadcast();
  static final _playController = StreamController<AudioService>.broadcast();
  static final _pauseController = StreamController<AudioService>.broadcast();
  static final _seekController = StreamController<Duration>.broadcast();

  static Stream<models.Track> get onPlayTrack => _playTrackController.stream;

  static Stream<AudioService> get onPlay => _playController.stream;

  static Stream<AudioService> get onPause => _pauseController.stream;

  static Stream<Duration> get onSeek => _seekController.stream;

  static AudioService create(
    ApiService api,
    AuthService auth,
    SettingsService settings,
  ) {
    return AudioService._internal(api, auth, settings);
  }

  AudioService._internal(
    this._apiService,
    this._authService,
    this._settingsService,
  ) : _player = media_kit.Player() {
    _init();
    _settingsService.addListener(_onSettingsChanged);
  }

  void setAudioHandler(MediaSessionHandler handler) {
    _audioHandler = handler;
  }

  Future<void> _init() async {
    try {
      _player.stream.completed.listen((completed) async {
        if (completed) {
          if (hasNext) {
            await skipNext();
          } else {
            _currentTrack = null;
            _currentIndex = -1;
          }
          notifyListeners();
        }
      });

      _player.stream.playing.listen((isPlaying) {
        if (isPlaying) {
          _playController.add(this);
        } else {
          _pauseController.add(this);
        }
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
  }) async {
    try {
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

      await _player.open(
        media_kit.Media(url, httpHeaders: {'Authorization': 'Bearer $token'}),
      );
      await _player.play();

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

      String albumArtUri = _apiService.getAlbumArtUrl(track.id);
      _audioHandler.updateItem(track, albumArtUri);

      _playTrackController.add(track);
      notifyListeners();
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
    _audioHandler.play();
    notifyListeners();
  }

  void pause() {
    _audioHandler.pause();
    notifyListeners();
  }

  void seek(Duration position) {
    _audioHandler.seek(position);
    _seekController.add(position);
    notifyListeners();
  }

  Future<void> restartCurrentTrack() async {
    if (_currentTrack != null) {
      final currentPosition = _player.state.position;
      await playTrack(_currentTrack!, queue: _queue, preserveIndex: true);
      seek(currentPosition);
    }
  }

  @override
  void dispose() {
    _settingsService.removeListener(_onSettingsChanged);
    _player.dispose();
    super.dispose();
  }
}
