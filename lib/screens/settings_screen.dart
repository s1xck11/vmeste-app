import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart' show AppColors;
import '../services/sync_service.dart';
import '../services/storage_service.dart';

/// Экран настроек.
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
  void _refresh() {
    if (mounted) setState(() {});
  }

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

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ $label скопирован')),
    );
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: widget.storage.myName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Моё имя'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
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

    if (result != null) {
      widget.storage.myName = result;
      widget.sync.schedulePush();
      _refresh();
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отключиться?'),
        content: const Text(
          '⚠️ Сохрани свой личный ключ ПЕРЕД отключением!\n\n'
          'Без него ты не сможешь восстановить доступ с нового устройства.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Отключиться',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.sync.disconnect();
      if (!mounted) return;
      // Перезапуск — приложение покажет SetupScreen
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.storage.coupleCode;
    final key = widget.storage.myKey;
    final name = widget.storage.myName;
    final isConfigured = code != null && key != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // === СИНХРОНИЗАЦИЯ ===
          _sectionTitle('Синхронизация'),
          _card(
            children: [
              _row(
                label: 'Статус',
                trailing: Text(
                  _statusText(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (isConfigured) ...[
                _divider(),
                _row(
                  label: 'Код группы',
                  subtitle: code,
                  subtitleColor: AppColors.accent,
                  subtitleMonospace: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () => _copy(code, 'Код'),
                  ),
                ),
                _divider(),
                _row(
                  label: 'Версия данных',
                  trailing: Text(
                    '${widget.storage.serverVersion}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // === МОЙ КЛЮЧ ===
          if (key != null) ...[
            _sectionTitle('🔑 Мой личный ключ'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent, width: 2),
              ),
              child: Column(
                children: [
                  const Text(
                    'Сохрани его! Он нужен для входа с нового телефона.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    key,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                      fontFamily: 'monospace',
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _copy(key, 'Ключ'),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Скопировать ключ'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.accent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // === ИМЯ ===
          _sectionTitle('Моё имя'),
          _card(
            children: [
              ListTile(
                title: const Text('Как тебя зовут?'),
                subtitle: Text(
                  name.isEmpty ? 'Нажми, чтобы ввести' : name,
                  style: TextStyle(
                    color: name.isEmpty ? AppColors.textSecondary : null,
                    fontWeight: name.isEmpty ? null : FontWeight.w600,
                  ),
                ),
                trailing: const Icon(Icons.edit, color: AppColors.textSecondary),
                onTap: _editName,
              ),
              if (widget.storage.partnerName.isNotEmpty) ...[
                _divider(),
                ListTile(
                  title: const Text('Имя партнёра'),
                  subtitle: Text(
                    widget.storage.partnerName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // === УПРАВЛЕНИЕ ===
          if (isConfigured) ...[
            _sectionTitle('Управление'),
            _card(
              children: [
                ListTile(
                  title: const Text('Отключиться от группы'),
                  trailing: const Icon(
                    Icons.logout,
                    color: AppColors.danger,
                  ),
                  onTap: _disconnect,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ============ ХЕЛПЕРЫ ============

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

  Widget _card({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 16, endIndent: 16);

  Widget _row({
    required String label,
    String? subtitle,
    Color? subtitleColor,
    bool subtitleMonospace = false,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 15)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: subtitleColor ?? AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontFamily: subtitleMonospace ? 'monospace' : null,
                      letterSpacing: subtitleMonospace ? 2 : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}