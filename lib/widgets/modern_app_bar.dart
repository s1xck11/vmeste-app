// lib/widgets/modern_app_bar.dart

import 'package:flutter/material.dart';

/// Современный заголовок экрана: крупный текст + иконки действий.
/// Аватарка — крайняя справа, ведёт в настройки.
class ModernAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final VoidCallback onAvatarTap;
  final String avatarLabel; // буква или эмодзи
  final double height;

  const ModernAppBar({
    super.key,
    required this.title,
    required this.onAvatarTap,
    this.actions,
    this.avatarLabel = '👤',
    this.height = 72,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 20,
        right: 12,
        bottom: 12,
      ),
      color: cs.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: cs.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actions != null) ...actions!,
          const SizedBox(width: 4),
          _AvatarButton(label: avatarLabel, onTap: onAvatarTap),
        ],
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AvatarButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: label.length <= 2 && label.runes.length > 1
                ? Text(label, style: const TextStyle(fontSize: 18))
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}