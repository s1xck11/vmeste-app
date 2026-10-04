// lib/screens/data_management_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../services/import_export_service.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/debug_log_service.dart';

class DataManagementScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;

  const DataManagementScreen({
    super.key,
    required this.storage,
    required this.sync,
  });

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  late final ImportExportService _service;
  final _log = DebugLogService();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _service = ImportExportService(widget.storage);
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final path = await _service.exportToFile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Файл сохранён:\n$path'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Скопировать путь',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: path));
            },
          ),
        ),
      );
    } catch (e, st) {
      _log.error('DataScreen', 'export error', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка экспорта: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) {
        setState(() => _busy = false);
        return;
      }
      final path = result.files.single.path!;

      if (!mounted) return;
      final mode = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Как импортировать?'),
          content: const Text(
            'Файл будет прочитан и применён к локальным данным. '
            'Записи с одинаковым ID не дублируются.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Отмена'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'replace'),
              child: const Text('Заменить всё'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8FAB),
              ),
              onPressed: () => Navigator.pop(ctx, 'add'),
              child: const Text('Добавить'),
            ),
          ],
        ),
      );

      if (mode == null) {
        setState(() => _busy = false);
        return;
      }

      final stats = await _service.importFromFile(
        path,
        replaceAll: mode == 'replace',
      );

      widget.sync.schedulePush();

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('✅ Импорт завершён'),
          content: SingleChildScrollView(
            child: Text(
              '${stats.toString()}\n\nВсего: ${stats.total}\n\n'
              'Данные отправляются в облако...',
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8FAB),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e, st) {
      _log.error('DataScreen', 'import error', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка импорта: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showDir() async {
    final path = await _service.getBackupDir();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Папка с бэкапами'),
        content: SelectableText(path),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: path));
              Navigator.pop(ctx);
            },
            child: const Text('Скопировать'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Данные'),
        backgroundColor: const Color(0xFFFF8FAB),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Здесь можно сохранить все данные приложения в файл '
            'и загрузить их обратно — например, для переноса со старой '
            'HTML-версии или для резервной копии.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          _buildActionCard(
            icon: Icons.upload_file,
            color: const Color(0xFF34C759),
            title: 'Экспорт в файл',
            subtitle: 'Сохранить все данные в JSON',
            onTap: _busy ? null : _export,
          ),
          const SizedBox(height: 12),

          _buildActionCard(
            icon: Icons.download,
            color: const Color(0xFF5856D6),
            title: 'Импорт из файла',
            subtitle: 'Загрузить данные из JSON-бэкапа',
            onTap: _busy ? null : _import,
          ),
          const SizedBox(height: 12),

          _buildActionCard(
            icon: Icons.folder,
            color: Colors.orange,
            title: 'Где лежат бэкапы',
            subtitle: 'Показать папку с сохранёнными файлами',
            onTap: _showDir,
          ),

          if (_busy)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: Color(0xFFFF8FAB))),
            ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF8F9FA),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}