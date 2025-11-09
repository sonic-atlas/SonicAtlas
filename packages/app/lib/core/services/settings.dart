import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/core/models/quality.dart';

class SettingsService with ChangeNotifier {
  late SharedPreferences _prefs;
  static const _serverIpKey = 'server_ip';
  static const _audioQualityKey = 'audio_quality';

  String? _serverIp;

  String? get serverIp => _serverIp;

  Quality _audioQuality = Quality.auto;

  Quality get audioQuality => _audioQuality;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _serverIp = _prefs.getString(_serverIpKey);

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
}
