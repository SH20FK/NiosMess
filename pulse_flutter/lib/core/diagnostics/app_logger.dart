import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppLogLevel { info, warning, error }

class AppLogEntry {
  const AppLogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
    this.stackTrace,
  });

  final DateTime timestamp;
  final AppLogLevel level;
  final String source;
  final String message;
  final StackTrace? stackTrace;

  String get label {
    return switch (level) {
      AppLogLevel.info => 'INFO',
      AppLogLevel.warning => 'WARN',
      AppLogLevel.error => 'ERROR',
    };
  }

  String toLogLine() {
    final StringBuffer buffer = StringBuffer()
      ..write(timestamp.toIso8601String())
      ..write(' [$label] ')
      ..write(source)
      ..write(': ')
      ..write(message);
    final StackTrace? stack = stackTrace;
    if (stack != null) {
      buffer
        ..writeln()
        ..write(stack.toString());
    }
    return buffer.toString();
  }
}

class AppLogger {
  AppLogger._();

  static final AppLogger instance = AppLogger._();
  static const int _maxEntries = 80;

  final List<AppLogEntry> _entries = <AppLogEntry>[];

  List<AppLogEntry> get entries => List<AppLogEntry>.unmodifiable(_entries);

  void info(String message, {String source = 'app'}) {
    _add(
      AppLogEntry(
        timestamp: DateTime.now(),
        level: AppLogLevel.info,
        source: source,
        message: message,
      ),
    );
  }

  void warning(String message, {String source = 'app'}) {
    _add(
      AppLogEntry(
        timestamp: DateTime.now(),
        level: AppLogLevel.warning,
        source: source,
        message: message,
      ),
    );
  }

  void error(Object error, StackTrace stackTrace, {String source = 'app'}) {
    _add(
      AppLogEntry(
        timestamp: DateTime.now(),
        level: AppLogLevel.error,
        source: source,
        message: error.toString(),
        stackTrace: stackTrace,
      ),
    );
  }

  void flutterError(FlutterErrorDetails details) {
    _add(
      AppLogEntry(
        timestamp: DateTime.now(),
        level: AppLogLevel.error,
        source: details.context?.toDescription() ?? 'flutter',
        message: details.exceptionAsString(),
        stackTrace: details.stack,
      ),
    );
  }

  String exportText() {
    if (_entries.isEmpty) return 'No local log entries.';
    return _entries.map((AppLogEntry entry) => entry.toLogLine()).join('\n\n');
  }

  void clear() {
    _entries.clear();
  }

  void _add(AppLogEntry entry) {
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
    debugPrint(entry.toLogLine());
  }
}

final Provider<AppLogger> appLoggerProvider = Provider<AppLogger>(
  (Ref ref) => AppLogger.instance,
);
