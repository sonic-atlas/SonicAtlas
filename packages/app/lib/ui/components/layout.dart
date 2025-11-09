import 'package:flutter/material.dart';

import 'mini_player.dart';

class MainLayout extends StatelessWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: child),
          SafeArea(top: false, child: const MiniPlayer()),
        ],
      ),
    );
  }
}
