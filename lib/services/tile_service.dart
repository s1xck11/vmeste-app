import 'package:flutter/services.dart';
import 'debug_log_service.dart';

/// Сервис для связи с нативными плиткой и уведомлением расхода.
class TileService {
  static const MethodChannel _channel = MethodChannel('com.vmeste.app/deeplink');
  final _log = DebugLogService();

  Future<String?> getInitialAction() async {
    try {
      return await _channel.invokeMethod<String>('getInitialAction');
    } catch (e, st) {
      _log.error('Tile', 'getInitialAction FAILED', e, st);
      return null;
    }
  }

  Future<void> showNotification() async {
    try {
      await _channel.invokeMethod('showExpenseNotification');
    } catch (e, st) {
      _log.error('Tile', 'showNotification FAILED', e, st);
    }
  }

  Future<void> hideNotification() async {
    try {
      await _channel.invokeMethod('hideExpenseNotification');
    } catch (e, st) {
      _log.error('Tile', 'hideNotification FAILED', e, st);
    }
  }

  void setHandler(Future<dynamic> Function(MethodCall call) handler) {
    _channel.setMethodCallHandler(handler);
  }
}