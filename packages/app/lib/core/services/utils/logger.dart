import 'dart:io';

import 'package:logger/logger.dart';

int _getLineLength() {
  try {
    if (stdout.hasTerminal) {
      return stdout.terminalColumns;
    }
  } catch (_) {}
  return 120;
}

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
    lineLength: _getLineLength(),
    colors: /* stdout.supportsAnsiEscapes */ true,
    printEmojis: false,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart
  )
);