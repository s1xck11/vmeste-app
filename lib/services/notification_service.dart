// lib/services/notification_service.dart

import 'storage_service.dart';
import 'debug_log_service.dart';

class NotificationService {
  final StorageService storage;
  final _log = DebugLogService();
  NotificationService(this.storage);

  bool get enabled => storage.notificationsEnabled;
  int get timing => storage.notificationTiming;

  Future<void> setEnabled(bool v) async {
    storage.notificationsEnabled = v;
    _log.info('Notif', 'enabled=$v');
  }

  Future<void> setTiming(int minutes) async {
    storage.notificationTiming = minutes;
    _log.info('Notif', 'timing=$minutes');
  }

  /// Здесь будет планирование реальных уведомлений.
  /// Сейчас — заглушка.
  Future<void> scheduleAll() async {
    _log.info('Notif', 'schedule (заглушка)');
  }
}