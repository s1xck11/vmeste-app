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
import '../services/weather_service.dart';
import '../services/widget_service.dart';
import '../widgets/update_dialog.dart';
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
  bool _refreshingWeather = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.storage.myName);
    _bgService = BackgroundService.instance;
    _notifService = NotificationService(widget.storage);
    _notifService.init();

    final box = Hive.box('vmeste_data');
    _quickExpenseEnabled = box.get('quick_expense_notif_enabled') as bool? ?? false;

    UpdateService.cleanupOldApks();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _copy(String text, String label) {
    if (text.isEmpty) return;
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
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
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

  // ============ ПОГОДА ============
  Future<void> _refreshWeather({bool force = true}) async {
    if (_refreshingWeather) return;
    setState(() => _refreshingWeather = true);
    try {
      final wx = WeatherService(widget.storage);
      final ok = await wx.refresh(force: force);
      if (!mounted) return;
      if (ok) {
        await WidgetService(widget.storage).updateAll();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Погода обновлена: ${widget.storage.cachedWeatherTemp} ${widget.storage.cachedWeatherCond}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось получить погоду. Проверь город или разрешение на геолокацию.')),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshingWeather = false);
    }
  }

  Future<void> _editCity() async {
    final ctrl = TextEditingController(text: widget.storage.weatherCity);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Город для погоды'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Например: Москва'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Сохранить')),
        ],
      ),
    );
    if (result != null) {
      widget.storage.weatherCity = result;
      setState(() {});
      if (result.isNotEmpty && !widget.storage.weatherAutoGeo) {
        await _refreshWeather();
      }
    }
  }

  Future<void> _toggleAutoGeo(bool v) async {
    widget.storage.weatherAutoGeo = v;
    setState(() {});
    if (v) await _refreshWeather();
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
    UpdateDialog.show(context, info, _updateService);
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
          // 1. Профиль
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary.withOpacity(0.1), cs.surfaceVariant],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cs.outline.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: cs.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.primary, width: 2),
                      boxShadow: [BoxShadow(color: cs.primary.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: Center(child: Text(widget.storage.myAvatar, style: const TextStyle(fontSize: 32, height: 1.0))),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Профиль', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: _editName,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.storage.myName.isEmpty ? 'Задать имя' : widget.storage.myName,
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface, height: 1.2),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(Icons.edit_outlined, size: 18, color: cs.primary),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. О приложении
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary.withOpacity(0.15), cs.surfaceVariant],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Text('🐉', style: TextStyle(fontSize: 28, height: 1.0)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Сяо Чэн 小程', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cs.primary, height: 1.2)),
                      const SizedBox(height: 2),
                      Text('Сделано с любовью для Серёжи и Насти',
                          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.3),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. Основные настройки
          _sectionTitle('ОСНОВНЫЕ', cs),
          _settingsTile(
            icon: Icons.palette_outlined,
            title: 'Оформление',
            subtitle: 'Тема и цветовая палитра',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ThemePickerScreen(themeService: widget.themeService)
            )),
            cs: cs,
          ),
          _settingsTile(
            icon: Icons.wallpaper,
            title: 'Фон приложения',
            subtitle: _bgService.hasImage ? 'Изображение задано' : 'Стандартный фон',
            onTap: () => _showBackgroundSheet(cs),
            cs: cs,
          ),
          _settingsTile(
            icon: Icons.receipt_long_outlined,
            title: 'Кнопка «Добавить расход»',
            subtitle: _quickExpenseEnabled ? 'Показывается в шторке уведомлений' : 'Отключено',
            trailing: Switch(
              value: _quickExpenseEnabled,
              onChanged: _toggleQuickExpense,
            ),
            cs: cs,
          ),
          _settingsTile(
            icon: Icons.notifications_outlined,
            title: 'Уведомления о сменах',
            subtitle: _notifService.enabled ? 'За ${_notifService.timing} мин до смены' : 'Выключены',
            trailing: Switch(
              value: _notifService.enabled,
              onChanged: (v) async {
                await _notifService.setEnabled(v);
                setState(() {});
              },
            ),
            cs: cs,
          ),
          if (_notifService.enabled)
            Padding(
              padding: const EdgeInsets.only(left: 66, top: 0, bottom: 8),
              child: Row(
                children: [
                  Text('Напомнить за: ', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                  DropdownButton<int>(
                    value: _notifService.timing,
                    underline: const SizedBox(),
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
                ],
              ),
            ),

          const SizedBox(height: 16),

          // 4. Город и погода
          _sectionTitle('ГОРОД И ПОГОДА', cs),
          _settingsTile(
            icon: Icons.location_city_outlined,
            title: 'Город',
            subtitle: widget.storage.weatherAutoGeo
                ? 'Автоопределение по геолокации'
                : (widget.storage.weatherCity.isEmpty ? 'Не задан' : widget.storage.weatherCity),
            onTap: widget.storage.weatherAutoGeo ? null : _editCity,
            cs: cs,
          ),
          _settingsTile(
            icon: Icons.my_location,
            title: 'Определять автоматически',
            subtitle: 'Запрашивать геолокацию для погоды',
            trailing: Switch(
              value: widget.storage.weatherAutoGeo,
              onChanged: _toggleAutoGeo,
            ),
            cs: cs,
          ),
          _settingsTile(
            icon: _refreshingWeather ? Icons.hourglass_top : Icons.wb_sunny_outlined,
            title: 'Обновить погоду',
            subtitle: _refreshingWeather
                ? 'Обновление...'
                : '${widget.storage.cachedWeatherTemp} ${widget.storage.cachedWeatherCond}'.trim(),
            onTap: _refreshingWeather ? null : () => _refreshWeather(),
            cs: cs,
          ),

          const SizedBox(height: 16),

          // 5. Связь и синхронизация
          _sectionTitle('СВЯЗЬ', cs),
          _settingsTile(
            icon: Icons.circle,
            iconColor: _syncColor(),
            title: 'Статус синхронизации',
            subtitle: _syncText(),
            cs: cs,
          ),
          _settingsTile(
            icon: Icons.copy,
            title: 'Код группы',
            subtitle: widget.storage.coupleCode ?? 'Не задан',
            onTap: () => _copy(widget.storage.coupleCode ?? '', 'Код'),
            cs: cs,
          ),
          _settingsTile(
            icon: Icons.key,
            title: 'Мой ключ доступа',
            subtitle: widget.storage.myKey ?? 'Не задан',
            onTap: () => _copy(widget.storage.myKey ?? '', 'Ключ'),
            cs: cs,
          ),
          _settingsTile(
            icon: Icons.people_outline,
            title: 'Участники группы',
            subtitle: '${widget.storage.members.length} устройств',
            onTap: () => _showMembers(cs),
            cs: cs,
          ),
          _settingsTile(
            icon: Icons.sync,
            title: 'Отправить в облако',
            subtitle: 'Принудительная синхронизация',
            onTap: () {
              widget.sync.schedulePush();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Отправлено')));
            },
            cs: cs,
          ),
          if (widget.sync.status != 'online')
            _settingsTile(
              icon: Icons.refresh,
              title: 'Подключиться заново',
              onTap: widget.onReconnect,
              cs: cs,
            ),

          const SizedBox(height: 16),

          // 6. Данные и редакторы
          _sectionTitle('ДАННЫЕ И НАСТРОЙКИ', cs),
          _expandableShiftTypes(cs),
          _expandablePartners(cs),
          _settingsTile(
            icon: Icons.account_balance_outlined,
            title: 'Банки',
            subtitle: 'Управление счетами и балансом',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => BanksEditorScreen(storage: widget.storage, sync: widget.sync),
            )),
            cs: cs,
          ),
          _settingsTile(
            icon: Icons.download,
            title: 'Импорт из Курьера',
            subtitle: 'Вставить JSON данные',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CourierImportScreen(storage: widget.storage, sync: widget.sync)
            )),
            cs: cs,
          ),
          _settingsTile(
            icon: Icons.history,
            title: 'История покупок',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PurchaseHistoryScreen(storage: widget.storage, sync: widget.sync)
            )),
            cs: cs,
          ),
          _settingsTile(
            icon: Icons.folder_outlined,
            title: 'Экспорт / Импорт JSON',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => DataManagementScreen(storage: widget.storage, sync: widget.sync)
            )),
            cs: cs,
          ),

          const SizedBox(height: 16),

          // 7. Прочее
          _sectionTitle('ПРОЧЕЕ', cs),
          _settingsTile(
            icon: Icons.system_update_alt,
            title: 'Проверить обновления',
            subtitle: _checkingUpdate ? 'Проверяю...' : 'Версия ${UpdateService.currentFull}',
            onTap: _checkingUpdate ? null : _checkUpdates,
            cs: cs,
          ),
          _settingsTile(
            icon: Icons.bug_report_outlined,
            title: 'Экран отладки',
            onTap: () => Navigator.of(context).push(MaterialPageRoute