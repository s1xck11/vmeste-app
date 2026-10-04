// lib/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_theme_config.dart';

class AppTheme {
  /// Собирает ThemeData из конфига.
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
      splashFactory: InkSparkle.splashFactory,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: p.text,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: p.text),
      ),

      // Navigation Bar (bottom)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.cardElevated,
        indicatorColor: p.accentSoft,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? p.accent : p.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? p.accent : p.textSecondary,
          );
        }),
      ),

      // Card
      cardTheme: CardThemeData(
        color: p.cardElevated,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: p.border, width: 1),
        ),
      ),

      // BottomSheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.cardElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBackgroundColor: p.cardElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: p.cardElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        titleTextStyle: TextStyle(
          color: p.text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          color: p.textSecondary,
          fontSize: 14,
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: p.textSecondary, fontSize: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.danger),
        ),
      ),

      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: isDark ? Colors.black : Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.accent,
          side: BorderSide(color: p.accent, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: p.card,
        selectedColor: p.accentSoft,
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        labelStyle: TextStyle(color: p.text, fontSize: 13),
        secondaryLabelStyle: TextStyle(color: p.accent, fontSize: 13, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? p.cardElevated : p.text,
        contentTextStyle: TextStyle(
          color: isDark ? p.text : Colors.white,
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accent,
        foregroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),

      // Text
      textTheme: TextTheme(
        headlineLarge: TextStyle(color: p.text, fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineMedium: TextStyle(color: p.text, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleLarge: TextStyle(color: p.text, fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: p.text, fontSize: 15),
        bodyMedium: TextStyle(color: p.text, fontSize: 14),
        bodySmall: TextStyle(color: p.textSecondary, fontSize: 12),
      ),

      // Icon
      iconTheme: IconThemeData(color: p.text),
    );
  }
}