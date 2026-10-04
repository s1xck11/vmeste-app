// lib/theme/app_theme_config.dart

import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Одна палитра цветов для определённой яркости.
class AppPalette {
  final String id;
  final String name;
  final Color accent;
  final Color accentSoft;      // мягкий фон под акцент
  final Color accentDeep;      // глубокий оттенок для градиента
  final Color background;
  final Color card;
  final Color cardElevated;
  final Color text;
  final Color textSecondary;
  final Color border;
  final Color danger;
  final Color success;
  final Color warning;
  final Color info;

  const AppPalette({
    required this.id,
    required this.name,
    required this.accent,
    required this.accentSoft,
    required this.accentDeep,
    required this.background,
    required this.card,
    required this.cardElevated,
    required this.text,
    required this.textSecondary,
    required this.border,
    required this.danger,
    required this.success,
    required this.warning,
    required this.info,
  });
}

/// Полный конфиг темы: палитра + яркость.
class AppThemeConfig {
  final AppPalette palette;
  final Brightness brightness;

  const AppThemeConfig({
    required this.palette,
    required this.brightness,
  });

  AppThemeConfig copyWith({
    AppPalette? palette,
    Brightness? brightness,
  }) {
    return AppThemeConfig(
      palette: palette ?? this.palette,
      brightness: brightness ?? this.brightness,
    );
  }

  /// Возвращает палитру по id для указанной яркости.
  static AppPalette paletteById(String id, Brightness brightness) {
    final map = brightness == Brightness.light
        ? AppColors.lightPalettes
        : AppColors.darkPalettes;
    return map[id] ?? map.values.first;
  }

  /// Список id всех доступных палитр.
  static List<String> get allIds => AppColors.lightPalettes.keys.toList();

  /// Имя палитры по id (независимо от яркости).
  static String nameById(String id) {
    return AppColors.lightPalettes[id]?.name ??
        AppColors.darkPalettes[id]?.name ??
        id;
  }
}