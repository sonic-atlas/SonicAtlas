import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;
import 'package:discord_rich_presence/discord_rich_presence.dart';
import 'package:flutter/foundation.dart';
import 'package:sonic_atlas/core/models/track.dart';
import 'package:sonic_atlas/core/services/config/settings.dart';
import 'package:sonic_atlas/core/services/network/api.dart';
import 'package:sonic_atlas/core/services/utils/logger.dart';

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
  ApiService? _apiService;

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

  void setApiService(ApiService service) {
    _apiService = service;
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
      logger.w('Discord IPC not available, skipping RPC.');
      return;
    } catch (e, s) {
      logger.e('DiscordService error', error: e, stackTrace: s);
      return;
    }

    logger.i('DiscordService connected');

    _subscriptions.addAll([
      AudioService.onPlayTrack.listen(playTrack),
      AudioService.onPlay.listen((_) => resumeTrack()),
      AudioService.onPause.listen((_) => pauseTrack()),
      AudioService.onSeek.listen(seekTrack),
    ]);

    _currentActivity = null;

    logger.i('DiscordService initialised');
    notifyListeners();
  }

  Future<void> disconnectClient() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    await client.disconnect();

    logger.i('DiscordService disconnected');
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

  // Cover art logic
  Future<String> _resolveCoverUrl(Track track) async {
    const defaultAsset = 'sonic_atlas_logo';
    if (_apiService == null) return defaultAsset;

    final serverType = _settingsService.serverType;

    if (serverType == 'domain') {
      final url = _apiService!.getAlbumArtUrl(track.id);
      if (url.length < 128) {
        return url;
      } else {
        logger.d('DiscordRPC: Custom URL too long (${url.length} chars).');
      }
    }

    try {
      final searchTerm = '${track.artist} ${track.releaseTitle}';
      final encodedQuery = Uri.encodeComponent(searchTerm);

      final response = await http.get(
        Uri.parse(
          'https://itunes.apple.com/search?term=$encodedQuery&entity=album&explicit=yes&limit=1',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // (low priority) TODO: Fallback to musicbrainz when 0 results.
        if (data['resultCount'] > 0) {
          String art = data['results'][0]['artworkUrl100'];
          return art.replaceAll('100x100bb', '512x512bb');
        }
      }
    } catch (e) {
      logger.d('DiscordRPC: iTunes fallback failed', error: e);
    }
    return defaultAsset;
  }

  Future<void> _updateActivity({
    String? details,
    String? state,
    ActivityTimestamps? timestamps,
    ActivityType? type,
    String? largeImage,
    String? largeText,
    String? smallImage,
    String? smallText,
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
        smallImage: smallImage,
        smallText: smallText,
      ),
    );

    await client.setActivity(_currentActivity!);
  }

  Future<void> playTrack(Track track) async {
    _currentlyPlaying = track;
    _trackStartTime = DateTime.now();
    _pauseTime = null;

    final coverImage = await _resolveCoverUrl(track);

    await _updateActivity(
      name: 'Sonic Atlas',
      details: track.title,
      state: track.artist,
      largeImage: coverImage,
      largeText: track.releaseTitle,
      smallImage: 'sonic_atlas_logo',
      smallText: 'Sonic Atlas',
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
