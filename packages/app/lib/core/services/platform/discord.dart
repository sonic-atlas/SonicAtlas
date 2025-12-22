import 'dart:async';
import 'dart:io' show Platform;

import 'package:discord_rich_presence/discord_rich_presence.dart';
import 'package:flutter/foundation.dart';
import 'package:sonic_atlas/core/models/track.dart';
import 'package:sonic_atlas/core/services/config/settings.dart';

import '../playback/audio.dart';

extension ActivityCopyWith on Activity {
  Activity copyWith({
    String? name,
    String? details,
    String? state,
    ActivityAssets? assets,
    ActivityTimestamps? timestamps,
    ActivityType? type,
  }) {
    return Activity(
      name: name ?? this.name,
      details: details ?? this.details,
      state: state ?? this.state,
      assets: assets ?? this.assets,
      timestamps: timestamps ?? this.timestamps,
      type: type ?? this.type,
    );
  }
}

extension ActivityAssetsCopyWith on ActivityAssets {
  ActivityAssets copyWith({
    String? largeImage,
    String? largeText,
    String? smallImage,
    String? smallText,
  }) {
    return ActivityAssets(
      largeImage: largeImage ?? this.largeImage,
      largeText: largeText ?? this.largeText,
      smallImage: smallImage ?? this.smallImage,
      smallText: smallText ?? this.smallText,
    );
  }
}

class DiscordService with ChangeNotifier {
  final Client client = Client(clientId: '1438064057138806818'); // Don't change
  final SettingsService _settingsService;
  AudioService? _audioService;

  Track? _currentlyPlaying;
  DateTime? _trackStartTime;
  DateTime? _pauseTime;

  final Activity _templateActivity = Activity(
    name: 'Sonic Atlas',
    assets: ActivityAssets(largeImage: 'sonic_atlas_logo'),
  );
  Activity? _currentActivity;

  bool _isEnabled = true;

  bool get isEnabled => _settingsService.discordRPCEnabled;

  final List<StreamSubscription> _subscriptions = [];

  DiscordService(this._settingsService) {
    _settingsService.addListener(_onSettingsChanged);
    _isEnabled = isEnabled;
  }

  void setAudioService(AudioService service) {
    _audioService = service;
    _subscriptions.add(
      _audioService!.playingStream.listen((isPlaying) {
        if (isPlaying) {
          resumeTrack();
        } else {
          pauseTrack();
        }
      }),
    );
  }

  Future<void> init() async {
    if (!isEnabled || Platform.isAndroid || Platform.isIOS || !_isEnabled) {
      return;
    }

    try {
      await client.connect().timeout(const Duration(seconds: 2));
    } on TimeoutException {
      if (kDebugMode) print('Discord IPC not available, skipping RPC.');
      return;
    } catch (e, s) {
      if (kDebugMode) {
        print('DiscordService error: $e');
        print('DiscordService stack trace: $s');
      }
      return;
    }

    if (kDebugMode) print('DiscordService connected');

    _subscriptions.addAll([
      AudioService.onPlayTrack.listen(playTrack),
      AudioService.onPlay.listen((_) => resumeTrack()),
      AudioService.onPause.listen((_) => pauseTrack()),
      AudioService.onSeek.listen(seekTrack),
    ]);

    _currentActivity = null;

    if (kDebugMode) print('DiscordService initialized');
    notifyListeners();
  }

  Future<void> disconnectClient() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    await client.disconnect();

    if (kDebugMode) {
      print('DiscordService disconnected');
    }
  }

  void _onSettingsChanged() async {
    if (_settingsService.discordRPCEnabled != _isEnabled) {
      _isEnabled = _settingsService.discordRPCEnabled;
      if (_isEnabled) {
        await init();
      } else {
        await disconnectClient();
      }
    }
  }

  Future<void> _updateActivity({
    String? details,
    String? state,
    ActivityTimestamps? timestamps,
    ActivityType? type,
    String? largeImage,
    String? largeText,
    String? name,
  }) async {
    _currentActivity = (_currentActivity ?? _templateActivity).copyWith(
      name: name,
      details: details,
      state: state,
      timestamps: timestamps,
      type: type ?? ActivityType.listening,
      assets: (_currentActivity?.assets ?? _templateActivity.assets)?.copyWith(
        largeImage: largeImage,
        largeText: largeText,
      ),
    );

    await client.setActivity(_currentActivity!);
  }

  Future<void> playTrack(Track track) async {
    if (kDebugMode) {
      print('Playing track: ${track.title}');
    }

    _currentlyPlaying = track;
    _trackStartTime = DateTime.now();
    _pauseTime = null;

    await _updateActivity(
      name: '${track.title} — ${track.artist}',
      details: track.title,
      state: track.artist,
      timestamps: ActivityTimestamps(
        start: _trackStartTime!,
        end: _trackStartTime!.add(Duration(seconds: track.duration)),
      ),
    );

    notifyListeners();
  }

  Future<void> resumeTrack() async {
    if (_currentlyPlaying == null || _pauseTime == null) return;

    final pausedTime = DateTime.now().difference(_pauseTime!);
    _trackStartTime = _trackStartTime!.add(pausedTime);
    _pauseTime = null;

    await _updateActivity(
      type: ActivityType.listening,
      timestamps: ActivityTimestamps(
        start: _trackStartTime!,
        end: _trackStartTime!.add(
          Duration(seconds: _currentlyPlaying!.duration),
        ),
      ),
    );
  }

  Future<void> pauseTrack() async {
    if (_currentlyPlaying == null || _pauseTime != null) return;

    _pauseTime = DateTime.now();

    await _updateActivity(
      timestamps: ActivityTimestamps(start: _trackStartTime, end: _pauseTime),
      type: ActivityType.playing,
    );
  }

  Future<void> seekTrack(Duration position) async {
    if (_currentlyPlaying == null) return;

    _trackStartTime = DateTime.now().subtract(position);
    _pauseTime = null;

    await _updateActivity(
      timestamps: ActivityTimestamps(
        start: _trackStartTime,
        end: _trackStartTime!.add(
          Duration(seconds: _currentlyPlaying!.duration),
        ),
      ),
    );
  }
}
