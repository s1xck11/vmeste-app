// lib/services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/shift.dart';
import '../models/shift_type.dart';
import '../models/partner.dart';
import 'storage_service.dart';
import 'debug_log_service.dart';

class NotificationService {
  final StorageService storage;
  final _log = DebugLogService();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _tzInitialized = false;

  NotificationService(this.storage);

  bool get enabled => storage.notificationsEnabled;
  int get timing => storage.notificationTiming;

  void _initTimezone() {
    if (_tzInitialized) return;
    tz_data.initializeTimeZones();
    // Устанавливаем локальную таймзону по offset
    try {
      final offset = DateTime.now().timeZoneOffset;
      final name = offset.inHours >= 0
          ? 'Etc/GMT-${offset.inHours}'
          : 'Etc/GMT+${offset.inHours.abs()}';
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // если не нашлось — оставляем UTC, для локальных смен работает
    }
    _tzInitialized = true;
  }

  Future<void> init() async {
    _initTimezone();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    try {
      await _plugin.initialize(initSettings);
      _log.info('Notif', 'инициализировано');
    } catch (e, st) {
      _log.error('Notif', 'init FAILED', e, st);
    }
  }

  Future<bool> requestPermission() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    } catch (e, st) {
      _log.error('Notif', 'permission FAILED', e, st);
      return false;
    }
  }

  Future<void> setEnabled(bool v) async {
    storage.notificationsEnabled = v;
    _log.info('Notif', 'enabled=$v');
    if (v) {
      await requestPermission();
      await scheduleAll();
    } else {
      await _plugin.cancelAll();
    }
  }

  Future<void> setTiming(int minutes) async {
    storage.notificationTiming = minutes;
    _log.info('Notif', 'timing=$minutes');
    if (enabled) await scheduleAll();
  }

  /// Планирует уведомления для всех смен на ближайшие 30 дней.
  Future<void> scheduleAll() async {
    if (!enabled) return;
    _initTimezone();
    await _plugin.cancelAll();

    final now = DateTime.now();
    final limit = now.add(const Duration(days: 30));
    final timing = this.timing;

    final shifts = storage.shifts;
    final partners = storage.partners;
    final types = storage.shiftTypes;

    int scheduled = 0;
    for (final s in shifts) {
      try {
        final parts = s.date.split('-');
        if (parts.length != 3) continue;
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final d = int.parse(parts[2]);

        final startParts = s.startTime.split(':');
        if (startParts.length != 2) continue;
        final h = int.parse(startParts[0]);
        final min = int.parse(startParts[1]);

        final startTime = DateTime(y, m, d, h, min);
        final notifyTime = startTime.subtract(Duration(minutes: timing));

        if (notifyTime.isBefore(now) || notifyTime.isAfter(limit)) continue;

        final p = partners.firstWhere(
          (x) => x.id == s.partner,
          orElse: () => Partner(id: s.partner, name: '?', rate: 0, payType: 'hourly'),
        );
        final t = types.firstWhere(
          (x) => x.id == s.type,
          orElse: () => ShiftType(id: s.type, label: 'Смена', hours: 0, color: '#9E9E9E'),
        );

        final body = '${p.name} — ${t.label} в ${s.startTime}';

        await _plugin.zonedSchedule(
          s.id,
          '⏰ Смена через $timing мин',
          body,
          tz.TZDateTime.from(notifyTime, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'shifts_channel',
              'Смены',
              channelDescription: 'Напоминания о сменах',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        scheduled++;
      } catch (e) {
        _log.warn('Notif', 'пропущена смена ${s.id}: $e');
      }
    }
    _log.info('Notif', 'запланировано $scheduled уведомлений');
  }
}