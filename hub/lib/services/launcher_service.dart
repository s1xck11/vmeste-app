// lib/services/launcher_service.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'debug_log_service.dart';

class LauncherService {
  static const String _boxName = 'vmeste_hub_data';
  static const String _keyPin = 'launcher_pin';
  static const String _keyEnabled = 'launcher_enabled';
  static const String _keyTvMode = 'tv_mode_enabled';

  final _log = DebugLogService();
  late Box _box;

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox(_boxName);
    } else {
      _box = Hive.box(_boxName);
    }
  }

  String get pin => _box.get(_keyPin) as String? ?? '';
  Future<void> setPin(String newPin) async => _box.put(_keyPin, newPin);
  bool checkPin(String input) => input == pin;

  bool get isEnabled => _box.get(_keyEnabled) as bool? ?? false;
  Future<bool> enableKiosk() async {
    try { await _box.put(_keyEnabled, true); return true; } catch (e) { return false; }
  }
  Future<bool> disableKiosk() async {
    try { await _box.put(_keyEnabled, false); return true; } catch (e) { return false; }
  }

  bool get tvModeEnabled => _box.get(_keyTvMode) as bool? ?? false;
  Future<void> setTvMode(bool enabled) async {
    await _box.put(_keyTvMode, enabled);
    _log.info('Launcher', 'ТВ-режим: $enabled');
  }
  Future<void> toggleTvMode() async {
    await setTvMode(!tvModeEnabled);
  }
}