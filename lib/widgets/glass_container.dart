// lib/widgets/glass_container.dart

import 'dart:ui';
import 'package:flutter/material.dart';

/// Матовое стекло с размытием фона.
/// 
/// Используется для навбара, верхней шапки, плавающих плашек.
/// 
/// Параметры:
/// - [opacity] — плотность фона (0.85 = сильное просвечивание, 0.95 = почти непрозрачный)
/// - [showTopBorder] — рисовать верхнюю полоску (нужно для навбара, у которого
///   только верхняя грань видна рядом с контентом)
/// - [showAllBorder] — обводка по всему периметру (для «островков»)
/// - [shadow] — мягкая тень под элементом
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final double blur;
  final double opacity;
  final Color? tint;
  final bool showTopBorder;
  final bool showAllBorder;
  final bool shadow;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.radius = 0,
    this.blur = 24,
    this.opacity = 0.90,
    this.tint,
    this.showTopBorder = false,
    this.showAllBorder = false,
    this.shadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base = tint ?? (isDark ? const Color(0xFF1C1A1B) : Colors.white);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: base.withOpacity(opacity),
              borderRadius: BorderRadius.circular(radius),
              border: _buildBorder(isDark),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  BoxBorder? _buildBorder(bool isDark) {
    final lineColor = (isDark ? Colors.white : Colors.black).withOpacity(0.08);

    if (showAllBorder) {
      return Border.all(color: lineColor, width: 1);
    }
    if (showTopBorder) {
      return Border(
        top: BorderSide(color: lineColor, width: 1),
      );
    }
    return null;
  }
}