// lib/widgets/app_bottom_sheet.dart

import 'package:flutter/material.dart';

/// Современная модалка снизу с ручкой и заголовком.
/// Умеет «прижиматься» к клавиатуре.
class AppBottomSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? footer;
  final bool scrollable;

  const AppBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.footer,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceVariant,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ручка
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Заголовок
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                    style: IconButton.styleFrom(
                      backgroundColor: cs.surface,
                      shape: const CircleBorder(),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outline),
            // Контент
            Flexible(
              child: scrollable
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: child,
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: child,
                    ),
            ),
            // Футер с кнопками
            if (footer != null) ...[
              Divider(height: 1, color: cs.outline),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: footer!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Удобный хелпер для показа.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    Widget? footer,
    bool isScrollControlled = true,
    bool scrollable = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (_) => AppBottomSheet(
        title: title,
        footer: footer,
        scrollable: scrollable,
        child: child,
      ),
    );
  }
}