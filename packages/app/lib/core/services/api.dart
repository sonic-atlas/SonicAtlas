import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '/core/models/quality.dart';
import '/core/models/track.dart';
import 'auth.dart';
import 'settings.dart';

class ApiService {
  final SettingsService _settingsService;
  final AuthService _authService;

  ApiService(this._settingsService, this._authService);

  String get _baseUrl {
    final ip = _settingsService.serverIp;
    if (ip == null) throw Exception('Server IP not set');
    return 'http://$ip:3000';
  }

  Map<String, String> get _headers {
    final token = _authService.token;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, String> get headers => _headers;

  Future<bool> login(String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/login'),
        headers: _headers,
        body: jsonEncode({'password': password}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        _authService.setToken(body['token']);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Login error: $e');
      }
      return false;
    }
  }

  Future<List<Track>> getTracks() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/tracks'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);
        return body.map((json) => Track.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Get tracks error: $e');
      }
      return [];
    }
  }

  Future<List<Track>> searchTracks(
    String query, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final allTracksList = await getTracks();
      final allTracksMap = {for (var track in allTracksList) track.id: track};

      final response = await http.get(
        Uri.parse(
          '$_baseUrl/api/search?q=${Uri.encodeComponent(query)}&limit=$limit&offset=$offset',
        ),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> results = body['results'] ?? [];
        return results.map((json) {
          final fullTrack = allTracksMap[json['id']];
          return Track(
            id: json['id'],
            title: json['title'] ?? 'Unknown Title',
            artist: json['artist'] ?? 'Unknown Artist',
            album: json['album'] ?? 'Unknown Album',
            duration: fullTrack?.duration ?? 0,
          );
        }).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Search tracks error: $e');
      }
      return [];
    }
  }

  String getStreamUrl(String trackId, Quality quality) {
    if (quality == Quality.auto) {
      return '$_baseUrl/api/stream/$trackId/master.m3u8';
    }
    return '$_baseUrl/api/stream/$trackId/${quality.value}/${quality.value}.m3u8';
  }

  Future<Map<String, dynamic>> getTrackQuality(String trackId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/stream/$trackId/quality'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return {
          'sourceQuality': Quality.fromString(body['sourceQuality'] ?? 'cd'),
          'availableQualities': (body['availableQualities'] as List<dynamic>)
              .map((q) => Quality.fromString(q.toString()))
              .toList(),
        };
      }
      return {
        'sourceQuality': Quality.cd,
        'availableQualities': Quality.values.toList(),
      };
    } catch (e) {
      if (kDebugMode) {
        print('Get track quality error: $e');
      }
      return {
        'sourceQuality': Quality.cd,
        'availableQualities': Quality.values.toList(),
      };
    }
  }

  String getAlbumArtUrl(String trackId) {
    return '$_baseUrl/api/metadata/$trackId/cover';
  }
}
