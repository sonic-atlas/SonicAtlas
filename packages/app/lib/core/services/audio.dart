import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' as media_kit;

import '../models/quality.dart';
import '../models/track.dart' as models;
import 'api.dart';
import 'auth.dart';
import 'settings.dart';

/// AudioService manages playback across the app
/// Uses media_kit for all platforms (Android, iOS, Linux, Windows, macOS)
/// media_kit handles OS-level media controls natively
class AudioService with ChangeNotifier {
  // Media kit player - works on all platforms
  final media_kit.Player _player;

  // Service dependencies
  final ApiService _apiService;
  final AuthService _authService;
  final SettingsService _settingsService;

  // Current track state
  models.Track? _currentTrack;
  models.Track? get currentTrack => _currentTrack;

  // Queue management
  List<models.Track> _queue = [];
  List<models.Track> get queue => _queue;
  int _currentIndex = -1;
  int get currentIndex => _currentIndex;

  // Quality tracking
  // The SETTING quality (what user wants)
  Quality get quality => _settingsService.audioQuality;
  // The ACTUAL quality playing (may differ if not available)
  Quality? _currentTrackQuality;
  Quality? get currentTrackQuality => _currentTrackQuality;

  // Playback state
  bool get isPlaying => _player.state.playing;

  Stream<bool> get playingStream => _player.stream.playing;

  Stream<Duration> get positionStream => _player.stream.position;

  Duration get duration => _player.state.duration;

  // Queue navigation helpers
  bool get hasNext => _currentIndex < _queue.length - 1;
  bool get hasPrevious => _currentIndex > 0;

  AudioService(this._apiService, this._authService, this._settingsService)
      : _player = media_kit.Player() {
    _init();
    _settingsService.addListener(_onSettingsChanged);
  }

  /// Initialize audio system and OS media controls
  Future<void> _init() async {
    try {
      // Set up track completion handler
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

      print('AudioService initialized (media_kit)');
    } catch (e, stackTrace) {
      print('Error initializing AudioService: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Handle quality setting changes
  void _onSettingsChanged() async {
    final newQuality = _settingsService.audioQuality;
    if (newQuality != _currentTrackQuality && _currentTrack != null) {
      print('Quality setting changed to: ${newQuality.value}');
      // Note: Quality will apply on next track or manual restart
    }
    notifyListeners();
  }

  /// Play a track with quality selection
  ///
  /// [track] - The track to play
  /// [queue] - Optional queue to set (defaults to single track)
  /// [preserveIndex] - Keep current queue index (used when skipping)
  Future<void> playTrack(
      models.Track track, {
        List<models.Track>? queue,
        bool preserveIndex = false,
      }) async {
    try {
      // Step 1: Get available qualities for this track
      final qualityInfo = await _apiService.getTrackQuality(track.id);
      final List<Quality> availableQualities = qualityInfo['availableQualities'];

      // Step 2: Determine which quality to actually use
      Quality desiredQuality = _settingsService.audioQuality;
      Quality? selectedQuality;

      if (desiredQuality == Quality.auto && availableQualities.isNotEmpty) {
        // Auto = use ABR (adaptive bitrate)
        selectedQuality = Quality.auto;
      } else if (availableQualities.contains(desiredQuality)) {
        // Desired quality is available
        selectedQuality = desiredQuality;
      } else {
        // Desired quality not available - find best alternative
        // Quality hierarchy: hires > cd > high > efficiency
        final qualityOrder = [Quality.hires, Quality.cd, Quality.high, Quality.efficiency];
        final desiredIndex = qualityOrder.indexOf(desiredQuality);

        // Try lower qualities first (maintain or reduce quality, never increase)
        for (int i = desiredIndex; i < qualityOrder.length; i++) {
          if (availableQualities.contains(qualityOrder[i])) {
            selectedQuality = qualityOrder[i];
            print('Quality ${desiredQuality.value} unavailable, using ${selectedQuality.value}');
            break;
          }
        }

        // Fallback to first available
        if (selectedQuality == null && availableQualities.isNotEmpty) {
          selectedQuality = availableQualities.first;
          print('Using fallback quality: ${selectedQuality.value}');
        }
      }

      if (selectedQuality == null) {
        throw Exception('No available quality found for track');
      }

      // Track the actual quality being played
      _currentTrackQuality = selectedQuality;

      // Step 3: Build stream URL and headers
      final url = _apiService.getStreamUrl(track.id, selectedQuality);
      final token = _authService.token;

      print('Playing: ${track.title}');
      print('Stream URL: $url');
      print('Quality: ${selectedQuality.value}');

      // Step 4: Load and play with media_kit (works on all platforms)
      await _player.open(
        media_kit.Media(url, httpHeaders: {'Authorization': 'Bearer $token'}),
      );
      await _player.play();

      // Step 5: Update state
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

      notifyListeners();
    } catch (e, stackTrace) {
      print('Error playing track: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Queue management
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

  // Playback controls
  Future<void> skipNext() async {
    if (hasNext) {
      _currentIndex++;
      await playTrack(_queue[_currentIndex], queue: _queue, preserveIndex: true);
    }
  }

  Future<void> skipPrevious() async {
    if (hasPrevious) {
      _currentIndex--;
      await playTrack(_queue[_currentIndex], queue: _queue, preserveIndex: true);
    }
  }

  void play() {
    _player.play();
    notifyListeners();
  }

  void pause() {
    _player.pause();
    notifyListeners();
  }

  void seek(Duration position) {
    _player.seek(position);
  }

  /// Restart current track with current quality settings
  /// Used when user manually changes quality mid-playback
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
