import 'dart:io';
import 'dart:typed_data';

import 'package:discord_rich_presence/discord_rich_presence.dart';

class UnixTransport extends Transport {
  UnixTransport(super._client);
  Socket? _socket;

  @override
  Future<void> connect() async {
    final Socket? socket = await _getIpc();
    if (socket == null) {
      throw "Couldn't connect to Discord's IPC";
    }

    _socket = socket;
    events.add(Event('open'));

    _socket?.add(encode(
      OPCodes.handshake,
      <String, Object?>{
        'v': 1,
        'client_id': client?.clientId,
      }
    ),);

    _socket?.listen((Uint8List data) {
      final (OPCodes? code, Map<String, dynamic> cmd) = decode(data);
      if (code == null) return;

      switch (code) {
        case OPCodes.ping:
          send(cmd, op: OPCodes.pong);

        case OPCodes.frame:
          events.add(Event('message', cmd));

        case OPCodes.close:
          events.add(Event('close', cmd));

        default:
          // Do nothing
      }
    });
  }

  @override
  Future<void> close() async {
    send(<dynamic, dynamic>{}, op: OPCodes.close);
    await _socket?.close();
    _socket = null;
  }

  @override
  void send(dynamic data, {OPCodes op = OPCodes.frame}) {
    try {
      _socket?.add(encode(op, data));
    } catch (err) {
      throw "Couldn't write to the IPC connection";
    }
  }

  String _getIpcPath(int id) {
    final Map<String, String> env = Platform.environment;
    final String prefix = switch (env) {
      {'XDG_RUNTIME_DIR': final String dir} => dir,
      {'TMPDIR': final String dir} => dir,
      {'TMP': final String dir} => dir,
      {'TEMP': final String dir} => dir,

      _ => '/tmp'
    };

    return '$prefix/discord-ipc-$id';
  }

  Future<Socket?> _getIpc({int id = 0}) async {
    if (id >= 10) {
      return null;
    }

    try {
      final String path = _getIpcPath(id);
      final InternetAddress host = InternetAddress(path, type: InternetAddressType.unix);
      
      final Socket conn = await Socket.connect(host, 0, timeout: Duration(seconds: 3));
      return conn;
    } catch (err) {
      return _getIpc(id: id + 1);
    }
  }
}
