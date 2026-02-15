import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/core/models/quality.dart';

class SettingsService with ChangeNotifier {
  late SharedPreferences _prefs;
  static const _serverIpKey = 'server_ip';
  static const _audioQualityKey = 'audio_quality';
  static const _discordRPCEnabledKey = 'discord_rpc_enabled';
  static const _relativeDurationKey = 'relative_duration';
  static const _themeModeKey = 'theme_mode';
  static const _audioBufferDurationKey = 'audio_buffer_duration';
  static const _useNativeSampleRateKey = 'use_native_sample_rate';
  static const _useExclusiveAudioKey = 'use_exclusive_audio';
  static const _audioVolumeKey = 'audio_volume';

  String? _serverIp;
  String? get serverIp => _serverIp;

  Quality _audioQuality = Quality.auto;
  Quality get audioQuality => _audioQuality;

  bool _discordRPCEnabled = true;
  bool get discordRPCEnabled => _discordRPCEnabled;

  bool _relativeDuration = false;
  bool get relativeDuration => _relativeDuration;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  double _audioBufferDuration = 4.0;
  double get audioBufferDuration => _audioBufferDuration;

  bool _useNativeSampleRate = true;
  bool get useNativeSampleRate => _useNativeSampleRate;

  bool _useExclusiveAudio = false;
  bool get useExclusiveAudio => _useExclusiveAudio;

  double _audioVolume = 1.0;
  double get audioVolume => _audioVolume;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _serverIp = _prefs.getString(_serverIpKey);
    _discordRPCEnabled = _prefs.getBool(_discordRPCEnabledKey) ?? true;
    _relativeDuration = _prefs.getBool(_relativeDurationKey) ?? false;
    _audioBufferDuration = _prefs.getDouble(_audioBufferDurationKey) ?? 4.0;
    _useNativeSampleRate = _prefs.getBool(_useNativeSampleRateKey) ?? true;
    _useExclusiveAudio = _prefs.getBool(_useExclusiveAudioKey) ?? false;
    _audioVolume = _prefs.getDouble(_audioVolumeKey) ?? 1.0;

    final savedTheme = _prefs.getString(_themeModeKey);
    if (savedTheme != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.toString() == savedTheme,
        orElse: () => ThemeMode.system,
      );
    }

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

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setString(_themeModeKey, mode.toString());
    notifyListeners();
  }

  Future<void> setAudioBufferDuration(double seconds) async {
    _audioBufferDuration = seconds;
    await _prefs.setDouble(_audioBufferDurationKey, seconds);
    notifyListeners();
  }

  Future<void> setUseNativeSampleRate(bool enabled) async {
    _useNativeSampleRate = enabled;
    await _prefs.setBool(_useNativeSampleRateKey, enabled);
    notifyListeners();
  }

  Future<void> setUseExclusiveAudio(bool enabled) async {
    _useExclusiveAudio = enabled;
    await _prefs.setBool(_useExclusiveAudioKey, enabled);
    notifyListeners();
  }

  Future<void> setAudioVolume(double volume) async {
    _audioVolume = volume;
    await _prefs.setDouble(_audioVolumeKey, volume);
    notifyListeners();
  }
}
