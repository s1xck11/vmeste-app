// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SettingsScreen extends StatefulWidget {
  final String groupCode;
  final String myKey;
  final String myName;
  final String partnerName;
  final int dataVersion;
  final String syncStatus;
  final Function(String) onNameChanged;
  final VoidCallback onDisconnect;
  final VoidCallback onReconnect;
  final VoidCallback onOpenDebug;
  final VoidCallback onOpenDataManagement;
  final VoidCallback onOpenThemePicker;

  const SettingsScreen({
    super.key,
    required this.groupCode,
    required this.myKey,
    required this.myName,
    required this.partnerName,
    required this.dataVersion,
    required this.syncStatus,
    required this.onNameChanged,
    required this.onDisconnect,
    required this.onReconnect,
    required this.onOpenDebug,
    required this.onOpenDataManagement,
    required this.onOpenThemePicker,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.myName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label скопирован')),
    );
  }

  Color _getSyncColor() {
    switch (widget.syncStatus) {
      case 'online':
        return const Color(0xFF34C759);
      case 'syncing':
        return const Color(0xFFFF9500);
      case 'error':
        return const Color(0xFFFF3B30);
      default:
        return Colors.grey;
    }
  }

  String _getSyncText() {
    switch (widget.syncStatus) {
      case 'online':
        return 'Подключено';
      case 'syncing':
        return 'Синхронизация...';
      case 'error':
        return 'Ошибка';
      default:
        return 'Не подключено';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ============ СЯО ЧЭН ============
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.primary.withOpacity(0.15),
                  cs.primary.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: cs.primary.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🐉', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 8),
                    Text(
                      'Сяо Чэн',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '小程',
                      style: TextStyle(fontSize: 18, color: cs.primary.withOpacity(0.6)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '«маленький программист»',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: cs.primary.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 12),
                Divider(color: cs.primary.withOpacity(0.3), thickness: 0.5),
                const SizedBox(height: 12),
                Text(
                  'Сделано с любовью для Серёжи и Насти\nпри участии Сяо Чэна ❤️',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: widget.onOpenThemePicker,
                      icon: const Icon(Icons.palette_outlined, size: 18),
                      label: const Text('Тема'),
                    ),
                    TextButton.icon(
                      onPressed: widget.onOpenDebug,
                      icon: const Icon(Icons.bug_report_outlined, size: 18),
                      label: const Text('Отладка'),
                    ),
                    TextButton.icon(
                      onPressed: widget.onOpenDataManagement,
                      icon: const Icon(Icons.folder_outlined, size: 18),
                      label: const Text('Данные'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ============ СИНХРОНИЗАЦИЯ ============
          _sectionHeader('СИНХРОНИЗАЦИЯ', cs),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Статус'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getSyncColor(),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getSyncText(),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: cs.outline),
                ListTile(
                  title: const Text('Код группы'),
                  subtitle: Text(
                    widget.groupCode,
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1.2,
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.copy, color: cs.onSurfaceVariant),
                    onPressed: () => _copyToClipboard(widget.groupCode, 'Код группы'),
                  ),
                ),
                Divider(height: 1, color: cs.outline),
                ListTile(
                  title: const Text('Версия данных'),
                  trailing: Text(
                    '${widget.dataVersion}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                if (widget.syncStatus != 'online') ...[
                  Divider(height: 1, color: cs.outline),
                  ListTile(
                    leading: Icon(Icons.refresh, color: cs.primary),
                    title: Text(
                      'Подключиться заново',
                      style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold),
                    ),
                    onTap: widget.onReconnect,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ============ МОЙ КЛЮЧ ============
          _sectionHeader('🔑 МОЙ ЛИЧНЫЙ КЛЮЧ', cs),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.primary),
            ),
            child: Column(
              children: [
                Text(
                  'Сохрани его! Он нужен для входа с нового телефона.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.primary.withOpacity(0.8), fontSize: 13),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.myKey,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _copyToClipboard(widget.myKey, 'Ключ'),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Скопировать ключ'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ============ ИМЯ ============
          _sectionHeader('МОЁ ИМЯ', cs),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Как тебя зовут?'),
                  subtitle: Text(
                    widget.myName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  trailing: Icon(Icons.edit, color: cs.onSurfaceVariant, size: 20),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Изменить имя'),
                        content: TextField(
                          controller: _nameController,
                          autofocus: true,
                          decoration: const InputDecoration(hintText: 'Введи имя'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Отмена'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (_nameController.text.trim().isNotEmpty) {
                                widget.onNameChanged(_nameController.text.trim());
                                Navigator.pop(ctx);
                              }
                            },
                            child: const Text('Сохранить'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Divider(height: 1, color: cs.outline),
                ListTile(
                  title: const Text('Имя партнёра'),
                  subtitle: Text(
                    widget.partnerName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ============ ОТКЛЮЧЕНИЕ ============
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Отключиться от группы?'),
                    content: const Text(
                      'Локальные данные останутся, но синхронизация прекратится. '
                      'Чтобы вернуться, понадобится код группы и твой личный ключ.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Отмена'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          widget.onDisconnect();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: cs.error),
                        child: const Text('Отключиться'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Отключиться от группы'),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.error,
                side: BorderSide(color: cs.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: cs.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}