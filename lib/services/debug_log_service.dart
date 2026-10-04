// lib/services/debug_log_service.dart

import 'dart:collection';

class LogEntry {
  final DateTime time;
  final String level; // INFO, WARN, ERROR
  final String tag;   // SyncService, Storage, UI, ...
  final String message;

  LogEntry({
    required this.time,
    required this.level,
    required this.tag,
    required this.message,
  });

  String toLine() {
    final t = time.toIso8601String().substring(11, 23); // HH:MM:SS.mmm
    return '[$t] [$level] [$tag] $message';
  }
}

class DebugLogService {
  static final DebugLogService _instance = DebugLogService._internal();
  factory DebugLogService() => _instance;
  DebugLogService._internal();

  final Queue<LogEntry> _logs = Queue();
  final int _maxSize = 500;

  void info(String tag, String message) => _add('INFO', tag, message);
  void warn(String tag, String message) => _add('WARN', tag, message);
  void error(String tag, String message, [Object? err, StackTrace? st]) {
    final full = err != null ? '$message\n  → $err' : message;
    _add('ERROR', tag, full);
    if (st != null) {
      _add('ERROR', tag, '  stack: ${st.toString().split('\n').take(4).join(' | ')}');
    }
  }

  void _add(String level, String tag, String message) {
    _logs.add(LogEntry(
      time: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
    ));
    while (_logs.length > _maxSize) {
      _logs.removeFirst();
    }
    // Дублируем в обычный print — для случая, когда есть USB-логи
    print('[$level][$tag] $message');
  }

  List<LogEntry> get all => _logs.toList();

  String asText() {
    final buf = StringBuffer();
    buf.writeln('=== VMESTE DEBUG LOG ===');
    buf.writeln('Собрано: ${DateTime.now().toIso8601String()}');
    buf.writeln('Записей: ${_logs.length}');
    buf.writeln('========================');
    for (final e in _logs) {
      buf.writeln(e.toLine());
    }
    return buf.toString();
  }

  void clear() => _logs.clear();
}