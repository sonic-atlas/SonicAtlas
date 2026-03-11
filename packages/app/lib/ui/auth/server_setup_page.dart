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
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '3000');

  String _protocol = 'http';
  String _serverType = 'ip';
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

  void _saveServerUrl() {
    final host = _hostController.text.trim();
    final port = _portController.text.trim();

    setState(() {
      _errorMessage = null;
    });

    if (host.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a host';
      });
      return;
    }

    if (_serverType == 'ip') {
      if (!_isValidIpAddress(host) && !_isValidHostname(host)) {
        setState(() {
          _errorMessage = 'Invalid IP address or hostname';
        });
        return;
      }

      if (port.isEmpty || int.tryParse(port) == null) {
        setState(() {
          _errorMessage = 'Invalid port';
        });
        return;
      }
    }

    String serverUrl;
    if (_serverType == 'ip') {
      serverUrl = '$_protocol://$host:$port';
    } else {
      serverUrl = '$_protocol://$host';
    }

    context.read<SettingsService>().setServerUrl(serverUrl, _serverType);
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome to Sonic Atlas',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Configure your server connection.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _protocol,
                      decoration: const InputDecoration(
                        labelText: 'Protocol',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'http', child: Text('HTTP')),
                        DropdownMenuItem(value: 'https', child: Text('HTTPS')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _protocol = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _serverType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'ip',
                          child: Text('IP Address'),
                        ),
                        DropdownMenuItem(
                          value: 'domain',
                          child: Text('Domain'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _serverType = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _hostController,
                decoration: InputDecoration(
                  labelText: _serverType == 'ip' ? 'Host / IP' : 'Domain',
                  border: const OutlineInputBorder(),
                  hintText: _serverType == 'ip' ? '192.168.1.100' : 'sonic.example.com',
                  errorText: _errorMessage,
                ),
                keyboardType: _serverType == 'ip' ? TextInputType.numberWithOptions(decimal: true) : TextInputType.url,
                textInputAction: TextInputAction.next,
              ),
              if (_serverType == 'ip') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _portController,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    border: OutlineInputBorder(),
                    hintText: '3000',
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveServerUrl(),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveServerUrl,
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
