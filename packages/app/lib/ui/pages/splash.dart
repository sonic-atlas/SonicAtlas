import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/core/services/auth.dart';
import '/core/services/settings.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    // Ensures we don't navigate before the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    final settings = context.read<SettingsService>();
    final auth = context.read<AuthService>();

    if (settings.serverIp == null) {
      Navigator.pushReplacementNamed(context, '/setup');
    } else if (!auth.isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
