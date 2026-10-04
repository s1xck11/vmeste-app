// lib/widgets/modern_app_bar.dart

import 'package:flutter/material.dart';

class ModernAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback onAvatarTap;
  final VoidCallback? onAdd;
  final String avatarEmoji;
  final double height;

  const ModernAppBar({
    super.key,
    required this.title,
    required this.onAvatarTap,
    this.onAdd,
    this.avatarEmoji = '👤',
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
          if (onAdd != null)
            IconButton(
              onPressed: onAdd,
              icon: Icon(Icons.add_circle_outline, color: cs.primary, size: 26),
              tooltip: 'Добавить',
            ),
          const SizedBox(width: 4),
          _AvatarButton(emoji: avatarEmoji, onTap: onAvatarTap),
        ],
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;

  const _AvatarButton({required this.emoji, required this.onTap});

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
            child: Text(
              emoji.isEmpty ? '👤' : emoji,
              style: const TextStyle(fontSize: 22),
            ),
          ),
        ),
      ),
    );
  }
}