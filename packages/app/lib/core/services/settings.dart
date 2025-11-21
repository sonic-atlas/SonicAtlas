import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/core/models/quality.dart';

class SettingsService with ChangeNotifier {
  late SharedPreferences _prefs;
  static const _serverIpKey = 'server_ip';
  static const _audioQualityKey = 'audio_quality';
  static const _discordRPCEnabledKey = 'discord_rpc_enabled';
  static const _relativeDurationKey = 'relative_duration';

  String? _serverIp;
  String? get serverIp => _serverIp;

  Quality _audioQuality = Quality.auto;
  Quality get audioQuality => _audioQuality;

  bool _discordRPCEnabled = true;
  bool get discordRPCEnabled => _discordRPCEnabled;

  bool _relativeDuration = false;
  bool get relativeDuration => _relativeDuration;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _serverIp = _prefs.getString(_serverIpKey);
    _discordRPCEnabled = _prefs.getBool(_discordRPCEnabledKey) ?? true;
    _relativeDuration = _prefs.getBool(_relativeDurationKey) ?? false;

    final savedQuality = _prefs.getString(_audioQualityKey);
    if (savedQuality != null) {
      _audioQuality = Quality.fromString(savedQuality);
    }
  }

  Future<void> setServerIp(String ip) async {
    _serverIp = ip;
    await _prefs.setString(_serverIpKey, ip);
    notifyListeners();
  }

  Future<void> setAudioQuality(Quality quality) async {
    _audioQuality = quality;
    await _prefs.setString(_audioQualityKey, quality.value);
    notifyListeners();
  }

  Future<void> setDiscordRPCEnabled(bool enabled) async {
    _discordRPCEnabled = enabled;
    await _prefs.setBool(_discordRPCEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setRelativeDuration(bool enabled) async {
    _relativeDuration = enabled;
    await _prefs.setBool(_relativeDurationKey, enabled);
    notifyListeners();
  }
}
