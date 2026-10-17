import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_theme_config.dart';

class AppTheme {
  static ThemeData build(AppThemeConfig config) {
    final p = config.palette;
    final isDark = config.brightness == Brightness.dark;
    final baseTextTheme = GoogleFonts.manropeTextTheme();

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
      fontFamily: GoogleFonts.manrope().fontFamily,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: p.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: p.text, fontSize: 22,
          fontWeight: FontWeight.w700, letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: p.text),
      ),

      cardTheme: CardTheme(
        color: p.cardElevated,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32), // Увеличили радиус
          side: BorderSide(color: p.border, width: 1),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.cardElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBackgroundColor: p.cardElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        ),
      ),

      dialogTheme: DialogTheme(
        backgroundColor: p.cardElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
        ),
        titleTextStyle: TextStyle(
          color: p.text, fontSize: 22, fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: p.textSecondary, fontSize: 16),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        hintStyle: TextStyle(color: p.textSecondary, fontSize: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: p.accent, width: 2),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: isDark ? Colors.black : Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),

      textTheme: baseTextTheme.copyWith(
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
            color: p.text, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
            color: p.text, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
            color: p.text, fontSize: 22, fontWeight: FontWeight.w700),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
            color: p.text, fontSize: 18, fontWeight: FontWeight.w600),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
            color: p.text, fontSize: 16, fontWeight: FontWeight.w500),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
            color: p.text, fontSize: 15, fontWeight: FontWeight.w500),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
            color: p.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
      ),

      iconTheme: IconThemeData(color: p.text),
    );
  }
}