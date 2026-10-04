// lib/screens/settings_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/theme_service.dart';
import '../services/background_service.dart';
import '../services/notification_service.dart';
import 'avatar_picker_screen.dart';
import 'data_management_screen.dart';
import 'debug_screen.dart';
import 'courier_import_screen.dart';
import 'theme_picker_screen.dart';
import 'categories_editor_screen.dart';
import 'partners_editor_screen.dart';
import 'purchase_templates_screen.dart';
import 'purchase_history_screen.dart';

class SettingsScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;
  final ThemeService themeService;
  final VoidCallback onDisconnect;
  final VoidCallback onReconnect;

  const SettingsScreen({
    super.key,
    required this.storage,
    required this.sync,
    required this.themeService,
    required this.onDisconnect,
    required this.onReconnect,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;
  late BackgroundService _bgService;
  late NotificationService _notifService;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.storage.myName);
    _bgService = BackgroundService(widget.storage);
    _notifService = NotificationService(widget.storage);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label скопирован')));
  }

  Future<void> _pickAvatar() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => AvatarPickerScreen(currentAvatar: widget.storage.myAvatar)),
    );
    if (result != null) {
      widget.storage.myAvatar = result;
      setState(() {});
    }
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: widget.storage.myName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Твоё имя'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Сохранить')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      widget.storage.myName = result;
      widget.sync.schedulePush();
      setState(() {});
    }
  }

  Future<void> _pickBackground() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: false,
      );
      if (result == null || result.files.single.path == null) return;

      final path = result.files.single.path!;
      final file = File(path);
      if (!await file.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл не найден')),
        );
        return;
      }

      final bytes = await file.readAsBytes();

      // Ограничение 3 МБ
      if (bytes.length > 3 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл слишком большой (макс 3 МБ). Выбери другой.')),
        );
        return;
      }

      await _bgService.saveImage(bytes);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Фон сохранён')),
      );
    } catch (e, st) {
      debugPrint('Background pick FAILED: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _clearBackground() async {
    await _bgService.clearImage();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _setBlur(double v) async {
    await _bgService.setBlur(v);
    setState(() {});
  }

  Color _syncColor() {
    switch (widget.sync.status) {
      case 'online': return const Color(0xFF34C759);
      case 'syncing': return const Color(0xFFFF9500);
      case 'error': return const Color(0xFFFF3B30);
      default: return Colors.grey;
    }
  }

  String _syncText() {
    switch (widget.sync.status) {
      case 'online': return 'Подключено';
      case 'syncing': return 'Синхронизация...';
      case 'error': return 'Ошибка';
      default: return 'Не подключено';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.primary, width: 2),
                    ),
                    child: Center(child: Text(widget.storage.myAvatar, style: const TextStyle(fontSize: 44))),
                  ),
                ),
                const SizedBox(height: 8),
                Text(widget.storage.myName.isEmpty ? 'Нажми, чтобы выбрать аватар' : widget.storage.myName,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary.withOpacity(0.15), cs.primary.withOpacity(0.05)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.primary.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('🐉', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text('Сяо Чэн 小程', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.primary)),
                ]),
                const SizedBox(height: 6),
                Text('Сделано с любовью для Серёжи и Насти ❤️', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: cs.onSurface)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _sectionTitle('АККАУНТ', cs),
          _tile(icon: Icons.person_outline, title: 'Моё имя', subtitle: widget.storage.myName.isEmpty ? 'Не задано' : widget.storage.myName, onTap: _editName, cs: cs),
          _tile(icon: Icons.palette_outlined, title: 'Оформление', subtitle: 'Тема и палитра',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ThemePickerScreen(themeService: widget.themeService))), cs: cs),
          _tile(icon: Icons.wallpaper, title: 'Фон приложения', subtitle: _bgService.getImageBytes() == null ? 'Не задан' : 'Задан',
              onTap: () => _showBackgroundDialog(cs), cs: cs),

          const SizedBox(height: 16),
          _sectionTitle('СИНХРОНИЗАЦИЯ', cs),
          _tile(icon: Icons.circle, iconColor: _syncColor(), title: 'Статус', subtitle: _syncText(), cs: cs),
          _tile(icon: Icons.copy, title: 'Код группы', subtitle: widget.storage.coupleCode ?? '—',
              onTap: () => _copy(widget.storage.coupleCode ?? '', 'Код'), cs: cs),
          _tile(icon: Icons.numbers, title: 'Версия данных', subtitle: '${widget.storage.serverVersion}', cs: cs),
          _tile(icon: Icons.sync, title: 'Отправить в облако', subtitle: 'Принудительная синхронизация',
              onTap: () { widget.sync.schedulePush(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Отправлено'))); }, cs: cs),
          _tile(icon: Icons.people_outline, title: 'Участники группы', subtitle: '${widget.storage.members.length} устройств', onTap: () => _showMembers(cs), cs: cs),
          if (widget.sync.status != 'online')
            _tile(icon: Icons.refresh, title: 'Подключиться заново', onTap: widget.onReconnect, cs: cs),

          const SizedBox(height: 16),
          _sectionTitle('🔑 МОЙ КЛЮЧ', cs),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.primary),
            ),
            child: Column(
              children: [
                Text('Сохрани его!', style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer.withOpacity(0.8))),
                const SizedBox(height: 10),
                Text(widget.storage.myKey ?? '', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2, color: cs.onPrimaryContainer)),
                const SizedBox(height: 10),
                OutlinedButton.icon(onPressed: () => _copy(widget.storage.myKey ?? '', 'Ключ'), icon: const Icon(Icons.copy, size: 16), label: const Text('Скопировать')),
              ],
            ),
          ),

          const SizedBox(height: 16),
          _sectionTitle('РЕДАКТОРЫ', cs),
          _tile(icon: Icons.category_outlined, title: 'Категории покупок', onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CategoriesEditorScreen(storage: widget.storage, sync: widget.sync, kind: CategoryKind.purchase))), cs: cs),
          _tile(icon: Icons.checklist, title: 'Категории задач', onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CategoriesEditorScreen(storage: widget.storage, sync: widget.sync, kind: CategoryKind.task))), cs: cs),
          _tile(icon: Icons.calendar_today_outlined, title: 'Типы смен', onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CategoriesEditorScreen(storage: widget.storage, sync: widget.sync, kind: CategoryKind.shiftType))), cs: cs),
          _tile(icon: Icons.people, title: 'Партнёры и зарплата', onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PartnersEditorScreen(storage: widget.storage, sync: widget.sync))), cs: cs),

          const SizedBox(height: 16),
          _sectionTitle('ИНСТРУМЕНТЫ', cs),
          _tile(icon: Icons.download, title: 'Импорт из Курьера', subtitle: 'Вставить JSON',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CourierImportScreen(storage: widget.storage, sync: widget.sync))), cs: cs),
          _tile(icon: Icons.view_list, title: 'Шаблоны покупок', onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PurchaseTemplatesScreen(storage: widget.storage, sync: widget.sync))), cs: cs),
          _tile(icon: Icons.history, title: 'История покупок', onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PurchaseHistoryScreen(storage: widget.storage, sync: widget.sync))), cs: cs),
          _tile(icon: Icons.folder_outlined, title: 'Данные', subtitle: 'Экспорт / Импорт JSON',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => DataManagementScreen(storage: widget.storage, sync: widget.sync))), cs: cs),
          _tile(icon: Icons.bug_report_outlined, title: 'Отладка', onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DebugScreen())), cs: cs),

          const SizedBox(height: 16),
          _sectionTitle('УВЕДОМЛЕНИЯ', cs),
          SwitchListTile(
            value: _notifService.enabled,
            onChanged: (v) async {
              await _notifService.setEnabled(v);
              setState(() {});
            },
            title: const Text('Напоминания о сменах'),
            subtitle: const Text('Требуется разрешение системы'),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Отключиться?'),
                    content: const Text('Локальные данные останутся. Синхронизация прекратится.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
                      ElevatedButton(
                        onPressed: () { Navigator.pop(ctx); widget.onDisconnect(); },
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBackgroundDialog(ColorScheme cs) async {
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => AlertDialog(
          title: const Text('Фон приложения'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: OutlinedButton.icon(onPressed: _pickBackground, icon: const Icon(Icons.upload), label: const Text('Загрузить'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(onPressed: _clearBackground, icon: const Icon(Icons.clear), label: const Text('Убрать'))),
                ],
              ),
              const SizedBox(height: 12),
              Text('Размытие: ${_bgService.blur.toStringAsFixed(0)}'),
              Slider(
                value: _bgService.blur, min: 0, max: 30,
                onChanged: (v) async {
                  await _setBlur(v);
                  setSt(() {});
                  setState(() {});
                },
              ),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      ),
    );
  }

  void _showMembers(ColorScheme cs) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Участники группы'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widget.storage.members.map((uid) {
            final isMe = uid == widget.storage.currentUserId;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('${isMe ? "📱 Это вы" : "📱 Устройство"}: ${uid.length > 8 ? uid.substring(0, 8) : uid}…',
                  style: TextStyle(color: isMe ? cs.primary : cs.onSurface, fontWeight: isMe ? FontWeight.bold : FontWeight.normal)),
            );
          }).toList(),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  Widget _sectionTitle(String text, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant, letterSpacing: 0.8)),
    );
  }

  Widget _tile({required IconData icon, required String title, String? subtitle, VoidCallback? onTap, Color? iconColor, required ColorScheme cs}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? cs.primary, size: 22),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: cs.onSurface)),
        subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)) : null,
        trailing: onTap != null ? Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20) : null,
        onTap: onTap,
      ),
    );
  }
}