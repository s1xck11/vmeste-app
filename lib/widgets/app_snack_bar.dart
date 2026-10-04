// lib/widgets/app_snack_bar.dart

import 'package:flutter/material.dart';

enum AppSnackType { success, error, info, warning }

/// Единый способ показывать всплывашки.
class AppSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    AppSnackType type = AppSnackType.info,
    Duration duration = const Duration(seconds: 2),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    late Color bg;
    late IconData icon;
    switch (type) {
      case AppSnackType.success:
        bg = cs.tertiaryContainer;
        icon = Icons.check_circle_outline;
        break;
      case AppSnackType.error:
        bg = cs.errorContainer;
        icon = Icons.error_outline;
        break;
      case AppSnackType.warning:
        bg = cs.secondaryContainer;
        icon = Icons.warning_amber_outlined;
        break;
      case AppSnackType.info:
      default:
        bg = cs.surfaceVariant;
        icon = Icons.info_outline;
        break;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(12),
          content: Row(
            children: [
              Icon(icon, color: cs.onSurface, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: cs.onSurface, fontSize: 14),
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: cs.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(actionLabel),
                ),
            ],
          ),
        ),
      );
  }

  static void success(BuildContext context, String message) =>
      show(context, message: message, type: AppSnackType.success);

  static void error(BuildContext context, String message) =>
      show(context, message: message, type: AppSnackType.error, duration: const Duration(seconds: 4));

  static void info(BuildContext context, String message) =>
      show(context, message: message, type: AppSnackType.info);

  static void warning(BuildContext context, String message) =>
      show(context, message: message, type: AppSnackType.warning);
}