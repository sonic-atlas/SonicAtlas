import 'dart:io';

import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'core/services/api.dart';
import 'core/services/audio.dart';
import 'core/services/auth.dart';
import 'core/services/discord.dart';
import 'core/services/media_handler.dart';
import 'core/services/mpris_service.dart';
import 'core/services/settings.dart';
import 'ui/pages/home.dart';
import 'ui/pages/login.dart';
import 'ui/pages/server_setup.dart';
import 'ui/pages/settings.dart';
import 'ui/pages/splash.dart';

late MediaSessionHandler audioHandler;
LinuxMprisManager? linuxMpris;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  MediaKit.ensureInitialized();

  final settingsService = SettingsService();
  await settingsService.init();

  final authService = AuthService();
  await authService.init();

  final discordService = DiscordService(settingsService);

  final apiService = ApiService(settingsService, authService);
  final audioService = AudioService.create(
    apiService,
    authService,
    settingsService,
  );

  discordService.setAudioService(audioService);

  audioHandler = await audio_service.AudioService.init(
    builder: () => MediaSessionHandler(
      audioService.player,
      onSkipNext: audioService.skipNext,
      onSkipPrevious: audioService.skipPrevious,
    ),
    config: const audio_service.AudioServiceConfig(
      androidNotificationChannelId: 'dev.heggo.sonic_atlas.channel',
      androidNotificationChannelName: 'Sonic Atlas Playback',
      androidNotificationChannelDescription: 'Media playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidShowNotificationBadge: true,
      notificationColor: Color(0xFF2196f3),
    ),
  );

  audioService.setAudioHandler(audioHandler);

  if (Platform.isLinux) {
    linuxMpris = LinuxMprisManager(audioHandler, audioService);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsService),
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider.value(value: discordService),
        ChangeNotifierProvider.value(value: audioService),

        ProxyProvider2<SettingsService, AuthService, ApiService>(
          update: (context, settings, auth, previous) =>
              ApiService(settings, auth),
        ),
      ],
      child: const SonicAtlasApp(),
    ),
  );

  Future.microtask(() => discordService.init());
}

class SonicAtlasApp extends StatelessWidget {
  const SonicAtlasApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color background = Color(0xFF121212);
    const Color primaryColor = Color(0xFF1DB954);
    const Color secondaryColor = Color(0xFFB954DB);
    const Color textPrimaryColor = Color(0xFFFFFFFF);
    const Color textSecondaryColor = Color(0xFFB3B3B3);
    const Color surfaceColor = Color(0xFF141414);

    return MaterialApp(
      title: 'Sonic Atlas',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        primaryColor: primaryColor,
        colorScheme: ColorScheme.dark(
          primary: primaryColor,
          secondary: secondaryColor,
          surface: background,
          surfaceContainerHighest: surfaceColor,
          onPrimary: Colors.black,
          onSecondary: Colors.black,
          onSurface: textPrimaryColor,
          onSurfaceVariant: surfaceColor,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: textPrimaryColor),
          bodyMedium: TextStyle(color: textPrimaryColor),
          bodySmall: TextStyle(color: textSecondaryColor),
          titleLarge: TextStyle(color: textPrimaryColor),
          titleMedium: TextStyle(color: textPrimaryColor),
          titleSmall: TextStyle(color: textSecondaryColor),
          headlineMedium: TextStyle(
            color: textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          elevation: 0,
          foregroundColor: textPrimaryColor,
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: textSecondaryColor,
          textColor: textPrimaryColor,
          subtitleTextStyle: TextStyle(color: textSecondaryColor),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
            iconColor: WidgetStateProperty.all(textPrimaryColor),
          ),
        ),
        iconTheme: const IconThemeData(color: textPrimaryColor),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: textPrimaryColor,
            side: const BorderSide(color: textSecondaryColor),
          ),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: primaryColor,
          thumbColor: primaryColor,
          inactiveTrackColor: textSecondaryColor.withValues(alpha: 0.3),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: surfaceColor,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashPage(),
        '/setup': (context) => const ServerSetupPage(),
        '/login': (context) => const LoginPage(),
        '/': (context) => const HomePage(),
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}
