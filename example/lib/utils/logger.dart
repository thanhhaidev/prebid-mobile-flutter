import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Simple logger that tracks SDK events with timestamps.
///
/// Mirrors Prebid demo's PrebidDemoLogger.
class PrebidDemoLogger extends ChangeNotifier {
  static final PrebidDemoLogger instance = PrebidDemoLogger._();

  PrebidDemoLogger._();

  final List<LogEntry> _entries = [];

  UnmodifiableListView<LogEntry> get entries => UnmodifiableListView(_entries);

  void log(String tag, String message, {LogLevel level = LogLevel.info}) {
    _entries.add(
      LogEntry(
        timestamp: DateTime.now(),
        tag: tag,
        message: message,
        level: level,
      ),
    );
    notifyListeners();
    if (kDebugMode) {
      final prefix = switch (level) {
        LogLevel.error => '❌',
        LogLevel.warning => '⚠️',
        LogLevel.info => 'ℹ️',
        LogLevel.debug => '🔍',
      };
      print('$prefix [$tag] $message');
    }
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}

enum LogLevel { debug, info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final String tag;
  final String message;
  final LogLevel level;

  const LogEntry({
    required this.timestamp,
    required this.tag,
    required this.message,
    required this.level,
  });

  String get timeString =>
      '${timestamp.hour.toString().padLeft(2, '0')}:'
      '${timestamp.minute.toString().padLeft(2, '0')}:'
      '${timestamp.second.toString().padLeft(2, '0')}.'
      '${timestamp.millisecond.toString().padLeft(3, '0')}';
}
