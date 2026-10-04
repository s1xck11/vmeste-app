// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SettingsScreen extends StatefulWidget {
  final String groupCode;
  final String myKey;
  final String myName;
  final String partnerName;
  final int dataVersion;
  final String syncStatus; // 'connected', 'connecting', 'offline', 'error'
  final Function(String) onNameChanged;
  final VoidCallback onDisconnect;

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
      case 'connected':
        return const Color(0xFF34C759);
      case 'connecting':
        return const Color(0xFFFF9500);
      case 'error':
        return const Color(0xFFFF3B30);
      default:
        return Colors.grey;
    }
  }

  String _getSyncText() {
    switch (widget.syncStatus) {
      case 'connected':
        return 'Подключено';
      case 'connecting':
        return 'Подключение...';
      case 'error':
        return 'Ошибка';
      default:
        return 'Не подключено';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        backgroundColor: const Color(0xFFFF8FAB),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ==========================================
          // БЛОК С СЯО ЧЭНОМ (小程)
          // ==========================================
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFE5EC), Color(0xFFFFF0F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFF8FAB).withOpacity(0.3)),
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
                        color: Colors.pink[700],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '小程',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.pink[300],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '«маленький программист»',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.pink[400],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFFFF8FAB), thickness: 0.5),
                const SizedBox(height: 12),
                Text(
                  'Сделано с любовью для Серёжи и Насти\nпри участии Сяо Чэна ❤️',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.pink[800],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ==========================================
          // СЕКЦИЯ: СИНХРОНИЗАЦИЯ
          // ==========================================
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'СИНХРОНИЗАЦИЯ',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Card(
            elevation: 0,
            color: const Color(0xFFF8F9FA),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: const Text('Код группы'),
                  subtitle: Text(
                    widget.groupCode,
                    style: const TextStyle(
                      color: Color(0xFFFF8FAB),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1.2,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy, color: Colors.grey),
                    onPressed: () => _copyToClipboard(widget.groupCode, 'Код группы'),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: const Text('Версия данных'),
                  trailing: Text(
                    '${widget.dataVersion}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ==========================================
          // СЕКЦИЯ: МОЙ ЛИЧНЫЙ КЛЮЧ
          // ==========================================
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '🔑 МОЙ ЛИЧНЫЙ КЛЮЧ',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE5EC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFF8FAB)),
            ),
            child: Column(
              children: [
                Text(
                  'Сохрани его! Он нужен для входа с нового телефона.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.pink[400], fontSize: 13),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.myKey,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink[600],
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _copyToClipboard(widget.myKey, 'Ключ'),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Скопировать ключ'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF8FAB),
                    side: const BorderSide(color: Color(0xFFFF8FAB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ==========================================
          // СЕКЦИЯ: ИМЕНА
          // ==========================================
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'МОЁ ИМЯ',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Card(
            elevation: 0,
            color: const Color(0xFFF8F9FA),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  title: const Text('Как тебя зовут?'),
                  subtitle: Text(
                    widget.myName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  trailing: const Icon(Icons.edit, color: Colors.grey, size: 20),
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF8FAB),
                            ),
                            child: const Text('Сохранить'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
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

          // ==========================================
          // КНОПКА ОТКЛЮЧЕНИЯ
          // ==========================================
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF3B30),
                        ),
                        child: const Text('Отключиться'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Отключиться от группы'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF3B30),
                side: const BorderSide(color: Color(0xFFFF3B30)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}