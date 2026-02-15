import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/core/models/quality.dart';
import '../../core/services/auth/auth.dart';
import '../../core/services/config/settings.dart';
import '../../core/services/playback/audio.dart';
import '/ui/common/layout.dart';

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
                      selected: isSelected,
                    );
                  }),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Text(
                'Playback',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            if (Platform.isAndroid)
              SwitchListTile(
                title: const Text('Exclusive Audio'),
                // TODO: Add note in docs
                // This does not work most of the time
                // You would need a custom usb driver to take control of a usb dac for example
                subtitle: const Text(
                  'Tries to take exclusive control of the specific device for playback (requires restart)',
                ),
                value: settings.useExclusiveAudio,
                onChanged: (value) async {
                  await settings.setUseExclusiveAudio(value);
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Restart Required'),
                        content: const Text(
                          'Exclusive audio settings require a full app restart to take effect.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => exit(0),
                            child: const Text('Restart Now'),
                          ),
                        ],
                      ),
                    );
                  }
                },
              )
            else
              SwitchListTile(
                title: const Text('Native Sample Rate'),
                subtitle: const Text(
                  'Avoid resampling (requires track change)',
                ),
                value: settings.useNativeSampleRate,
                onChanged: (value) => settings.setUseNativeSampleRate(value),
              ),
            ListTile(
              title: const Text('Song Start Buffer Duration'),
              subtitle: Text(
                'This changes how much a song buffers when starting (This will probably will removed later on).',
              ),
              trailing: DropdownButton<double>(
                value: settings.audioBufferDuration,
                onChanged: (value) {
                  if (value != null) {
                    settings.setAudioBufferDuration(value);
                  }
                },
                items: const [
                  DropdownMenuItem(value: 1.0, child: Text('Low (1s)')),
                  DropdownMenuItem(value: 2.0, child: Text('Default (2s)')),
                  DropdownMenuItem(value: 4.0, child: Text('Stable (4s)')),
                  DropdownMenuItem(value: 7.0, child: Text('Long (7s)')),
                  DropdownMenuItem(value: 10.0, child: Text('Max (10s)')),
                ],
              ),
            ),
            ListTile(
              title: const Text('Default Volume'),
              subtitle: Text('${(settings.audioVolume * 100).toInt()}%'),
            ),
            Slider(
              value: settings.audioVolume.clamp(0.0, 1.0),
              min: 0.0,
              max: 1.0,
              onChanged: (value) {
                context.read<AudioService>().setVolume(value);
              },
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
              ),
            ),
            ListTile(
              title: const Text('Theme'),
              trailing: RepaintBoundary(
                child: Builder(
                  builder: (context) {
                    return DropdownButton<ThemeMode>(
                      value: settings.themeMode,
                      onChanged: (value) {
                        if (value != null) {
                          settings.setThemeMode(value);
                        }
                      },
                      items: const [
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text('System'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text('Light'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text('Dark'),
                        ),
                      ],
                    );
                  },
                ),
              ),
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
            ListTile(
              title: const Text('Record Music'),
              subtitle: const Text(
                'Record releases from input devices or cd\'s',
              ),
              leading: const Icon(Icons.mic),
              onTap: () {
                Navigator.pushNamed(context, '/recorder');
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
