import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/core/models/quality.dart';
import '/core/services/auth.dart';
import '/core/services/settings.dart';
import '/ui/components/layout.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();

    return MainLayout(
      child: Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          children: [
            ListTile(
              title: const Text('Server Address'),
              subtitle: Text(settings.serverIp ?? 'Not set'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/setup');
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Text(
                'Audio Quality',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            RadioGroup<Quality>(
              groupValue: settings.audioQuality,
              onChanged: (Quality? value) {
                if (value != null) {
                  settings.setAudioQuality(value);
                }
              },
              child: Column(
                children: <Widget>[
                  ...Quality.values.map((quality) {
                    final info = quality.info;
                    final isSelected = settings.audioQuality == quality;

                    return RadioListTile<Quality>(
                      title: Text(info.label),
                      subtitle: Text(
                      info.bitrate != null
                      ? '${info.codec} • ${info.bitrate}'
                          : info.sampleRate != null
                      ? '${info.codec} • ${info.sampleRate}'
                          : info.codec,
                      ),
                      value: quality,
                      selected: isSelected
                    );
                  })
                ]
              )
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Text(
                'Other',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            ),
            ListTile(
              title: const Text('Discord RPC'),
              subtitle: const Text('Enable Discord Rich Presence'),
              trailing: Switch(
                value: settings.discordRPCEnabled,
                onChanged: (value) {
                  settings.setDiscordRPCEnabled(value);
                },
              ),
            ),
            ListTile(
              title: const Text('Upload Music'),
              subtitle: const Text('Upload releases to the server'),
              leading: const Icon(Icons.upload),
              onTap: () {
                Navigator.pushNamed(context, '/upload');
              },
            ),
            const Divider(),
            ListTile(
              title: const Text('Log Out'),
              onTap: () {
                context.read<AuthService>().logout();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
