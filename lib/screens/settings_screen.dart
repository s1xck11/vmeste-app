import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import '../services/sync_service.dart';
import '../services/storage_service.dart';

/// Экран настроек.
/// 
/// Пока простой: показывает статус синхронизации, код группы,
/// и позволяет изменить имя партнёра.
class SettingsScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;

  const SettingsScreen({
    super.key,
    required this.storage,
    required this.sync,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _refresh() => setState(() {});

  @override
  void initState() {
    super.initState();
    widget.sync.onStatusChanged = _refresh;
  }

  String _statusText() {
    switch (widget.sync.status) {
      case 'online':
        return '🟢 Подключено';
      case 'syncing':
        return '🟡 Синхронизация...';
      case 'error':
        return '🔴 Ошибка';
      default:
        return '⚪ Оффлайн';
    }
  }

  void _copyCode() {
    final code = widget.storage.coupleCode;
    if (code == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Код: $code')),
    );
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отключиться?'),
        content: const Text(
          'Данные останутся в облаке. Чтобы снова подключиться — введёшь код группы заново.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Отключиться', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.sync.disconnect();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.storage.coupleCode;
    final isConfigured = code != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // === СИНХРОНИЗАЦИЯ ===
          _sectionTitle('Синхронизация'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  title: const Text('Статус'),
                  trailing: Text(
                    _statusText(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (isConfigured) ...[
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Код группы'),
                    subtitle: Text(
                      code,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                        color: AppColors.accent,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: _copyCode,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Версия данных'),
                    trailing: Text(
                      '${widget.storage.serverVersion}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // === ИМЯ ПАРТНЁРА ===
          _sectionTitle('Моё имя'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              title: const Text('Как тебя зовут?'),
              subtitle: const Text('Будет видно партнёру'),
              trailing: const Icon(Icons.edit, color: AppColors.textSecondary),
              onTap: () async {
                final controller = TextEditingController(
                  text: widget.storage.myPartnerId ?? '',
                );
                final result = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Моё имя'),
                    content: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Например, Серёжа',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Отмена'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                        child: const Text('Сохранить'),
                      ),
                    ],
                  ),
                );
                if (result != null && result.isNotEmpty) {
                  widget.storage.myPartnerId = result;
                  _refresh();
                }
              },
            ),
          ),
          const SizedBox(height: 24),

          // === ОПАСНАЯ ЗОНА ===
          if (isConfigured) ...[
            _sectionTitle('Управление'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: const Text('Отключиться от группы'),
                trailing: const Icon(Icons.logout, color: AppColors.danger),
                onTap: _disconnect,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}