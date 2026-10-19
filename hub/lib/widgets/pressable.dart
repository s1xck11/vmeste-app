import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool enableHaptic;
  final bool animate; // Если false — не скейлим (для стеклянных карточек)

  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.enableHaptic = true,
    this.animate = false, // По умолчанию выключено для производительности
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (!widget.animate) return;
    setState(() => _isPressed = true);
    _ctrl.forward();
  }

  void _onTapUp(TapUpDetails _) {
    if (!widget.animate) return;
    setState(() => _isPressed = false);
    _ctrl.reverse();
  }

  void _onTapCancel() {
    if (!widget.animate) return;
    setState(() => _isPressed = false);
    _ctrl.reverse();
  }

  void _onTap() {
    if (widget.enableHaptic) {
      HapticFeedback.lightImpact();
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    // Если анимация выключена, просто оборачиваем в Opacity/AnimatedOpacity
    // для эффекта "нажатия" без тяжелого BackdropFilter.
    if (!widget.animate) {
      return GestureDetector(
        onTap: _onTap,
        onLongPress: widget.onLongPress,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          opacity: _isPressed ? 0.85 : 1.0,
          child: widget.child,
        ),
      );
    }

    // Если анимация включена (для легких элементов)
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: _onTap,
      onLongPress: widget.onLongPress,
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}