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
    Clipboard.setData(ClipboardData(text: _logger.asText()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Скопировано ${_logger.all.length} записей')),
    );
  }

  void _clear() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить лог?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
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

  Color _levelColor(String level, ColorScheme cs) {
    switch (level) {
      case 'ERROR': return cs.error;
      case 'WARN': return cs.secondary;
      default: return cs.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final logs = _logger.all.reversed.toList();
    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        title: const Text('Отладка'),
        actions: [
          IconButton(onPressed: _clear, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: cs.primaryContainer,
            child: Row(
              children: [
                Expanded(child: Text('Записей: ${logs.length}', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onPrimaryContainer))),
                ElevatedButton.icon(
                  onPressed: _copyAll,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Скопировать'),
                ),
              ],
            ),
          ),
          Expanded(
            child: logs.isEmpty
                ? Center(child: Text('Пока пусто', style: TextStyle(color: cs.onSurfaceVariant)))
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
                            SizedBox(width: 70, child: Text(
                              e.time.toIso8601String().substring(11, 19),
                              style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: cs.onSurfaceVariant),
                            )),
                            SizedBox(width: 50, child: Text(
                              e.level,
                              style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: _levelColor(e.level, cs)),
                            )),
                            Expanded(child: Text(
                              '[${e.tag}] ${e.message}',
                              style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: cs.onSurface),
                            )),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() {}),
        child: const Icon(Icons.refresh),
      ),
    );
  }
}