import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  cs.background,
                  Color.lerp(cs.background, cs.primary, 0.08) ?? cs.background,
                  cs.background,
                ]
              : [
                  cs.background,
                  Color.lerp(cs.background, cs.primary, 0.12) ?? cs.background,
                  cs.background,
                ],
        ),
      ),
      child: child,
    );
  }
}