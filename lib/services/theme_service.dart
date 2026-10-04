// lib/services/theme_service.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme_config.dart';

class ThemeService {
  static const String _boxName = 'vmeste_data';
  static const String _keyPalette = 'theme_palette';
  static const String _keyBrightness = 'theme_brightness';

  late Box _box;

  /// Текущий конфиг темы. Слушаем через ValueListenableBuilder.
  final ValueNotifier<AppThemeConfig> notifier = ValueNotifier(
    AppThemeConfig(
      palette: AppColors.defaultPalette,
      brightness: AppColors.defaultBrightness,
    ),
  );

  AppThemeConfig get current => notifier.value;

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox(_boxName);
    } else {
      _box = Hive.box(_boxName);
    }

    final paletteId = _box.get(_keyPalette) as String? ?? AppColors.defaultPaletteId;
    final brightnessStr = _box.get(_keyBrightness) as String? ?? 'light';
    final brightness = brightnessStr == 'dark' ? Brightness.dark : Brightness.light;

    notifier.value = AppThemeConfig(
      palette: AppThemeConfig.paletteById(paletteId, brightness),
      brightness: brightness,
    );
  }

  Future<void> setPalette(String paletteId) async {
    final current = notifier.value;
    final newPalette = AppThemeConfig.paletteById(paletteId, current.brightness);
    notifier.value = current.copyWith(palette: newPalette);
    await _box.put(_keyPalette, paletteId);
  }

  Future<void> setBrightness(Brightness brightness) async {
    final current = notifier.value;
    final newPalette = AppThemeConfig.paletteById(current.palette.id, brightness);
    notifier.value = AppThemeConfig(palette: newPalette, brightness: brightness);
    await _box.put(_keyBrightness, brightness == Brightness.dark ? 'dark' : 'light');
  }

  Future<void> toggleBrightness() async {
    final newBrightness = notifier.value.brightness == Brightness.light
        ? Brightness.dark
        : Brightness.light;
    await setBrightness(newBrightness);
  }
}