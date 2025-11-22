import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:discord_rich_presence/discord_rich_presence.dart';

class WindowsTransport extends Transport {
  WindowsTransport(super._client);
  RandomAccessFile? _file;
  Timer? _timer;

  @override
  Future<void> connect() async {
    final RandomAccessFile? file = await _getIpc();
    if (file == null) {
      throw "Couldn't write to the IPC connection";
    }

    _file = file;
    events.add(Event('open'));

    send(<String, Object?>{
      'v': 1,
      'client_id': client?.clientId,
    }, op: OPCodes.handshake,);

    await read();

    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      readLoop();
    });
  }

  Future<void> readLoop() async {
    final List<int> data = await read();
    if (data.isEmpty) return;

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
  }

  String _getIpcPath(int id) {
    return '\\\\?\\pipe\\discord-ipc-$id';
  }

  Future<RandomAccessFile?> _getIpc({int id = 0}) async {
    try {
      final RandomAccessFile ipcFile = await File(_getIpcPath(id)).open(mode: FileMode.write);
      return ipcFile;
    } catch (err) {
      if (id >= 10) {
        return null;
      }

      return _getIpc(id: id + 1);
    }
  }

  Future<List<int>> read() async {
    if (_file == null) return <int>[];

    int len = await _file!.length();
    do {
      len = await _file!.length();
      sleep(Duration(milliseconds: 50));
    } while (len == 0 && _timer == null);

    if (len == 0 && _timer != null) return <int>[];

    final Uint8List data = await _file!.read(len);
    return data;
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    send(<dynamic, dynamic>{}, op: OPCodes.close);
    await _file?.close();
  }

  @override
  void send(dynamic data, {OPCodes op = OPCodes.frame}) {
    try {
      _file?.writeFromSync(encode(op, data));
    } catch (err) {
      throw 'Write error.';
    }
  }
}
