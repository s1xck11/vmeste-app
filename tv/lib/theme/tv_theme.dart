// tv/lib/theme/tv_theme.dart
//
// Дизайн в стиле Android TV / Google TV:
// тёмная сцена, ряды карточек, крупные плитки, белый фокус-ринг.
// Размеры рассчитаны на 1080p и просмотр с ~2-3 метров.

import 'package:flutter/material.dart';

class TvColors {
  // Сцена
  static const Color bg = Color(0xFF0F0F0F);
  static const Color surface = Color(0xFF161616);
  static const Color card = Color(0xFF1F1F1F);
  static const Color cardHi = Color(0xFF2A2A2A);
  static const Color outline = Color(0xFF333333);

  // Текст
  static const Color text = Color(0xFFF2F2F2);
  static const Color textDim = Color(0xFFA8A8A8);
  static const Color textFaint = Color(0xFF6F6F6F);

  // Фокус (как на Android TV — белая рамка)
  static const Color focus = Color(0xFFFFFFFF);

  // Фирменный акцент «Вместе» (роза из мобильной темы)
  static const Color accent = Color(0xFFE8A0B5);
  static const Color accentDeep = Color(0xFFC77B91);

  // Семантика
  static const Color danger = Color(0xFFEF5350);
  static const Color success = Color(0xFF66BB6A);
  static const Color warning = Color(0xFFFFB74D);
  static const Color info = Color(0xFF64B5F6);

  // Приоритеты (как в мобилке: high/med/low)
  static const Color prioHigh = Color(0xFFEF5350);
  static const Color prioMed = Color(0xFFFFB74D);
  static const Color prioLow = Color(0xFF64B5F6);
}

class TvText {
  static const String _f = 'Inter';

  static const TextStyle clock = TextStyle(
    fontFamily: _f, fontSize: 84, fontWeight: FontWeight.w600,
    color: TvColors.text, height: 1.0, letterSpacing: -2,
  );
  static const TextStyle date = TextStyle(
    fontFamily: _f, fontSize: 22, fontWeight: FontWeight.w400,
    color: TvColors.textDim, height: 1.2,
  );
  static const TextStyle heroNumber = TextStyle(
    fontFamily: _f, fontSize: 52, fontWeight: FontWeight.w700,
    color: TvColors.text, height: 1.05, letterSpacing: -1,
  );
  static const TextStyle rowTitle = TextStyle(
    fontFamily: _f, fontSize: 26, fontWeight: FontWeight.w600,
    color: TvColors.text, height: 1.2,
  );
  static const TextStyle cardTitle = TextStyle(
    fontFamily: _f, fontSize: 22, fontWeight: FontWeight.w600,
    color: TvColors.text, height: 1.2,
  );
  static const TextStyle body = TextStyle(
    fontFamily: _f, fontSize: 20, fontWeight: FontWeight.w400,
    color: TvColors.text, height: 1.3,
  );
  static const TextStyle bodyDim = TextStyle(
    fontFamily: _f, fontSize: 20, fontWeight: FontWeight.w400,
    color: TvColors.textDim, height: 1.3,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: _f, fontSize: 16, fontWeight: FontWeight.w500,
    color: TvColors.textDim, height: 1.2,
  );
  static const TextStyle tileTitle = TextStyle(
    fontFamily: _f, fontSize: 20, fontWeight: FontWeight.w600,
    color: TvColors.text, height: 1.2,
  );
  static const TextStyle button = TextStyle(
    fontFamily: _f, fontSize: 20, fontWeight: FontWeight.w600,
    color: TvColors.text, height: 1.2,
  );
}

class TvSpace {
  static const double screenH = 48;      // боковые отступы (безопасная зона ТВ)
  static const double screenV = 32;
  static const double rowGap = 36;       // между рядами
  static const double cardGap = 18;      // между карточками в ряду
  static const double cardRadius = 18;
  static const double tileRadius = 16;
  static const double buttonRadius = 12;
  static const double focusBorder = 3;
}

class TvDecor {
  /// Карточка/плитка с фокус-рамкой в стиле Android TV.
  static BoxDecoration card({bool focused = false, Color? color, double radius = TvSpace.cardRadius}) {
    return BoxDecoration(
      color: color ?? TvColors.card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: focused ? TvColors.focus : Colors.transparent,
        width: TvSpace.focusBorder,
      ),
      boxShadow: focused
          ? [BoxShadow(color: Colors.black.withOpacity(0.65), blurRadius: 28, spreadRadius: 2)]
          : null,
    );
  }
}

class TvTheme {
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: TvColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: TvColors.accent,
        secondary: TvColors.accentDeep,
        surface: TvColors.card,
        error: TvColors.danger,
        onPrimary: Colors.black,
        onSurface: TvColors.text,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dialogBackgroundColor: TvColors.cardHi,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: TvColors.accent,
        selectionColor: Color(0x66E8A0B5),
        selectionHandleColor: TvColors.accent,
      ),
    );
  }
}
