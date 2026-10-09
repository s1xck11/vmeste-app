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

/// Сервис, который готовит данные для трёх Android-виджетов
/// и вызывает их обновление.
///
/// Виджеты:
///  - Вместе.Shifts    — ближайшие 4 смены
///  - Вместе.Purchases — ближайшие 4 непокупленные покупки
///  - Вместе.Tasks     — ближайшие 4 незавершённые задачи
///
/// Настройка в AndroidManifest:
///  <receiver android:name=".VmesteWidgetProvider">
///    ...
///  </receiver>
///
/// Соглашение с Kotlin:
///  - ключ "shifts_lines"  — 4 строки, разделитель "\n"
///  - ключ "shifts_title"  — "СМЕНЫ"
///  - ключ "purchases_lines" / "purchases_title"
///  - ключ "tasks_lines" / "tasks_title"
///  - ключ "shifts_sub" — мелкий текст (например "нет смен")
///  - аналогично для purchases / tasks
class WidgetService {
  static const String androidShiftsName =
      'com.vmeste.vmeste_app.VmesteShiftsWidget';
  static const String androidPurchasesName =
      'com.vmeste.vmeste_app.VmestePurchasesWidget';
  static const String androidTasksName =
      'com.vmeste.vmeste_app.VmesteTasksWidget';

  static const String _keyShiftsLines = 'shifts_lines';
  static const String _keyShiftsTitle = 'shifts_title';
  static const String _keyShiftsSub = 'shifts_sub';

  static const String _keyPurchasesLines = 'purchases_lines';
  static const String _keyPurchasesTitle = 'purchases_title';
  static const String _keyPurchasesSub = 'purchases_sub';

  static const String _keyTasksLines = 'tasks_lines';
  static const String _keyTasksTitle = 'tasks_title';
  static const String _keyTasksSub = 'tasks_sub';

  final StorageService storage;
  final _log = DebugLogService();

  WidgetService(this.storage);

  /// Вызывается из SyncService._notifyAll() после каждого pull/push.
  /// Обновляет все три виджета. Ошибки глушим — не должны ломать приложение.
  Future<void> updateAll() async {
    try {
      await updateShifts();
      await updatePurchases();
      await updateTasks();
    } catch (e, st) {
      _log.error('Widget', 'updateAll FAILED', e, st);
    }
  }

  // ============================================================
  // СМЕНЫ
  // ============================================================

  Future<void> updateShifts() async {
    try {
      final lines = _buildShiftLines();
      final sub = lines.isEmpty ? 'нет смен' : '';
      await HomeWidget.saveWidgetData<String>(_keyShiftsTitle, 'СМЕНЫ');
      await HomeWidget.saveWidgetData<String>(_keyShiftsLines, lines.join('\n'));
      await HomeWidget.saveWidgetData<String>(_keyShiftsSub, sub);
      await HomeWidget.updateWidget(androidName: androidShiftsName);
      _log.info('Widget', 'shifts: ${lines.length} строк');
    } catch (e, st) {
      _log.error('Widget', 'updateShifts FAILED', e, st);
    }
  }

  List<String> _buildShiftLines() {
    final now = DateTime.now();
    final todayKey = _dateKey(now);
    final all = List<Shift>.from(storage.shifts)
      ..sort((a, b) => a.date.compareTo(b.date));

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
        orElse: () => ShiftType(
          id: s.type,
          label: 'Смена',
          hours: 0,
          color: '#9E9E9E',
        ),
      );
      final p = partners.firstWhere(
        (x) => x.id == s.partner,
        orElse: () => Partner(id: s.partner, name: ''),
      );
      final day = _formatDay(s.date, now);
      final time = '${s.startTime}–${s.endTime}';
      final who = p.name.isNotEmpty ? ' · ${p.name}' : '';
      result.add('$time · $day$who · ${t.label}');
    }
    return result;
  }

  // ============================================================
  // ПОКУПКИ
  // ============================================================

  Future<void> updatePurchases() async {
    try {
      final lines = _buildPurchaseLines();
      final sub = lines.isEmpty ? 'всё куплено' : '';
      await HomeWidget.saveWidgetData<String>(_keyPurchasesTitle, 'ПОКУПКИ');
      await HomeWidget.saveWidgetData<String>(
          _keyPurchasesLines, lines.join('\n'));
      await HomeWidget.saveWidgetData<String>(_keyPurchasesSub, sub);
      await HomeWidget.updateWidget(androidName: androidPurchasesName);
      _log.info('Widget', 'purchases: ${lines.length} строк');
    } catch (e, st) {
      _log.error('Widget', 'updatePurchases FAILED', e, st);
    }
  }

  List<String> _buildPurchaseLines() {
    final all = storage.purchases
        .where((p) => !p.done && !p.missing)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final result = <String>[];
    for (final p in all.take(4)) {
      final qty = p.qty > 1 ? '${_trimNum(p.qty)} ${p.unit} · ' : '';
      result.add('$qty${p.text}');
    }
    return result;
  }

  // ============================================================
  // ЗАДАЧИ
  // ============================================================

  Future<void> updateTasks() async {
    try {
      final lines = _buildTaskLines();
      final sub = lines.isEmpty ? 'всё сделано' : '';
      await HomeWidget.saveWidgetData<String>(_keyTasksTitle, 'ЗАДАЧИ');
      await HomeWidget.saveWidgetData<String>(_keyTasksLines, lines.join('\n'));
      await HomeWidget.saveWidgetData<String>(_keyTasksSub, sub);
      await HomeWidget.updateWidget(androidName: androidTasksName);
      _log.info('Widget', 'tasks: ${lines.length} строк');
    } catch (e, st) {
      _log.error('Widget', 'updateTasks FAILED', e, st);
    }
  }

  List<String> _buildTaskLines() {
    final all = storage.tasks
        .where((t) => !t.done && !t.archived)
        .toList()
      ..sort((a, b) {
        // high → med → low, потом по deadline, потом по order
        int rank(String p) {
          if (p == 'high') return 0;
          if (p == 'med') return 1;
          return 2;
        }
        final ra = rank(a.priority), rb = rank(b.priority);
        if (ra != rb) return ra.compareTo(rb);
        if (a.deadline.isNotEmpty && b.deadline.isNotEmpty) {
          return a.deadline.compareTo(b.deadline);
        }
        if (a.deadline.isNotEmpty) return -1;
        if (b.deadline.isNotEmpty) return 1;
        return a.order.compareTo(b.order);
      });

    final result = <String>[];
    for (final t in all.take(4)) {
      final mark = t.priority == 'high' ? '🔴 ' : '';
      final dl = t.deadline.isNotEmpty
          ? ' · до ${_shortDate(t.deadline)}'
          : '';
      result.add('$mark${t.text}$dl');
    }
    return result;
  }

  // ============================================================
  // ХЕЛПЕРЫ
  // ============================================================

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
    if (diff == 2) return 'послезавтра';
    return _shortDate(dateKey);
  }

  String _shortDate(String dateKey) {
    final parsed = _tryParseDate(dateKey);
    if (parsed == null) return dateKey;
    const months = [
      'янв', 'фев', 'мар', 'апр', 'май', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
    ];
    final m = months[parsed.month - 1];
    final day = parsed.day.toString().padLeft(2, '0');
    return '$day $m';
  }

  DateTime? _tryParseDate(String key) {
    try {
      final parts = key.split('-');
      if (parts.length != 3) return null;
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }

  String _trimNum(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}