import 'package:flutter/material.dart';

/// Полупрозрачный контейнер (без BackdropFilter для производительности).
/// Визуально имитирует стекло: плотный полупрозрачный фон, обводка, тень.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
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
    this.opacity = 0.92, // Чуть плотнее, чтобы компенсировать отсутствие блюра
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
                  color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: base.withOpacity(opacity),
          borderRadius: BorderRadius.circular(radius),
          border: _buildBorder(isDark),
        ),
        child: child,
      ),
    );
  }

  BoxBorder? _buildBorder(bool isDark) {
    final topColor = Colors.white.withOpacity(isDark ? 0.15 : 0.8);
    final bottomColor = Colors.black.withOpacity(isDark ? 0.3 : 0.05);

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