import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:sonic_atlas/core/services/utils/logger.dart';

import '/core/models/quality.dart';
import '/core/models/track.dart';
import '/core/models/release.dart';
import '/core/models/upload.dart';
import '../auth/auth.dart';
import '../config/settings.dart';

class ApiService {
  final SettingsService _settingsService;
  final AuthService _authService;

  ApiService(this._settingsService, this._authService);

  String get _baseUrl {
    final url = _settingsService.serverUrl;
    if (url == null) throw Exception('Server URL not set');
    return url;
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
      logger.e('Login error', error: e);
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
      logger.e('Get tracks error', error: e);
      return [];
    }
  }

  Future<Track?> getTrack(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/tracks/$id'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return Track.fromJson(body);
      }
      return null;
    } catch (e) {
      logger.e('Get track error', error: e);
      return null;
    }
  }

  Future<List<Track>> searchTracks(
    String query, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
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
          json['album'] = json['album'] ?? json['releaseTitle'] ?? 'Unknown Album';
          json['artist'] = json['artist'] ?? json['releaseArtist'] ?? 'Unknown Artist';
          return Track.fromJson(json);
        }).toList();
      }
      return [];
    } catch (e) {
      logger.e('Search tracks error', error: e);
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
      logger.e('Get track quality error', error: e);
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

  String getReleaseCoverUrl(String releaseId, {String? size}) {
    final url = '$_baseUrl/api/releases/$releaseId/cover';
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
      logger.e('Get release error', error: e);
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
        final Map<String, dynamic> release = body['release'];
        final String releaseTitle = release['title'];
        final String? releaseArtist = release['primaryArtist'];

        return tracks.map((json) {
          json['releaseTitle'] = releaseTitle;
          json['releaseArtist'] = releaseArtist;
          if (json['album'] == 'Unknown Album' || json['album'] == null) {
            json['album'] = releaseTitle;
          }
          return Track.fromJson(json);
        }).toList();
      }
      return [];
    } catch (e) {
      logger.e('Get releases from tracks error', error: e);
      return [];
    }
  }

  Future<Map<String, dynamic>?> _initUpload(
    Map<String, dynamic> metadata,
    List<Map<String, dynamic>> files,
    String? coverFileName,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/uploads/init'),
      headers: _headers,
      body: jsonEncode({
        'releaseMetadata': metadata,
        'files': files,
        'coverFileName': coverFileName,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Init failed: ${response.statusCode} - ${response.body}');
  }

  Future<void> _uploadSmallFile(
    String uploadId,
    String fileId,
    String filePath,
    String mimeType,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/uploads/$uploadId/file'),
    );
    request.headers.addAll(_headers);

    request.fields['fileId'] = fileId;
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        filePath,
        contentType: MediaType.parse(mimeType),
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('File upload failed: ${response.body}');
    }
  }

  Future<void> _uploadChunk(
    String uploadId,
    String fileId,
    int chunkIndex,
    List<int> chunkData,
  ) async {
    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$_baseUrl/api/uploads/$uploadId/chunk'),
        );
        request.headers.addAll(_headers);

        request.fields['fileId'] = fileId;
        request.fields['chunkIndex'] = chunkIndex.toString();
        request.files.add(
          http.MultipartFile.fromBytes(
            'chunk',
            chunkData,
            filename: 'chunk_$chunkIndex',
          ),
        );

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode != 200 && response.statusCode != 201) {
          throw Exception('Chunk upload failed: ${response.body}');
        }
        return;
      } catch (e) {
        if (attempt >= maxRetries) rethrow;
        await Future.delayed(Duration(seconds: attempt));
      }
    }
  }

  Future<void> _completeChunkedFile(String uploadId, String fileId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/uploads/$uploadId/file/$fileId/complete'),
      headers: _headers,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('File completion failed: ${response.body}');
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
    String? socketId, {
    void Function(ReleaseUploadProgress progress)? onProgress,
  }) async {
    try {
      final manifest = <Map<String, dynamic>>[];
      final filesMap = <String, File>{};

      for (var path in filePaths) {
        final file = File(path);
        final fileName = path.split(Platform.pathSeparator).last;
        final fileSize = await file.length();
        String mimeType = lookupMimeType(path) ?? 'application/octet-stream';
        if (mimeType == 'audio/x-flac') {
          mimeType = 'audio/flac';
        }

        manifest.add({
          'fileName': fileName,
          'fileSize': fileSize,
          'mimeType': mimeType,
        });
        filesMap[fileName] = file;
      }

      final metadata = {
        'title': title,
        'primaryArtist': artist,
        'year': year,
        'releaseType': type,
        'extractAllCovers': extractAllCovers,
        'socketId': ?socketId,
      };

      String? coverFileName;
      if (coverPath != null) {
        coverFileName = coverPath.split(Platform.pathSeparator).last;
      }

      final initData = await _initUpload(metadata, manifest, coverFileName);
      if (initData == null) throw Exception('Init logic did not return data');

      final initRes = UploadInitResponse.fromJson(initData);
      final progressMap = <String, FileUploadProgress>{};

      for (var fp in initRes.files) {
        final file = filesMap[fp.fileName];
        progressMap[fp.fileId] = FileUploadProgress(
          fileId: fp.fileId,
          fileName: fp.fileName,
          bytesUploaded: 0,
          bytesTotal: file != null ? file.lengthSync() : 0,
          status: 'pending',
        );
      }

      void emitProgress() {
        if (onProgress == null) return;
        final allFiles = progressMap.values.toList();
        final totalBytes = allFiles.fold<int>(0, (s, f) => s + f.bytesTotal);
        final uploadedBytes = allFiles.fold<int>(
          0,
          (s, f) => s + f.bytesUploaded,
        );
        final overallProgress = totalBytes > 0 ? ((uploadedBytes / totalBytes) * 100).round() : 0;

        onProgress(
          ReleaseUploadProgress(
            uploadId: initRes.uploadId,
            files: allFiles,
            overallProgress: overallProgress,
          ),
        );
      }

      emitProgress();

      final errors = <Exception>[];
      final maxConcurrentUploads = 2;
      final queue = List<UploadFilePlan>.from(initRes.files);

      Future<void> processNext() async {
        while (queue.isNotEmpty) {
          final filePlan = queue.removeAt(0);
          final file = filesMap[filePlan.fileName];

          if (file == null) {
            errors.add(Exception('File not found: ${filePlan.fileName}'));
            continue;
          }

          final progress = progressMap[filePlan.fileId]!;
          progress.status = 'uploading';
          emitProgress();

          try {
            if (!filePlan.needsChunking) {
              String mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
              if (mimeType == 'audio/x-flac') {
                mimeType = 'audio/flac';
              }
              await _uploadSmallFile(
                initRes.uploadId,
                filePlan.fileId,
                file.path,
                mimeType,
              );
              progress.bytesUploaded = file.lengthSync();
              emitProgress();
            } else {
              const chunkSize = 50 * 1024 * 1024; // 50MB
              final totalChunks = filePlan.totalChunks;
              int bytesUploaded = 0;
              final raf = await file.open(mode: FileMode.read);

              for (int i = 0; i < totalChunks; i++) {
                final start = i * chunkSize;
                final end = (start + chunkSize < file.lengthSync()) ? start + chunkSize : file.lengthSync();

                raf.setPositionSync(start);
                final chunkData = raf.readSync(end - start);

                await _uploadChunk(
                  initRes.uploadId,
                  filePlan.fileId,
                  i,
                  chunkData,
                );
                bytesUploaded = end;
                progress.bytesUploaded = bytesUploaded;
                emitProgress();
              }
              await raf.close();
              await _completeChunkedFile(initRes.uploadId, filePlan.fileId);
            }

            progress.status = 'processing';
            progress.bytesUploaded = progress.bytesTotal;
            emitProgress();

            progress.status = 'complete';
            emitProgress();
          } catch (e) {
            progress.status = 'error';
            progress.error = e.toString();
            emitProgress();
            errors.add(Exception(e.toString()));
          }
        }
      }

      final workers = List.generate(
        maxConcurrentUploads < initRes.files.length ? maxConcurrentUploads : initRes.files.length,
        (_) => processNext(),
      );
      await Future.wait(workers);

      if (errors.isNotEmpty && errors.length == initRes.files.length) {
        throw Exception(
          'All file uploads failed. First error: ${errors[0].toString()}',
        );
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/uploads/${initRes.uploadId}/complete'),
      );
      request.headers.addAll(_headers);

      if (coverPath != null) {
        final mimeType = lookupMimeType(coverPath) ?? 'image/jpeg';
        request.files.add(
          await http.MultipartFile.fromPath(
            'cover',
            coverPath,
            contentType: MediaType.parse(mimeType),
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      throw Exception('Upload complete failed: ${response.body}');
    } catch (e) {
      logger.e('Upload release error', error: e);
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
      logger.e('Update release error', error: e);
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
      logger.e('Update track metadata error', error: e);
      return false;
    }
  }
}
