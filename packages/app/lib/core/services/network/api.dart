import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import '/core/models/quality.dart';
import '/core/models/track.dart';
import '/core/models/release.dart';
import '../auth/auth.dart';
import '../config/settings.dart';

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

  Future<Track?> getTrack(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/tracks/$id'),
        headers: _headers
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return Track.fromJson(body);
      }
      return null;
    } catch (e) {
        if (kDebugMode) {
          print('Get track error: $e');
        }
        return null;
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

  String getAlbumArtUrl(String trackId, {String? size}) {
    final url = '$_baseUrl/api/metadata/$trackId/cover';
    if (size != null) {
      return '$url?size=$size';
    }
    return url;
  }

  Future<Release?> getRelease(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/releases/$id'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return Release.fromJson(body['release']);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Get release error: $e');
      }
      return null;
    }
  }

  Future<List<Track>> getReleaseTracks(String releaseId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/releases/$releaseId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> tracks = body['tracks'];
        return tracks.map((json) => Track.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Get release tracks error: $e');
      }
      return [];
    }
  }

  Future<Map<String, dynamic>?> uploadRelease(
    List<String> filePaths,
    String? coverPath,
    String title,
    String artist,
    String year,
    String type,
    bool extractAllCovers,
    String? socketId,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/releases/upload'),
      );
      request.headers.addAll(_headers);

      for (var path in filePaths) {
        String mimeType = lookupMimeType(path) ?? 'application/octet-stream';
        if (mimeType == 'audio/x-flac') {
          mimeType = 'audio/flac';
        }
        final mediaType = MediaType.parse(mimeType);
        request.files.add(
          await http.MultipartFile.fromPath(
            'files[]',
            path,
            contentType: mediaType,
          ),
        );
      }

      if (coverPath != null) {
        final mimeType = lookupMimeType(coverPath) ?? 'image/jpeg';
        final mediaType = MediaType.parse(mimeType);
        request.files.add(
          await http.MultipartFile.fromPath(
            'cover',
            coverPath,
            contentType: mediaType,
          ),
        );
      }

      request.fields['releaseTitle'] = title;
      request.fields['primaryArtist'] = artist;
      request.fields['year'] = year;
      request.fields['releaseType'] = type;
      request.fields['extractAllCovers'] = extractAllCovers.toString();
      if (socketId != null) {
        request.fields['socketId'] = socketId;
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      throw Exception('Upload failed: ${response.body}');
    } catch (e) {
      if (kDebugMode) {
        print('Upload release error: $e');
      }
      rethrow;
    }
  }

  Future<bool> updateRelease(String id, Map<String, dynamic> data) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/api/releases/$id'),
        headers: _headers,
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Update release error: $e');
      }
      return false;
    }
  }

  Future<bool> updateTrackMetadata(String id, Map<String, dynamic> data) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/api/metadata/$id'),
        headers: _headers,
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Update track metadata error: $e');
      }
      return false;
    }
  }
}
