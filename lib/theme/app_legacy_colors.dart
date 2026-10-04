// lib/theme/app_legacy_colors.dart
//
// ВРЕМЕННЫЙ ФАЙЛ.
// Нужен, чтобы старые экраны (Покупки, Задачи, Смены, Setup, модалки)
// продолжали работать, пока мы их не перепишем на новую систему.
// После переписывания всех экранов — этот файл удалим.

import 'package:flutter/material.dart';

class AppColors {
  static const Color accent = Color(0xFFFF8FAB);
  static const Color accentLight = Color(0xFFFFE5EC);
  static const Color danger = Color(0xFFFF3B30);
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9500);
  static const Color info = Color(0xFF5856D6);
  static const Color bgLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFF8F9FA);
  static const Color textLight = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF8E8E93);
}