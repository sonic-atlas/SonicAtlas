import 'dart:io';

import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

import 'core/services/network/api.dart';
import 'core/services/playback/audio.dart';
import 'core/services/auth/auth.dart';
import 'core/services/utils/cla.dart';
import 'core/services/platform/discord.dart';
import 'core/services/playback/media_handler.dart';
import 'core/services/playback/mpris_service.dart';
import 'core/services/config/settings.dart';
import 'core/services/network/socket.dart';
import 'core/services/platform/wtaskbar.dart';
import 'core/services/recorder/recorder_service.dart';
import 'core/services/recorder/processing_service.dart';
import 'core/services/platform/win_http.dart';

import 'ui/home/home_page.dart';
import 'ui/auth/login_page.dart';
import 'ui/auth/server_setup_page.dart';
import 'ui/settings/settings_page.dart';
import 'ui/splash/splash_page.dart';
import 'ui/upload/upload_page.dart';
import 'ui/recorder/recording_page.dart';
import 'ui/recorder/editor_page.dart';
import 'ui/theme/app_theme.dart';

late MediaSessionHandler audioHandler;
LinuxMprisManager? linuxMpris;

void main(List<String> args) async {
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

  late final WinHttp winHttp;

  if (Platform.isWindows) {
    await WindowsSingleInstance.ensureSingleInstance(
      args,
      'com.sonicatlas/player',
      onSecondWindow: (args) {
        handleCLA(args, audioService: audioService, apiService: apiService);
      },
    );

    winHttp = WinHttp(audioService, apiService);
    await winHttp.start();
  }

  discordService.setAudioService(audioService);
  discordService.setApiService(apiService);

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
        ChangeNotifierProvider(create: (_) => SonicRecorderService()),
        ChangeNotifierProvider(create: (_) => ProcessingService(apiService)),

        ProxyProvider2<SettingsService, AuthService, ApiService>(
          update: (context, settings, auth, previous) =>
              ApiService(settings, auth),
        ),
        ChangeNotifierProvider<SocketService>(
          create: (context) => SocketService(
            Provider.of<SettingsService>(context, listen: false),
          ),
        ),
      ],
      child: const SonicAtlasApp(),
    ),
  );

  if (args.isNotEmpty) {
    handleCLA(args, audioService: audioService, apiService: apiService);
  }

  Future.microtask(() => discordService.init());

  final wTaskBarService = WTaskbarService();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await Future.delayed(const Duration(milliseconds: 200));
    wTaskBarService.setup(audioService);
  });
}

class SonicAtlasApp extends StatelessWidget {
  const SonicAtlasApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.select<SettingsService, ThemeMode>(
      (s) => s.themeMode,
    );

    return MaterialApp(
      title: 'Sonic Atlas',
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.unknown,
        },
      ),
      theme: AppTheme.fromBrightness(Brightness.light),
      darkTheme: AppTheme.fromBrightness(Brightness.dark),
      themeMode: theme,
      themeAnimationDuration: const Duration(milliseconds: 0),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashPage(),
        '/setup': (context) => const ServerSetupPage(),
        '/login': (context) => const LoginPage(),
        '/': (context) => const HomePage(),
        '/settings': (context) => const SettingsPage(),
        '/upload': (context) => const UploadPage(),
        '/recorder': (context) => const RecordingPage(),
        '/editor': (context) => const EditorPage(),
      },
    );
  }
}
