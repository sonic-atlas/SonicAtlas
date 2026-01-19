import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:collection/collection.dart';
import 'package:discord_rich_presence/discord_rich_presence.dart';

enum OPCodes {
  handshake(0),
  frame(1),
  close(2),
  ping(3),
  pong(4);

  const OPCodes(this.code);
  final int code;

  static OPCodes? fromCode(int code) =>
      OPCodes.values.firstWhereOrNull((OPCodes op) => op.code == code);
}

class Event {
  Event(this.type, [this.data]);

  final String type;
  final Map<String, dynamic>? data;
}

abstract class Transport {
  Transport(this._client);

  final Client? _client;
  Client? get client => _client;

  final StreamController<Event> _events = StreamController<Event>.broadcast();
  StreamController<Event> get events => _events;

  static Transport create(Client client) {
    if (Platform.isWindows) {
      return WindowsTransport(client);
    }

    return UnixTransport(client);
  }

  Future<void> connect();
  void send(dynamic data, {OPCodes op = OPCodes.frame});
  Future<void> close();

  List<int> encode(OPCodes op, dynamic value) {
    final JsonEncoder encoder = JsonEncoder();
    final String data = encoder.convert(value);

    final List<int> utf8Bytes = utf8.encode(data);

    final ByteDataWriter writer = ByteDataWriter(endian: Endian.little);
    writer.writeInt32(op.code);
    writer.writeInt32(utf8Bytes.length);
    writer.write(utf8Bytes);

    return writer.toBytes();
  }

  (OPCodes?, Map<String, dynamic>) decode(List<int> value) {
    final ByteDataReader reader = ByteDataReader(endian: Endian.little);
    reader.add(value);

    final OPCodes? op = OPCodes.fromCode(reader.readInt32());
    if (op == null) return (null, <String, dynamic>{});

    final int len = reader.readInt32();
    final Uint8List dataEncoded = reader.read(len);
    final String data = String.fromCharCodes(dataEncoded);

    final Map<String, dynamic> command = jsonDecode(data);
    return (op, command);
  }
}
