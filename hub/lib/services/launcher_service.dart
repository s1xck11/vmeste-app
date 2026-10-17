import 'package:flutter/material.dart';
import 'package:device_policy_controller/device_policy_controller.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'debug_log_service.dart';

/// Сервис управления режимом лаунчера/киоска.
class LauncherService {
  static const String _boxName = 'vmeste_hub_data';
  static const String _keyPin = 'launcher_pin';
  static const String _keyEnabled = 'launcher_enabled';

  final _log = DebugLogService();
  late Box _box;
  final DevicePolicyController _policy = DevicePolicyController();

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox(_boxName);
    } else {
      _box = Hive.box(_boxName);
    }
  }

  bool get isEnabled => _box.get(_keyEnabled) as bool? ?? false;
  String get pin => _box.get(_keyPin) as String? ?? '';

  Future<void> setPin(String newPin) async {
    await _box.put(_keyPin, newPin);
  }

  /// Проверяет введённый PIN.
  bool checkPin(String input) {
    return input == pin;
  }

  /// Включает режим домашнего экрана (лаунчер).
  Future<bool> enableKiosk() async {
    try {
      // 1. Устанавливаем приложение как домашний экран
      final ok = await _policy.setAsLauncher(enable: true);
      _log.info('Launcher', 'setAsLauncher: $ok');

      // 2. Блокируем выход из приложения (kiosk)
      await _policy.lockApp();
      _log.info('Launcher', 'lockApp вызван');

      // 3. Не гасим экран при питании
      await _policy.setKeepScreenAwake(true);

      await _box.put(_keyEnabled, true);
      return true;
    } catch (e, st) {
      _log.error('Launcher', 'enableKiosk FAILED', e, st);
      return false;
    }
  }

  /// Выключает киоск (нужен PIN).
  Future<bool> disableKiosk() async {
    try {
      await _policy.unlockApp();
      await _policy.setAsLauncher(enable: false);
      await _policy.setKeepScreenAwake(false);
      await _box.put(_keyEnabled, false);
      _log.info('Launcher', 'киоск выключен');
      return true;
    } catch (e, st) {
      _log.error('Launcher', 'disableKiosk FAILED', e, st);
      return false;
    }
  }
}