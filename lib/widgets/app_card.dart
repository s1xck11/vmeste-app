// lib/widgets/app_card.dart

import 'package:flutter/material.dart';

/// Современная карточка: мягкая рамка, скругления, опционально
/// кликабельная.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final content = Container(
      decoration: BoxDecoration(
        color: color ?? cs.surfaceVariant,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? cs.outline,
          width: 1,
        ),
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}