import 'dart:io';

import 'package:discord_rich_presence/discord_rich_presence.dart';

void main() async {
  // Create your client
  final Client client = Client(clientId: '');

  // Connect to Discord (via IPC)
  await client.connect();

  // Set your awesome activity
  await client.setActivity(
    Activity(
      name: 'minecraft',
      type: ActivityType.playing,
      timestamps: ActivityTimestamps(
        start: DateTime.now(),
      ),
    ),
  );

  // Wait 5 seconds
  sleep(Duration(seconds: 5));

  // Disconnect when you're done (Will render the client unusable)
  await client.disconnect();
}
