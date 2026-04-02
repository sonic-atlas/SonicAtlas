import 'dart:io';

import 'package:logger/logger.dart';

/// logger
/// ------
/// Usage:
/// ```dart
/// logger.t('Trace log');
/// logger.d('Debug log');
/// logger.i('Info log');
/// logger.w('Warning log');
/// logger.e('Error log', error: 'Test Error');
/// logger.f('Fatal log', error: error, stackTrace: stackTrace);
/// ```
Logger logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 8,
    lineLength: stdout.hasTerminal ? stdout.terminalColumns : 120,
    colors: /* stdout.supportsAnsiEscapes */ true,
    printEmojis: false,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart
  )
);