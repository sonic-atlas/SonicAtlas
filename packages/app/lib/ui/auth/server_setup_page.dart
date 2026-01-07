import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/config/settings.dart';

class ServerSetupPage extends StatefulWidget {
  const ServerSetupPage({super.key});

  @override
  State<ServerSetupPage> createState() => _ServerSetupPageState();
}

class _ServerSetupPageState extends State<ServerSetupPage> {
  final _ipController = TextEditingController();
  String? _errorMessage;

  bool _isValidIpAddress(String ip) {
    return InternetAddress.tryParse(ip) != null;
  }

  bool _isValidHostname(String hostname) {
    final looksLikeIp = RegExp(r'^[0-9.]+$').hasMatch(hostname);
    if (looksLikeIp && !_isValidIpAddress(hostname)) {
      return false;
    }

    final hostnamePattern = RegExp(
      r'^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*'
      r'([A-Za-z0-9]|[A-Za-z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])$',
    );
    return hostnamePattern.hasMatch(hostname) && hostname.length <= 253;
  }

  void _saveServerIp() {
    final trimmedInput = _ipController.text.trim();

    setState(() {
      _errorMessage = null;
    });

    if (trimmedInput.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a server IP or hostname';
      });
      return;
    }

    if (!_isValidIpAddress(trimmedInput) && !_isValidHostname(trimmedInput)) {
      setState(() {
        _errorMessage = 'Invalid IP address or hostname';
      });
      return;
    }

    _ipController.text = trimmedInput;

    context.read<SettingsService>().setServerIp(trimmedInput);
    Navigator.pushReplacementNamed(
      context,
      '/login',
      arguments: {'fromSetup': true},
    );
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
              const Text(
                'Please enter your server IP address or hostname to begin.',
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _ipController,
                decoration: InputDecoration(
                  labelText: 'Server IP or Hostname',
                  border: const OutlineInputBorder(),
                  hintText: 'e.g., 192.168.1.100',
                  errorText: _errorMessage,
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _saveServerIp(),
                onChanged: (_) {
                  if (_errorMessage != null) {
                    setState(() {
                      _errorMessage = null;
                    });
                  }
                },
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
