import 'dart:ui';
import 'package:flutter/material.dart';

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
    this.radius = 32,
    this.blur = 30,
    this.opacity = 0.82, // Чуть прозрачнее, чтобы стекло дышало
    this.tint,
    this.showTopBorder = false,
    this.showAllBorder = false,
    this.shadow = true,
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
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                  blurRadius: 32,
                  spreadRadius: 0,
                  offset: const Offset(0, 12), // Тень глубже
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
    // Светлый блик сверху и едва заметная тень снизу — как у Apple
    final topColor = (isDark ? Colors.white : Colors.white).withOpacity(isDark ? 0.15 : 0.8);
    final bottomColor = (isDark ? Colors.black : Colors.black).withOpacity(isDark ? 0.3 : 0.05);

    if (showAllBorder) {
      return Border.all(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
        width: 1,
      );
    }
    
    return Border(
      top: BorderSide(color: topColor, width: 1.5),
      bottom: BorderSide(color: bottomColor, width: 1),
    );
  }
}