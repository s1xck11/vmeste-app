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
  final String? avatarText;
  final Color? avatarColor;

  const NoteCard({
    super.key,
    required this.title,
    this.subtitle,
    this.accentColor,
    this.isDone = false,
    this.isHighPriority = false,
    required this.onTap,
    this.avatarText,
    this.avatarColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
              color: isHighPriority ? cs.error.withOpacity(0.45) : cs.outline.withOpacity(0.35),
              width: isHighPriority ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                spreadRadius: -1,
                offset: const Offset(0, 2),
              ),
              if (isHighPriority)
                BoxShadow(
                  color: cs.error.withOpacity(0.2),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 0),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isHighPriority) ...[
                          Row(
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(color: cs.error, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Важно',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: cs.error, letterSpacing: 0.4),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            decorationColor: cs.onSurfaceVariant,
                            height: 1.3,
                            letterSpacing: -0.1,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (avatarText != null && avatarText!.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: (avatarColor ?? cs.primary).withOpacity(0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: (avatarColor ?? cs.primary).withOpacity(0.6), width: 1.2),
                      ),
                      child: Text(
                        avatarText!,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.0,
                          fontWeight: FontWeight.w800,
                          color: avatarColor ?? cs.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                  maxLines: 2,
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