import 'package:flutter/material.dart';

import '/ui/player/components/mini_player.dart';

class MainLayout extends StatelessWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 300 || constraints.maxHeight < 300) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Window too small',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return Scaffold(
          body: Column(
            children: [
              Expanded(child: child),
              SafeArea(top: false, child: const MiniPlayer()),
            ],
          ),
        );
      },
    );
  }
}
