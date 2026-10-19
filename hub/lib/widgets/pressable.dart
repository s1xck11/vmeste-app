import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Pressable extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool enableHaptic;
  final bool animate; // Игнорируется, оставлен для обратной совместимости

  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.enableHaptic = true,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (enableHaptic) HapticFeedback.lightImpact();
        onTap();
      },
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}