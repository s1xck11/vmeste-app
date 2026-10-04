// lib/widgets/glass_container.dart

import 'dart:ui';
import 'package:flutter/material.dart';

/// Матовое стекло с размытием фона.
/// Используется для нижней навигации и модальных окон.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final double blur;
  final double opacity;
  final Color? tint;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.radius = 0,
    this.blur = 24,
    this.opacity = 0.85,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base = tint ?? (isDark ? Colors.black : Colors.white);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: base.withOpacity(opacity),
            border: Border(
              top: BorderSide(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                width: 1,
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}