import 'package:flutter/material.dart';

/// Карточка-заметка для стиля Masonry Grid.
/// Высота зависит от длины текста.
class NoteCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color? accentColor;
  final bool isDone;
  final bool isHighPriority;
  final VoidCallback onTap;

  const NoteCard({
    super.key,
    required this.title,
    this.subtitle,
    this.accentColor,
    this.isDone = false,
    this.isHighPriority = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = accentColor ?? cs.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHighPriority
                  ? cs.error.withOpacity(0.5)
                  : cs.outline.withOpacity(0.5),
              width: isHighPriority ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Заголовок
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  decorationColor: cs.onSurfaceVariant,
                  height: 1.3,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (isDone) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: cs.tertiary),
                    const SizedBox(width: 4),
                    Text(
                      'Выполнено',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cs.tertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}