// lib/screens/settings_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/theme_service.dart';
import '../services/background_service.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
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
  final _updateService = UpdateService();
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.storage.myName);
    _bgService = BackgroundService.instance;
    _notifService = NotificationService(widget.storage);
    _notifService.init();
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
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return;
      if (bytes.length > 8 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл больше 8 МБ')),
        );
        return;
      }
      await _bgService.saveImage(bytes);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Фон сохранён')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
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

  Future<void> _checkUpdates() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      final info = await _updateService.checkForUpdate();
      if (!mounted) return;
      if (info == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Обновлений нет. У тебя последняя версия.')),
        );
      } else {
        _showUpdateDialog(info);
      }
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  void _showUpdateDialog(UpdateInfo info) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Доступна версия ${info.tag}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (info.apkSize > 0)
                Text('Размер: ${(info.apkSize / 1024 / 1024).toStringAsFixed(1)} МБ',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              if (info.body.isNotEmpty)
                Text(info.body, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Позже')),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await _updateService.downloadAndInstall(info);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ok ? 'Открываю установщик...' : 'Не удалось скачать')),
              );
            },
            icon: const Icon(Icons.download),
            label: const Text('Скачать и установить'),
          ),
        ],
      ),
    );
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
                Text('Сделано с любовью для Серёжи и Насти ❤️',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: cs.onSurface)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _sectionTitle('АККАУНТ', cs),
          _tile(icon: Icons.person_outline, title: 'Моё имя',
              subtitle: widget.storage.myName.isEmpty ? 'Не задано' : widget.storage.myName,
              onTap: _editName, cs: cs),
          _tile(icon: Icons.palette_outlined, title: 'Оформление', subtitle: 'Тема и палитра',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ThemePickerScreen(themeService: widget.themeService))), cs: cs),
          _tile(icon: Icons.wallpaper, title: 'Фон приложения',
              subtitle: _bgService.hasImage ? 'Задан' : 'Не задан',
              onTap: () => _showBackgroundDialog(cs), cs: cs),

          const SizedBox(height: 16),
          _sectionTitle('СИНХРОНИЗАЦИЯ', cs),
          _tile(icon: Icons.circle, iconColor: _syncColor(), title: 'Статус', subtitle: _syncText(), cs: cs),
          _tile(icon: Icons.copy, title: 'Код группы', subtitle: widget.storage.coupleCode ?? '—',
              onTap: () => _copy(widget.storage.coupleCode ?? '', 'Код'), cs: cs),
          _tile(icon: Icons.numbers, title: 'Версия данных', subtitle: '${widget.storage.serverVersion}', cs: cs),
          _tile(icon: Icons.sync, title: 'Отправить в облако', subtitle: 'Принудительная синхронизация',
              onTap: () { widget.sync.schedulePush(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Отправлено'))); }, cs: cs),
          _tile(icon: Icons.people_outline, title: 'Участники группы',
              subtitle: '${widget.storage.members.length} устройств',
              onTap: () => _showMembers(cs), cs: cs),
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
                Text(widget.storage.myKey ?? '',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2, color: cs.onPrimaryContainer)),
                const SizedBox(height: 10),
                OutlinedButton.icon(onPressed: () => _copy(widget.storage.myKey ?? '', 'Ключ'), icon: const Icon(Icons.copy, size: 16), label: const Text('Скопировать')),
              ],
            ),
          ),

          const SizedBox(height: 16),
          _sectionTitle('РЕДАКТОРЫ', cs),
          _tile(icon: Icons.category_outlined, title: 'Категории покупок',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CategoriesEditorScreen(storage: widget.storage, sync: widget.sync, kind: CategoryKind.purchase))), cs: cs),
          _tile(icon: Icons.checklist, title: 'Категории задач',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CategoriesEditorScreen(storage: widget.storage, sync: widget.sync, kind: CategoryKind.task))), cs: cs),
          _tile(icon: Icons.calendar_today_outlined, title: 'Типы смен',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CategoriesEditorScreen(storage: widget.storage, sync: widget.sync, kind: CategoryKind.shiftType))), cs: cs),
          _tile(icon: Icons.people, title: 'Партнёры и зарплата',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PartnersEditorScreen(storage: widget.storage, sync: widget.sync))), cs: cs),

          const SizedBox(height: 16),
          _sectionTitle('ИНСТРУМЕНТЫ', cs),
          _tile(icon: Icons.system_update_alt, title: 'Проверить обновления',
              subtitle: _checkingUpdate ? 'Проверяю...' : 'Версия ${UpdateService.currentVersion}',
              onTap: _checkingUpdate ? null : _checkUpdates, cs: cs),
          _tile(icon: Icons.download, title: 'Импорт из Курьера', subtitle: 'Вставить JSON',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CourierImportScreen(storage: widget.storage, sync: widget.sync))), cs: cs),
          _tile(icon: Icons.view_list, title: 'Шаблоны покупок',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PurchaseTemplatesScreen(storage: widget.storage, sync: widget.sync))), cs: cs),
          _tile(icon: Icons.history, title: 'История покупок',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PurchaseHistoryScreen(storage: widget.storage, sync: widget.sync))), cs: cs),
          _tile(icon: Icons.folder_outlined, title: 'Данные', subtitle: 'Экспорт / Импорт JSON',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => DataManagementScreen(storage: widget.storage, sync: widget.sync))), cs: cs),
          _tile(icon: Icons.bug_report_outlined, title: 'Отладка',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DebugScreen())), cs: cs),

          const SizedBox(height: 16),
          _sectionTitle('УВЕДОМЛЕНИЯ', cs),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: _notifService.enabled,
                  onChanged: (v) async {
                    await _notifService.setEnabled(v);
                    setState(() {});
                  },
                  title: const Text('Напоминания о сменах'),
                  subtitle: const Text('Разрешение системы запросится автоматически'),
                ),
                if (_notifService.enabled)
                  ListTile(
                    title: const Text('Напомнить за'),
                    subtitle: Text('${_notifService.timing} минут'),
                    trailing: DropdownButton<int>(
                      value: _notifService.timing,
                      items: const [
                        DropdownMenuItem(value: 15, child: Text('15 мин')),
                        DropdownMenuItem(value: 30, child: Text('30 мин')),
                        DropdownMenuItem(value: 60, child: Text('60 мин')),
                        DropdownMenuItem(value: 120, child: Text('120 мин')),
                      ],
                      onChanged: (v) async {
                        if (v != null) {
                          await _notifService.setTiming(v);
                          setState(() {});
                        }
                      },
                    ),
                  ),
              ],
            ),
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