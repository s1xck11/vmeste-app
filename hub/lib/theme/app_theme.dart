// hub/lib/theme/app_theme.dart
// lib/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_theme_config.dart';

class AppTheme {
  static ThemeData build(AppThemeConfig config) {
    final p = config.palette;
    final isDark = config.brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: config.brightness,
      primary: p.accent,
      onPrimary: isDark ? Colors.black : Colors.white,
      secondary: p.accentDeep,
      onSecondary: isDark ? Colors.black : Colors.white,
      error: p.danger,
      onError: Colors.white,
      background: p.background,
      onBackground: p.text,
      surface: p.card,
      onSurface: p.text,
      surfaceVariant: p.cardElevated,
      onSurfaceVariant: p.textSecondary,
      outline: p.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: config.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      dividerColor: p.border,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: p.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: p.text, fontSize: 22,
          fontWeight: FontWeight.w700, letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: p.text),
      ),

      cardTheme: CardTheme(
        color: p.cardElevated,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: p.border, width: 1),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.cardElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBackgroundColor: p.cardElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),

      dialogTheme: DialogTheme(
        backgroundColor: p.cardElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        titleTextStyle: TextStyle(
          color: p.text, fontSize: 20, fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: p.textSecondary, fontSize: 15),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: TextStyle(color: p.textSecondary, fontSize: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: p.accent, width: 1.5),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: isDark ? Colors.black : Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.accent,
          side: BorderSide(color: p.accent, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? p.cardElevated : p.text,
        contentTextStyle: TextStyle(
          color: isDark ? p.text : Colors.white, fontSize: 15,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),

      textTheme: TextTheme(
        headlineLarge: TextStyle(color: p.text, fontSize: 36,
            fontWeight: FontWeight.w700, letterSpacing: -0.6),
        headlineMedium: TextStyle(color: p.text, fontSize: 28,
            fontWeight: FontWeight.w700, letterSpacing: -0.4),
        titleLarge: TextStyle(color: p.text, fontSize: 22,
            fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: p.text, fontSize: 18,
            fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: p.text, fontSize: 16),
        bodyMedium: TextStyle(color: p.text, fontSize: 15),
        bodySmall: TextStyle(color: p.textSecondary, fontSize: 13),
      ),

      iconTheme: IconThemeData(color: p.text),
    );
  }
}