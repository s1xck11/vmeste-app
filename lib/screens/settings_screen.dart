// lib/screens/settings_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/purchase_category.dart';
import '../models/task_category.dart';
import '../models/shift_type.dart';
import '../models/partner.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/theme_service.dart';
import '../services/background_service.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
import '../services/tile_service.dart';
import 'avatar_picker_screen.dart';
import 'data_management_screen.dart';
import 'debug_screen.dart';
import 'courier_import_screen.dart';
import 'theme_picker_screen.dart';
import 'purchase_history_screen.dart';
import 'banks_editor_screen.dart';

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
  final _tileService = TileService();
  bool _checkingUpdate = false;
  bool _quickExpenseEnabled = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.storage.myName);
    _bgService = BackgroundService.instance;
    _notifService = NotificationService(widget.storage);
    _notifService.init();

    final box = Hive.box('vmeste_data');
    _quickExpenseEnabled = box.get('quick_expense_notif_enabled') as bool? ?? false;
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Файл больше 8 МБ')));
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

  Future<void> _toggleQuickExpense(bool value) async {
    setState(() => _quickExpenseEnabled = value);
    final box = Hive.box('vmeste_data');
    await box.put('quick_expense_notif_enabled', value);
    if (value) {
      await _tileService.showNotification();
    } else {
      await _tileService.hideNotification();
    }
  }

  Future<void> _checkUpdates() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      final info = await _updateService.checkForUpdate(force: true);
      if (!mounted) return;
      if (info == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Обновлений нет')));
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
        content: Text(info.body.isNotEmpty ? info.body : 'Новая версия'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Позже')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateService.downloadApk(info).then((f) {
                if (f != null) _updateService.installApk(f);
              });
            },
            child: const Text('Скачать'),
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
      default: return 'Офлайн';
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

          _sectionTitle('ПРОФИЛЬ', cs),
          _tile(icon: Icons.person_outline, title: 'Моё имя',
              subtitle: widget.storage.myName.isEmpty ? 'Не задано' : widget.storage.myName,
              onTap: _editName, cs: cs),
          _tile(icon: Icons.palette_outlined, title: 'Оформление', subtitle: 'Тема и палитра',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ThemePickerScreen(themeService: widget.themeService))), cs: cs),
          _tile(icon: Icons.wallpaper, title: 'Фон приложения',
              subtitle: _bgService.hasImage ? 'Задан' : 'Не задан',
              onTap: () => _showBackgroundDialog(cs), cs: cs),

          const SizedBox(height: 16),

          _sectionTitle('СВЯЗЬ', cs),
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
          _tile(icon: Icons.key, title: 'Мой ключ',
              subtitle: widget.storage.myKey ?? '—',
              onTap: () => _copy(widget.storage.myKey ?? '', 'Ключ'), cs: cs),

          const SizedBox(height: 16),

          _sectionTitle('НАСТРОЙКИ', cs),
          _expandableShiftTypes(cs),
          _expandablePartners(cs),
          _tile(
            icon: Icons.account_balance_outlined,
            title: 'Банки',
            subtitle: 'Управление банками и начальным балансом',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => BanksEditorScreen(storage: widget.storage, sync: widget.sync),
            )),
            cs: cs,
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                SwitchListTile(
                  value: _quickExpenseEnabled,
                  onChanged: _toggleQuickExpense,
                  secondary: Icon(Icons.receipt_long_outlined, color: cs.primary, size: 22),
                  title: const Text('Кнопка «Добавить расход»'),
                  subtitle: Text(_quickExpenseEnabled
                      ? 'Показывается в шторке уведомлений'
                      : 'Отключено'),
                ),
              ],
            ),
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                SwitchListTile(
                  value: _notifService.enabled,
                  onChanged: (v) async {
                    await _notifService.setEnabled(v);
                    setState(() {});
                  },
                  secondary: Icon(Icons.notifications_outlined, color: cs.primary, size: 22),
                  title: const Text('Уведомления о сменах'),
                  subtitle: Text(_notifService.enabled
                      ? 'За ${_notifService.timing} мин до смены'
                      : 'Выключены'),
                ),
                if (_notifService.enabled)
                  ListTile(
                    title: const Text('Напомнить за'),
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

          const SizedBox(height: 16),

          _sectionTitle('ДАННЫЕ', cs),
          _tile(icon: Icons.download, title: 'Импорт из Курьера', subtitle: 'Вставить JSON',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CourierImportScreen(storage: widget.storage, sync: widget.sync))), cs: cs),
          _tile(icon: Icons.history, title: 'История покупок',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PurchaseHistoryScreen(storage: widget.storage, sync: widget.sync))), cs: cs),
          _tile(icon: Icons.folder_outlined, title: 'Экспорт / Импорт JSON',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => DataManagementScreen(storage: widget.storage, sync: widget.sync))), cs: cs),

          const SizedBox(height: 16),

          _sectionTitle('ПРОЧЕЕ', cs),
          _tile(icon: Icons.system_update_alt, title: 'Проверить обновления',
              subtitle: _checkingUpdate ? 'Проверяю...' : 'Версия ${UpdateService.currentFull}',
              onTap: _checkingUpdate ? null : _checkUpdates, cs: cs),
          _tile(icon: Icons.bug_report_outlined, title: 'Отладка',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DebugScreen())), cs: cs),

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

  Widget _expandableShiftTypes(ColorScheme cs) {
    return _ExpandableSection(
      title: 'Типы смен',
      icon: Icons.calendar_today_outlined,
      cs: cs,
      builder: (setSt) {
        final types = List<ShiftType>.from(widget.storage.shiftTypes);
        return Column(
          children: [
            ...List.generate(types.length, (i) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: cs.surfaceVariant, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(color: _parseColor(types[i].color), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: types[i].label,
                      style: TextStyle(color: cs.onSurface),
                      decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                      onFieldSubmitted: (v) {
                        types[i] = ShiftType(id: types[i].id, label: v, hours: types[i].hours, color: types[i].color);
                        widget.storage.shiftTypes = types;
                        widget.sync.schedulePush();
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: cs.error, size: 20),
                    onPressed: () {
                      types.removeAt(i);
                      widget.storage.shiftTypes = types;
                      widget.sync.schedulePush();
                      setSt();
                    },
                  ),
                ],
              ),
            )),
            TextButton.icon(
              onPressed: () {
                types.add(ShiftType(id: 'st_${DateTime.now().millisecondsSinceEpoch}', label: 'Новый', hours: 8, color: '#FF8FAB'));
                widget.storage.shiftTypes = types;
                widget.sync.schedulePush();
                setSt();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Добавить'),
            ),
          ],
        );
      },
    );
  }

  Widget _expandablePartners(ColorScheme cs) {
    return _ExpandableSection(
      title: 'Партнёры и зарплата',
      icon: Icons.people,
      cs: cs,
      builder: (setSt) {
        final partners = List<Partner>.from(widget.storage.partners);
        return Column(
          children: List.generate(partners.length, (i) {
            final p = partners[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cs.surfaceVariant, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    initialValue: p.name,
                    style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Имя партнёра',
                      labelStyle: TextStyle(color: cs.onSurfaceVariant),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onFieldSubmitted: (v) {
                      partners[i] = Partner(id: p.id, name: v, rate: p.rate, payType: p.payType);
                      widget.storage.partners = partners;
                      widget.sync.schedulePush();
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: p.rate.toStringAsFixed(0),
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: cs.onSurface),
                          decoration: InputDecoration(
                            labelText: 'Ставка',
                            suffixText: '₽',
                            labelStyle: TextStyle(color: cs.onSurfaceVariant),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onFieldSubmitted: (v) {
                            partners[i] = Partner(id: p.id, name: p.name, rate: double.tryParse(v) ?? 0, payType: p.payType);
                            widget.storage.partners = partners;
                            widget.sync.schedulePush();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: p.payType,
                          decoration: const InputDecoration(labelText: 'Тип', border: OutlineInputBorder(), isDense: true),
                          items: const [
                            DropdownMenuItem(value: 'hourly', child: Text('Почасовая')),
                            DropdownMenuItem(value: 'fixed', child: Text('Фиксированная')),
                            DropdownMenuItem(value: 'piecework', child: Text('Сдельная')),
                          ],
                          onChanged: (v) {
                            partners[i] = Partner(id: p.id, name: p.name, rate: p.rate, payType: v ?? 'hourly');
                            widget.storage.partners = partners;
                            widget.sync.schedulePush();
                            setSt();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  Color _parseColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return const Color(0xFF9E9E9E);
    }
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

class _ExpandableSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final ColorScheme cs;
  final Widget Function(VoidCallback) builder;

  const _ExpandableSection({
    required this.title,
    required this.icon,
    required this.cs,
    required this.builder,
  });

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            leading: Icon(widget.icon, color: cs.primary, size: 22),
            title: Text(widget.title, style: TextStyle(fontWeight: FontWeight.w500, color: cs.onSurface)),
            trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: cs.onSurfaceVariant),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: widget.builder(() => setState(() {})),
            ),
        ],
      ),
    );
  }
}