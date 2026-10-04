// lib/screens/debug_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/debug_log_service.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final _logger = DebugLogService();

  void _copyAll() {
    final text = _logger.asText();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Скопировано ${_logger.all.length} записей в буфер'),
      ),
    );
  }

  void _clear() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить лог?'),
        content: const Text('Все записи будут удалены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _logger.clear();
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'ERROR':
        return Colors.red;
      case 'WARN':
        return Colors.orange;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = _logger.all.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Отладка'),
        backgroundColor: const Color(0xFFFF8FAB),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Очистить',
            icon: const Icon(Icons.delete_outline),
            onPressed: _clear,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFFFFE5EC),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Записей: ${logs.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _copyAll,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Скопировать всё'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8FAB),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: logs.isEmpty
                ? const Center(child: Text('Пока пусто'))
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: logs.length,
                    itemBuilder: (ctx, i) {
                      final e = logs[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 70,
                              child: Text(
                                e.time.toIso8601String().substring(11, 19),
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 50,
                              child: Text(
                                e.level,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _levelColor(e.level),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '[${e.tag}] ${e.message}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          setState(() {});
        },
        backgroundColor: const Color(0xFFFF8FAB),
        icon: const Icon(Icons.refresh, color: Colors.white),
        label: const Text('Обновить', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}