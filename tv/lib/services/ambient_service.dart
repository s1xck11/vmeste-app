// tv/lib/services/ambient_service.dart
//
// Амбиент-режим: после простоя лаунчер гаснет в живые обои с часами,
// погодой и ближайшей сменой. Любой ввод возвращает обратно.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../main.dart' show navigatorKey;
import 'embed_service.dart';
import 'input_service.dart';
import 'osk_service.dart';
import 'sound_service.dart';

class AmbientService extends ChangeNotifier {
  AmbientService._();
  static final AmbientService instance = AmbientService._();

  bool enabled = true;
  int minutes = 5;
  bool showWeather = true;
  bool particles = true;

  final ValueNotifier<bool> active = ValueNotifier(false);
  Timer? _idle;

  Future<void> init() async {
    final box = Hive.box('vmeste_tv_prefs');
    enabled = box.get('amb_on', defaultValue: true) as bool;
    minutes = (box.get('amb_min', defaultValue: 5) as num).toInt();
    showWeather = box.get('amb_weather', defaultValue: true) as bool;
    particles = box.get('amb_particles', defaultValue: true) as bool;
    _restart();
    notifyListeners();
  }

  bool get _allowed {
    final nav = navigatorKey.currentState;
    if (nav == null || nav.canPop()) return false;
    if (OskService.instance.visible) return false;
    if (InputService.instance.pointerMode.value) return false;
    if (EmbedService.instance.active.value) return false;
    return true;
  }

  void _restart() {
    _idle?.cancel();
    if (!enabled) return;
    _idle = Timer(Duration(minutes: minutes), () {
      if (!_allowed) {
        _restart();
        return;
      }
      active.value = true;
      SoundService.instance.open();
      notifyListeners();
    });
  }

  /// Любой ввод: будим амбиент или сбрасываем таймер простоя.
  void bump() {
    if (active.value) {
      exit();
    } else {
      _restart();
    }
  }

  void exit() {
    if (!active.value) return;
    active.value = false;
    SoundService.instance.move();
    _restart();
    notifyListeners();
  }

  Future<void> setEnabled(bool v) async {
    enabled = v;
    await Hive.box('vmeste_tv_prefs').put('amb_on', v);
    if (!v) exit();
    _restart();
    notifyListeners();
  }

  Future<void> setMinutes(int v) async {
    minutes = v.clamp(1, 60);
    await Hive.box('vmeste_tv_prefs').put('amb_min', minutes);
    _restart();
    notifyListeners();
  }

  Future<void> setShowWeather(bool v) async {
    showWeather = v;
    await Hive.box('vmeste_tv_prefs').put('amb_weather', v);
    notifyListeners();
  }

  Future<void> setParticles(bool v) async {
    particles = v;
    await Hive.box('vmeste_tv_prefs').put('amb_particles', v);
    notifyListeners();
  }
}
