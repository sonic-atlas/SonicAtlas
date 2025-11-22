import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:discord_rich_presence/discord_rich_presence.dart';
import 'package:uuid/uuid.dart';

class Client {
  Client({required this.clientId});

  final String clientId;
  late Transport? _transport;

  Future<void> connect() async {
    _transport = Transport.create(this);
    await _transport?.connect();

    _transport?.events.stream.listen(_rpcMessage);
  }

  Future<void> disconnect() async {
    _transport?.close();
  }

  Future<void> setActivity(Activity activity) async {
    final Activity safeActivity = Activity(
      name: _truncateTo128Bytes(activity.name),
      details: activity.details != null
          ? _truncateTo128Bytes(activity.details!)
          : null,
      state: activity.state != null
          ? _truncateTo128Bytes(activity.state!)
          : null,
      type: activity.type,
      url: activity.url,
      timestamps: activity.timestamps,
      assets: activity.assets,
    );

    await _request(
      DiscordCommands.setActivity.name,
      <String, dynamic>{
        'pid': pid,
        'activity': safeActivity.toJson(),
      },
      '',
    );
  }

  Future<void> _request(String cmd, Map<String, dynamic> args, String event) async {
    final Uuid uuid = Uuid();
    final String nonce = uuid.v4();

    _transport?.send(<String, Object>{
      'cmd': cmd,
      'args': args,
      'evt': event,
      'nonce': nonce,
    });
  }

  void _rpcMessage(Event message) async {
    switch (message.type) {
      case 'close':
        await disconnect(); 

      default:
        
    }
  }

  String _truncateTo128Bytes(String text) {
    final Uint8List bytes = utf8.encode(text);
    final int maxBytes = 120;
    if (bytes.length <= maxBytes) return text;

    final Uint8List ellipsis = utf8.encode('...');
    final int limit = maxBytes - ellipsis.length;

    int cutIndex = 0;
    int byteCount = 0;

    while (cutIndex < text.length) {
      final Uint8List charBytes = utf8.encode(text[cutIndex]);
      if (byteCount + charBytes.length > limit) break;
      byteCount += charBytes.length;
      cutIndex++;
    }

    return '${text.substring(0, cutIndex)}...';
  }

}
