import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:sonic_atlas/core/services/utils/logger.dart';

import '../../models/crash_event.dart';

class CrashReporter {
  static bool _initialised = false;

  static final List<CrashEvent> _events = [];
  static late final String _sessionFilePath;

  static Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    final dir = Directory('crash_reports');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final now = DateTime.now();
    _sessionFilePath = 'crash_reports/session_${now.toIso8601String().replaceAll(':', '-')}.txt';

    FlutterError.onError = (FlutterErrorDetails details) async {
      FlutterError.dumpErrorToConsole(details);
      await _recordEvent(details.exceptionAsString(), details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _recordEvent(error.toString(), stack);
      return true;
    };

    Isolate.current.addErrorListener(RawReceivePort((pair) async {
      final List<dynamic> errorAndStack = pair;
      await _recordEvent(errorAndStack[0].toString(), StackTrace.fromString(errorAndStack[1].toString()));
    }).sendPort);
  }

  static void runAppGuarded(Future<void> Function() appRunner) {
    runZonedGuarded(() async {
      await appRunner();
    }, (error, stackTrace) async {
      await _recordEvent(error.toString(), stackTrace);
    });
  }

  static Future<void> _recordEvent(String error, StackTrace? stackTrace) async {
    _events.add(CrashEvent(error, stackTrace));
    await _updateReport();
  }

  static Future<void> _updateReport() async {
    if (_events.isEmpty) return;

    try {
      final buffer = StringBuffer();

      buffer.writeln('=== CRASH SESSION ===');
      buffer.writeln('Time: ${DateTime.now()}');
      buffer.writeln('OS: ${Platform.isMacOS ? '${Platform.operatingSystem} ' : ''}${Platform.operatingSystemVersion}');
      buffer.writeln('Dart SDK: ${Platform.version}');
      buffer.writeln('Events: ${_events.length}');
      buffer.writeln('');
      buffer.writeln(''); // Extra line for clearer separation

      for (final event in _events) {
        buffer.writeln(event.format());
      }

      final file = File(_sessionFilePath);
      await file.writeAsString(buffer.toString(), mode: FileMode.write);

      logger.i('''
Crash session updated at
${file.absolute.path}''');
    } catch (e) {
      logger.w('Failed to update crash session');
    }
  }
}