import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../playback/audio.dart';
import '../network/api.dart';

typedef Json = Map<String, dynamic>;
typedef VoidCallback = void Function();

class WinHttp {
  static const int port = 39393;

  HttpServer? _server;
  final Set<WebSocket> _clients = {};

  bool get isRunning => _server != null;

  final AudioService _audioService;
  final ApiService _apiService;

  late Json trackState;

  WinHttp(this._audioService, this._apiService);

  Future<void> start() async {
    if (_server != null) {
      return;
    }

    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port, shared: true);

    /*_audioService.trackStream.listen((track) async {
      if (track == null) return;
      trackState = {
        ...track.toJson(),
        'albumUrl': _apiService.getAlbumArtUrl(track.id),
        'position': _audioService.currentPosition.inSeconds,
        'isPlaying': _audioService.isPlaying
      };
      broadcast('state', trackState);
    });*/

    AudioService.onPlayTrack.listen((track) async {
      trackState = {
        ...track.toJson(),
        'albumUrl': _apiService.getAlbumArtUrl(track.id),
        'position': _audioService.currentPosition.inSeconds,
        'isPlaying': _audioService.isPlaying
      };
      broadcast('state', trackState);
    });

    AudioService.onTrackStart.listen((track) async {
      trackState = {
        ...track.toJson(),
        'albumUrl': _apiService.getAlbumArtUrl(track.id),
        'position': _audioService.currentPosition.inSeconds,
        'isPlaying': _audioService.isPlaying
      };
      broadcast('state', trackState);
    });

    AudioService.onSeek.listen((pos) {
      broadcast('seek', {'position': pos.inSeconds});
    });

    AudioService.onPlay.listen((_) {
      trackState['isPlaying'] = true;
      broadcast('play', {});
    });

    AudioService.onPause.listen((_) {
      trackState['isPlaying'] = true;
      broadcast('pause', {});
    });

    AudioService.onRestart.listen((_) {
      broadcast('state', trackState);
    });

    _listen();
  }

  Future<void> stop() async {
    for (final c in _clients) {
      await c.close();
    }
    _clients.clear();

    await _server?.close(force: true);
    _server = null;
  }

  void _listen() async {
    await for (final req in _server!) {
      if (WebSocketTransformer.isUpgradeRequest(req)) {
        _handleWebSocket(req);
        continue;
      }

      _handleHttp(req);
    }
  }

  // Http
  void _handleHttp(HttpRequest req) {
    switch (req.uri.path) {
      case '/state':
        trackState = {
          ...trackState,
          'position': _audioService.currentPosition.inSeconds
        };
        _sendJson(req, trackState);
        break;
      case '/play':
        _audioService.play();
        _ok(req);
        break;
      case '/pause':
        _audioService.pause();
        _ok(req);
        break;
      case '/next':
        _audioService.skipNext();
        _ok(req);
        break;
      case '/previous':
        _audioService.skipPrevious();
        _ok(req);
        break;
      default:
        _notFound(req);
    }
  }

  // WebSocket
  Future<void> _handleWebSocket(HttpRequest req) async {
    final ws = await WebSocketTransformer.upgrade(req);
    _clients.add(ws);

    ws.done.whenComplete(() {
      _clients.remove(ws);
    });
  }

  void broadcast(String type, Json payload) {
    final msg = jsonEncode({
      'type': type,
      'payload': payload,
    });

    for (final c in _clients) {
      c.add(msg);
    }
  }

  // Responses
  void _sendJson(HttpRequest req, Json body) {
    req.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body))
      ..close();
  }

  void _ok(HttpRequest req) {
    req.response
      ..statusCode = HttpStatus.ok
      ..write('ok')
      ..close();
  }

  void _notFound(HttpRequest req) {
    req.response
      ..statusCode = HttpStatus.notFound
      ..close();
  }
}