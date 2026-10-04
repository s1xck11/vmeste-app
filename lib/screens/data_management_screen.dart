// lib/screens/data_management_screen.dart

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
          content: Text('Сохранено:\n$path'),
          action: SnackBarAction(label: 'Путь', onPressed: () => Clipboard.setData(ClipboardData(text: path))),
        ),
      );
    } catch (e, st) {
      _log.error('DataScreen', 'export error', e, st);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['json'],
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
          content: const Text('Записи с одинаковым ID не дублируются.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Отмена')),
            OutlinedButton(onPressed: () => Navigator.pop(ctx, 'replace'), child: const Text('Заменить')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, 'add'), child: const Text('Добавить')),
          ],
        ),
      );
      if (mode == null) {
        setState(() => _busy = false);
        return;
      }
      final stats = await _service.importFromFile(path, replaceAll: mode == 'replace');
      widget.sync.schedulePush();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('✅ Импорт завершён'),
          content: SingleChildScrollView(child: Text('${stats.toString()}\n\nВсего: ${stats.total}')),
          actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
    } catch (e, st) {
      _log.error('DataScreen', 'import error', e, st);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
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
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(title: const Text('Данные')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Сохрани все данные в файл и загрузи обратно — для переноса или резервной копии.',
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          _card(Icons.upload_file, const Color(0xFF34C759), 'Экспорт в файл', 'Сохранить в JSON', _busy ? null : _export, cs),
          const SizedBox(height: 12),
          _card(Icons.download, const Color(0xFF5856D6), 'Импорт из файла', 'Загрузить из JSON', _busy ? null : _import, cs),
          const SizedBox(height: 12),
          _card(Icons.folder, Colors.orange, 'Где лежат бэкапы', 'Показать папку', _showDir, cs),
          if (_busy) const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }

  Widget _card(IconData icon, Color color, String title, String subtitle, VoidCallback? onTap, ColorScheme cs) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface)),
        subtitle: Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
        trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }
}