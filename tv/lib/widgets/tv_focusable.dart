// tv/lib/widgets/tv_focusable.dart
//
// Базовые ТВ-контролы: фокус как на Android TV (белая рамка + зум),
// работают мышью, клавиатурой и геймпадом.

import 'package:flutter/material.dart';

import '../services/osk_service.dart';
import '../theme/tv_theme.dart';

class TvFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool autofocus;
  final double scale;
  final double radius;

  const TvFocusable({
    super.key,
    required this.child,
    this.onTap,
    this.autofocus = false,
    this.scale = 1.04,
    this.radius = TvSpace.tileRadius,
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  final FocusNode _node = FocusNode();
  bool _focused = false;
  bool _hovered = false;

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _focused || _hovered;
    return FocusableActionDetector(
      focusNode: _node,
      autofocus: widget.autofocus,
      onFocusChange: (v) => setState(() => _focused = v),
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onTap?.call();
          return null;
        }),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _node.requestFocus();
          widget.onTap?.call();
        },
        child: AnimatedScale(
          scale: active ? widget.scale : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius + 2),
              border: Border.all(
                color: active ? TvColors.focus : Colors.transparent,
                width: TvSpace.focusBorder,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 24,
                        spreadRadius: 1,
                      )
                    ]
                  : const [],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class TvIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? color;
  final bool autofocus;

  const TvIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.color,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: TvColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color ?? TvColors.text, size: 26),
    );
    return TvFocusable(
      onTap: onTap,
      autofocus: autofocus,
      scale: 1.08,
      radius: 12,
      child: tooltip == null
          ? box
          : Tooltip(
              message: tooltip!,
              waitDuration: const Duration(milliseconds: 600),
              child: box,
            ),
    );
  }
}

class TvDialogButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool danger;
  final bool primary;
  final bool autofocus;

  const TvDialogButton({
    super.key,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.primary = false,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onTap: onTap,
      autofocus: autofocus,
      scale: 1.05,
      radius: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: primary
              ? TvColors.accent
              : danger
                  ? TvColors.danger.withOpacity(0.16)
                  : TvColors.cardHi,
          borderRadius: BorderRadius.circular(12),
          border: danger
              ? Border.all(color: TvColors.danger.withOpacity(0.5))
              : null,
        ),
        child: Text(
          label,
          style: TvText.button.copyWith(
            color: primary
                ? Colors.black
                : danger
                    ? TvColors.danger
                    : TvColors.text,
          ),
        ),
      ),
    );
  }
}

class TvSectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const TvSectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, left: 4),
      child: Row(
        children: [
          Text(text, style: TvText.rowTitle),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

/// Поле ввода, которое само открывает экранную клаву при фокусе.
class TvTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool autofocus;
  final VoidCallback? onSubmit;

  const TvTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.autofocus = false,
    this.onSubmit,
  });

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> {
  final FocusNode _node = FocusNode();

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocus);
  }

  void _onFocus() {
    if (_node.hasFocus) {
      OskService.instance.show(
        controller: widget.controller,
        onSubmit: widget.onSubmit,
      );
    }
  }

  @override
  void dispose() {
    if (OskService.instance.controller == widget.controller) {
      OskService.instance.hide();
    }
    _node.removeListener(_onFocus);
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _node,
      autofocus: widget.autofocus,
      style: TvText.body,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => widget.onSubmit?.call(),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        labelStyle: TvText.bodyDim,
        hintStyle: TvText.bodyDim.copyWith(color: TvColors.textFaint),
        filled: true,
        fillColor: TvColors.cardHi,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TvColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TvColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TvColors.accent, width: 2),
        ),
      ),
    );
  }
}
