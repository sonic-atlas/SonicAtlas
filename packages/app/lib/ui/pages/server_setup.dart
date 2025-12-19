import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/core/services/settings.dart';

class ServerSetupPage extends StatefulWidget {
  const ServerSetupPage({super.key});

  @override
  State<ServerSetupPage> createState() => _ServerSetupPageState();
}

class _ServerSetupPageState extends State<ServerSetupPage> {
  final _ipController = TextEditingController();

  void _saveServerIp() {
    if (_ipController.text.isNotEmpty) {
      context.read<SettingsService>().setServerIp(_ipController.text);
      Navigator.pushReplacementNamed(
        context,
        '/login',
        arguments: {'fromSetup': true},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome to Sonic Atlas',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text('Please enter your server IP address to begin.'),
              const SizedBox(height: 24),
              TextField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'Server IP or Hostname',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., 192.168.1.100',
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _saveServerIp(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveServerIp,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Save and Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
