import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/settings.dart';

class SocketService extends ChangeNotifier {
  final SettingsService _settingsService;
  io.Socket? _socket;
  String? _id;

  SocketService(this._settingsService) {
    _settingsService.addListener(_connect);
    _connect();
  }

  String? get id => _id;
  io.Socket? get socket => _socket;

  void _connect() {
    final ip = _settingsService.serverIp;
    if (ip == null) return;

    if (_socket != null) {
      _socket!.dispose();
    }

    final url = 'ws://$ip:3000';
    if (kDebugMode) {
      print('Connecting to socket at: $url');
    }

    _socket = io.io(
      url,
      io.OptionBuilder()
          .setPath('/ws')
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      _id = _socket!.id;
      if (kDebugMode) {
        print('Socket connected: $_id');
      }
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      _id = null;
      if (kDebugMode) {
        print('Socket disconnected');
      }
      notifyListeners();
    });

    _socket!.connect();
  }

  @override
  void dispose() {
    _settingsService.removeListener(_connect);
    _socket?.dispose();
    super.dispose();
  }
}
