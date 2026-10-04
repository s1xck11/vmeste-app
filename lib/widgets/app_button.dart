// lib/widgets/app_button.dart

import 'package:flutter/material.dart';

enum AppButtonVariant { primary, outlined, text, danger }

/// Единая кнопка приложения. Автоматически подстраивается
/// под палитру темы.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool fullWidth;
  final bool loading;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.fullWidth = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (icon != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(icon, size: 18),
          ),
        Text(label),
      ],
    );

    final onTap = (loading || onPressed == null) ? null : onPressed;

    Widget btn;
    switch (variant) {
      case AppButtonVariant.primary:
        btn = ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          child: child,
        );
        break;
      case AppButtonVariant.outlined:
        btn = OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.primary,
            side: BorderSide(color: cs.primary, width: 1.2),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          child: child,
        );
        break;
      case AppButtonVariant.text:
        btn = TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: cs.primary,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          child: child,
        );
        break;
      case AppButtonVariant.danger:
        btn = ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          child: child,
        );
        break;
    }

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: btn);
    }
    return btn;
  }
}