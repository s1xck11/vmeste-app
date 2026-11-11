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

  static const List<String> _shiftPalette = [
    '#4CAF50', '#EF5350', '#7E57C2', '#FFB74D',
    '#42A5F5', '#26C6DA', '#EC407A', '#9CCC65',
    '#FF7043', '#8D6E63', '#78909C', '#FFEE58',
  ];

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
                      Text('Профиль', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant, letterSpacing: 0.5, height: 1.2)),
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
          const SizedBox(height: 20),

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
                      Text('Сделано с любовью для Серёжи и Насти', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.3)),
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
            cs: cs
          ),
          _settingsTile(
            icon: Icons.wallpaper,
            title: 'Фон приложения',
            subtitle: _bgService.hasImage ? 'Изображение задано' : 'Стандартный фон',
            onTap: () => _showBackgroundSheet(cs),
            cs: cs
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
              padding: const EdgeInsets.only(left: 56, top: 0, bottom: 8),
              child: Row(
                children: [
                  Text('Напомнить за: ', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.2)),
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
            cs: cs
          ),
          _settingsTile(
            icon: Icons.copy,
            title: 'Код группы',
            subtitle: widget.storage.coupleCode ?? 'Не задан',
            onTap: () => _copy(widget.storage.coupleCode ?? '', 'Код'),
            cs: cs
          ),
          _settingsTile(
            icon: Icons.key,
            title: 'Мой ключ доступа',
            subtitle: widget.storage.myKey ?? 'Не задан',
            onTap: () => _copy(widget.storage.myKey ?? '', 'Ключ'),
            cs: cs
          ),
          _settingsTile(
            icon: Icons.people_outline,
            title: 'Участники группы',
            subtitle: '${widget.storage.members.length} устройств',
            onTap: () => _showMembers(cs),
            cs: cs
          ),
          _settingsTile(
            icon: Icons.sync,
            title: 'Отправить в облако',
            subtitle: 'Принудительная синхронизация',
            onTap: () {
              widget.sync.schedulePush();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Отправлено')));
            },
            cs: cs
          ),
          if (widget.sync.status != 'online')
            _settingsTile(
              icon: Icons.refresh,
              title: 'Подключиться заново',
              onTap: widget.onReconnect,
              cs: cs
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
            cs: cs
          ),
          _settingsTile(
            icon: Icons.history,
            title: 'История покупок',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PurchaseHistoryScreen(storage: widget.storage, sync: widget.sync)
            )),
            cs: cs
          ),
          _settingsTile(
            icon: Icons.folder_outlined,
            title: 'Экспорт / Импорт JSON',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => DataManagementScreen(storage: widget.storage, sync: widget.sync)
            )),
            cs: cs
          ),

          const SizedBox(height: 16),

          // 7. Прочее
          _sectionTitle('ПРОЧЕЕ', cs),
          _settingsTile(
            icon: Icons.system_update_alt,
            title: 'Проверить обновления',
            subtitle: _checkingUpdate ? 'Проверяю...' : 'Версия ${UpdateService.currentFull}',
            onTap: _checkingUpdate ? null : _checkUpdates,
            cs: cs
          ),
          _settingsTile(
            icon: Icons.bug_report_outlined,
            title: 'Экран отладки',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DebugScreen())),
            cs: cs
          ),

          const SizedBox(height: 24),

          // 8. Выход
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Отключиться от группы?'),
                    content: const Text('Локальные данные останутся на устройстве, но синхронизация с партнером прекратится.'),
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
              label: const Text('Отключиться'),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.error,
                side: BorderSide(color: cs.error),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color? iconColor,
    Widget? trailing,
    required ColorScheme cs,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cs.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (iconColor ?? cs.primary).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor ?? cs.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface, height: 1.25),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.3),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing else if (onTap != null) Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== РЕДАКТОР: ТИПЫ СМЕН ====================

  Widget _expandableShiftTypes(ColorScheme cs) {
    return _ExpandableSection(
      title: 'Типы смен',
      icon: Icons.calendar_today_outlined,
      cs: cs,
      builder: (setSt) {
        final types = List<ShiftType>.from(widget.storage.shiftTypes);

        void persist() {
          widget.storage.shiftTypes = types;
          widget.sync.schedulePush();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...List.generate(types.length, (i) {
              final t = types[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outline.withOpacity(0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _colorDotButton(
                          cs: cs,
                          color: _parseColor(t.color),
                          onTap: () async {
                            final picked = await _pickShiftColor(t.color);
                            if (picked == null) return;
                            types[i] = ShiftType(
                              id: t.id,
                              label: types[i].label,
                              hours: types[i].hours,
                              rate: types[i].rate,
                              color: picked,
                            );
                            persist();
                            setSt();
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _inputShell(
                            cs: cs,
                            child: TextFormField(
                              initialValue: t.label,
                              maxLines: 1,
                              textInputAction: TextInputAction.done,
                              textCapitalization: TextCapitalization.sentences,
                              style: TextStyle(color: cs.onSurface, fontSize: 15, fontWeight: FontWeight.w600, height: 1.2),
                              decoration: _plainDecoration(cs, hint: 'Название типа'),
                              onFieldSubmitted: (v) {
                                final name = v.trim().isEmpty ? t.label : v.trim();
                                types[i] = ShiftType(id: t.id, label: name, hours: types[i].hours, rate: types[i].rate, color: types[i].color);
                                persist();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _deleteButton(cs, () {
                          types.removeAt(i);
                          persist();
                          setSt();
                        }),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _labeledInput(
                            cs: cs,
                            caption: 'Часов',
                            child: TextFormField(
                              initialValue: _num(t.hours),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textInputAction: TextInputAction.done,
                              style: TextStyle(color: cs.onSurface, fontSize: 15, height: 1.2),
                              decoration: _plainDecoration(cs, suffix: 'ч'),
                              onFieldSubmitted: (v) {
                                types[i] = ShiftType(
                                  id: t.id,
                                  label: types[i].label,
                                  hours: double.tryParse(v.replaceAll(',', '.')) ?? types[i].hours,
                                  rate: types[i].rate,
                                  color: types[i].color,
                                );
                                persist();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _labeledInput(
                            cs: cs,
                            caption: 'Ставка',
                            child: TextFormField(
                              initialValue: _num(t.rate),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textInputAction: TextInputAction.done,
                              style: TextStyle(color: cs.onSurface, fontSize: 15, height: 1.2),
                              decoration: _plainDecoration(cs, suffix: '₽/час'),
                              onFieldSubmitted: (v) {
                                types[i] = ShiftType(
                                  id: t.id,
                                  label: types[i].label,
                                  hours: types[i].hours,
                                  rate: double.tryParse(v.replaceAll(',', '.')) ?? types[i].rate,
                                  color: types[i].color,
                                );
                                persist();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  types.add(ShiftType(
                    id: 'st_${DateTime.now().millisecondsSinceEpoch}',
                    label: 'Новая смена',
                    hours: 8,
                    rate: 0,
                    color: '#FF8FAB',
                  ));
                  persist();
                  setSt();
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Добавить тип', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        );
      },
    );
  }

  // ==================== РЕДАКТОР: ПАРТНЁРЫ ====================

  Widget _expandablePartners(ColorScheme cs) {
    return _ExpandableSection(
      title: 'Партнёры и зарплата',
      icon: Icons.people,
      cs: cs,
      builder: (setSt) {
        final partners = List<Partner>.from(widget.storage.partners);

        void persist() {
          widget.storage.partners = partners;
          widget.sync.schedulePush();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(partners.length, (i) {
            final p = partners[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outline.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _labeledInput(
                    cs: cs,
                    caption: 'Имя партнёра',
                    child: TextFormField(
                      initialValue: p.name,
                      maxLines: 1,
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 16, height: 1.2),
                      decoration: _plainDecoration(cs, hint: 'Имя'),
                      onFieldSubmitted: (v) {
                        final name = v.trim().isEmpty ? p.name : v.trim();
                        partners[i] = Partner(id: p.id, name: name, rate: partners[i].rate, payType: partners[i].payType);
                        persist();
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _labeledInput(
                          cs: cs,
                          caption: 'Ставка',
                          child: TextFormField(
                            initialValue: _num(p.rate),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textInputAction: TextInputAction.done,
                            style: TextStyle(color: cs.onSurface, fontSize: 15, height: 1.2),
                            decoration: _plainDecoration(cs, suffix: '₽'),
                            onFieldSubmitted: (v) {
                              partners[i] = Partner(
                                id: p.id,
                                name: partners[i].name,
                                rate: double.tryParse(v.replaceAll(',', '.')) ?? partners[i].rate,
                                payType: partners[i].payType,
                              );
                              persist();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _labeledInput(
                          cs: cs,
                          caption: 'Тип оплаты',
                          child: DropdownButtonFormField<String>(
                            value: p.payType,
                            isExpanded: true,
                            isDense: true,
                            icon: Icon(Icons.expand_more, size: 20, color: cs.onSurfaceVariant),
                            dropdownColor: cs.surface,
                            borderRadius: BorderRadius.circular(12),
                            style: TextStyle(color: cs.onSurface, fontSize: 15, fontWeight: FontWeight.w600, height: 1.2),
                            decoration: _plainDecoration(cs),
                            items: const [
                              DropdownMenuItem(value: 'hourly', child: Text('Почасовая', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'fixed', child: Text('Фиксированная', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'piecework', child: Text('Сдельная', overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (v) {
                              partners[i] = Partner(id: p.id, name: partners[i].name, rate: partners[i].rate, payType: v ?? 'hourly');
                              persist();
                              setSt();
                            },
                          ),
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

  // ==================== ХЕЛПЕРЫ ПОЛЕЙ ====================

  String _num(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toString();
  }

  InputDecoration _plainDecoration(ColorScheme cs, {String? suffix, String? hint}) {
    return InputDecoration(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      hintText: hint,
      hintStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.6), fontSize: 15, height: 1.2),
      suffixText: suffix,
      suffixStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w600, height: 1.2),
    );
  }

  Widget _inputShell({required ColorScheme cs, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withOpacity(0.3)),
      ),
      child: child,
    );
  }

  Widget _labeledInput({
    required ColorScheme cs,
    required String caption,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            caption,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant, letterSpacing: 0.4, height: 1.2),
          ),
        ),
        _inputShell(cs: cs, child: child),
      ],
    );
  }

  Widget _deleteButton(ColorScheme cs, VoidCallback onTap) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        icon: Icon(Icons.delete_outline, color: cs.error, size: 22),
      ),
    );
  }

  Widget _colorDotButton({
    required ColorScheme cs,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withOpacity(0.3)),
        ),
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
          ),
        ),
      ),
    );
  }

  Future<String?> _pickShiftColor(String current) {
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Цвет типа смены', style: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 280,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _shiftPalette.map((hex) {
                final sel = hex.toLowerCase() == current.toLowerCase();
                return GestureDetector(
                  onTap: () => Navigator.pop(ctx, hex),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _parseColor(hex),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: sel ? cs.onSurface : Colors.white.withOpacity(0.2),
                        width: sel ? 3 : 1,
                      ),
                    ),
                    child: sel ? Icon(Icons.check, size: 20, color: Colors.white.withOpacity(0.95)) : null,
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ],
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

  Future<void> _showBackgroundSheet(ColorScheme cs) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => Container(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outline.withOpacity(0.5), borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              Text('Фон приложения', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: cs.onSurface, height: 1.2)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () { _pickBackground(); Navigator.pop(ctx); },
                      icon: const Icon(Icons.upload, size: 20),
                      label: const Text('Загрузить', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () { _clearBackground(); Navigator.pop(ctx); },
                      icon: const Icon(Icons.clear, size: 20),
                      label: const Text('Убрать', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.error,
                        side: BorderSide(color: cs.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Степень размытия: ${_bgService.blur.toStringAsFixed(0)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface, height: 1.2)),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                ),
                child: Slider(
                  value: _bgService.blur, min: 0, max: 30,
                  onChanged: (v) async {
                    await _setBlur(v);
                    setSt(() {});
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
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
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(isMe ? Icons.phone_android : Icons.devices, size: 18, color: isMe ? cs.primary : cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${isMe ? "Это вы" : "Устройство"}: ${uid.length > 8 ? uid.substring(0, 8) : uid}…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: isMe ? cs.primary : cs.onSurface, fontWeight: isMe ? FontWeight.w600 : FontWeight.normal, height: 1.3),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  Widget _sectionTitle(String text, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant, letterSpacing: 0.8, height: 1.2)),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon, color: cs.primary, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface, fontSize: 15, height: 1.25)),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: cs.onSurfaceVariant, size: 20),
                ],
              ),
            ),
          ),
          if (_expanded)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: widget.builder(() => setState(() {})),
            ),
        ],
      ),
    );
  }
}