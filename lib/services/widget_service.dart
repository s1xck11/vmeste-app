// lib/services/widget_service.dart

import 'dart:async';
import 'package:home_widget/home_widget.dart';
import '../models/shift.dart';
import '../models/shift_type.dart';
import '../models/purchase.dart';
import '../models/task.dart';
import '../models/partner.dart';
import 'storage_service.dart';
import 'debug_log_service.dart';

class WidgetService {
  static const String androidShiftsName = 'com.vmeste.vmeste_app.VmesteShiftsWidget';
  static const String androidPurchasesName = 'com.vmeste.vmeste_app.VmestePurchasesWidget';
  static const String androidTasksName = 'com.vmeste.vmeste_app.VmesteTasksWidget';
  static const String androidClockName = 'com.vmeste.vmeste_app.VmesteClockWidget';

  static const String _keyShiftsLines = 'shifts_lines';
  static const String _keyShiftsTitle = 'shifts_title';
  static const String _keyShiftsSub = 'shifts_sub';

  static const String _keyPurchasesLines = 'purchases_lines';
  static const String _keyPurchasesTitle = 'purchases_title';
  static const String _keyPurchasesSub = 'purchases_sub';

  static const String _keyTasksLines = 'tasks_lines';
  static const String _keyTasksTitle = 'tasks_title';
  static const String _keyTasksSub = 'tasks_sub';
  
  static const String _keyClockWeather = 'clock_weather';
  static const String _keyClockShifts = 'clock_shifts';

  final StorageService storage;
  final _log = DebugLogService();

  WidgetService(this.storage);

  Future<void> updateAll() async {
    try {
      await updateShifts();
      await updatePurchases();
      await updateTasks();
      await updateClock();
    } catch (e, st) {
      _log.error('Widget', 'updateAll FAILED', e, st);
    }
  }

  Future<void> updateShifts() async {
    try {
      final lines = _buildShiftLines();
      final sub = lines.isEmpty ? 'нет смен' : '';
      await HomeWidget.saveWidgetData<String>(_keyShiftsTitle, 'СМЕНЫ');
      await HomeWidget.saveWidgetData<String>(_keyShiftsLines, lines.join('\n'));
      await HomeWidget.saveWidgetData<String>(_keyShiftsSub, sub);
      await HomeWidget.updateWidget(androidName: androidShiftsName);
    } catch (e, st) {
      _log.error('Widget', 'updateShifts FAILED', e, st);
    }
  }

  List<String> _buildShiftLines() {
    final now = DateTime.now();
    final todayKey = _dateKey(now);
    final all = List<Shift>.from(storage.shifts)..sort((a, b) => a.date.compareTo(b.date));
    final types = storage.shiftTypes;
    final partners = storage.partners;
    final future = <Shift>[];
    for (final s in all) {
      if (s.date.compareTo(todayKey) < 0) continue;
      future.add(s);
    }

    final result = <String>[];
    for (final s in future.take(4)) {
      final t = types.firstWhere(
        (x) => x.id == s.type,
        orElse: () => ShiftType(id: s.type, label: 'Смена', hours: 0, color: '#9E9E9E'),
      );
      final p = partners.firstWhere((x) => x.id == s.partner, orElse: () => Partner(id: s.partner, name: ''));
      final day = _formatDay(s.date, now);
      final time = '${s.startTime}–${s.endTime}';
      final who = p.name.isNotEmpty ? ' · ${p.name}' : '';
      result.add('$time · $day$who');
    }
    return result;
  }

  Future<void> updatePurchases() async {
    try {
      final lines = _buildPurchaseLines();
      final sub = lines.isEmpty ? 'всё куплено' : '';
      await HomeWidget.saveWidgetData<String>(_keyPurchasesTitle, 'ПОКУПКИ');
      await HomeWidget.saveWidgetData<String>(_keyPurchasesLines, lines.join('\n'));
      await HomeWidget.saveWidgetData<String>(_keyPurchasesSub, sub);
      await HomeWidget.updateWidget(androidName: androidPurchasesName);
    } catch (e, st) {
      _log.error('Widget', 'updatePurchases FAILED', e, st);
    }
  }

  List<String> _buildPurchaseLines() {
    final all = storage.purchases.where((p) => !p.done && !p.missing).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final result = <String>[];
    for (final p in all.take(4)) {
      final qty = p.qty > 1 ? '${_trimNum(p.qty)} ${p.unit} · ' : '';
      result.add('$qty${p.text}');
    }
    return result;
  }

  Future<void> updateTasks() async {
    try {
      final lines = _buildTaskLines();
      final sub = lines.isEmpty ? 'всё сделано' : '';
      await HomeWidget.saveWidgetData<String>(_keyTasksTitle, 'ЗАДАЧИ');
      await HomeWidget.saveWidgetData<String>(_keyTasksLines, lines.join('\n'));
      await HomeWidget.saveWidgetData<String>(_keyTasksSub, sub);
      await HomeWidget.updateWidget(androidName: androidTasksName);
    } catch (e, st) {
      _log.error('Widget', 'updateTasks FAILED', e, st);
    }
  }

  List<String> _buildTaskLines() {
    final all = storage.tasks.where((t) => !t.done && !t.archived).toList()
      ..sort((a, b) {
        int rank(String p) {
          if (p == 'high') return 0;
          if (p == 'med') return 1;
          return 2;
        }
        final ra = rank(a.priority), rb = rank(b.priority);
        if (ra != rb) return ra.compareTo(rb);
        return a.order.compareTo(b.order);
      });

    final result = <String>[];
    for (final t in all.take(4)) {
      final mark = t.priority == 'high' ? '🔴 ' : '';
      result.add('$mark${t.text}');
    }
    return result;
  }

  Future<void> updateClock() async {
    try {
      // 1. Погода (если есть)
      String weather = '--°';
      // В идеале тут нужно дернуть WeatherService, но чтобы не плодить зависимости, 
      // предположим, что мы просто передаем заглушку или берем из кэша, если он есть.
      // Для простоты оставим так, погоду обновим отдельно, если нужно.
      await HomeWidget.saveWidgetData<String>(_keyClockWeather, weather);

      // 2. Смены на сегодня
      final now = DateTime.now();
      final todayKey = _dateKey(now);
      final todayShifts = storage.shifts.where((s) => s.date == todayKey).toList();
      final partners = storage.partners;
      
      final shiftLines = <String>[];
      for (final s in todayShifts) {
        final p = partners.firstWhere((x) => x.id == s.partner, orElse: () => Partner(id: s.partner, name: ''));
        shiftLines.add('${p.name}: ${s.startTime}–${s.endTime}');
      }
      
      await HomeWidget.saveWidgetData<String>(_keyClockShifts, shiftLines.isEmpty ? 'Смен нет' : shiftLines.join('\n'));
      
      // Обновляем нативный виджет
      await HomeWidget.updateWidget(androidName: androidClockName);
    } catch (e, st) {
      _log.error('Widget', 'updateClock FAILED', e, st);
    }
  }

  String _dateKey(DateTime d) {
    final m = d.month < 10 ? '0${d.month}' : '${d.month}';
    final day = d.day < 10 ? '0${d.day}' : '${d.day}';
    return '${d.year}-$m-$day';
  }

  String _formatDay(String dateKey, DateTime now) {
    final parsed = _tryParseDate(dateKey);
    if (parsed == null) return dateKey;
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(parsed.year, parsed.month, parsed.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'сегодня';
    if (diff == 1) return 'завтра';
    return '${parsed.day}.${parsed.month}';
  }

  DateTime? _tryParseDate(String key) {
    try {
      final parts = key.split('-');
      if (parts.length != 3) return null;
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    } catch (_) {
      return null;
    }
  }

  String _trimNum(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}