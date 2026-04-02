class CrashEvent {
  final DateTime time;
  final String error;
  final StackTrace? stack;

  CrashEvent(this.error, this.stack) : time = DateTime.now();

  String format() => '''
--- EVENT ---
Time: $time
Error: $error
StackTrace:
$stack''';
}