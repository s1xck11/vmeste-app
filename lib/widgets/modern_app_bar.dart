import 'package:flutter/material.dart';
import 'glass_container.dart';

class ModernAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback onAvatarTap;
  final String avatarEmoji;
  final List<Widget>? actions;
  final double panelHeight;

  const ModernAppBar({
    super.key,
    required this.title,
    required this.onAvatarTap,
    this.avatarEmoji = '👤',
    this.actions,
    this.panelHeight = 56,
  });

  @override
  Size get preferredSize => Size.fromHeight(panelHeight + 8);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final topInset = MediaQuery.of(context).padding.top;

    return Padding(
      padding: EdgeInsets.only(
        top: topInset + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      child: GlassContainer(
        radius: 28,
        showAllBorder: true,
        shadow: true,
        child: SizedBox(
          height: panelHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (actions != null) ...actions!,
                const SizedBox(width: 4),
                _AvatarButton(emoji: avatarEmoji, onTap: onAvatarTap),
              ],
            ),
          ),
        ),
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
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              emoji.isEmpty ? '👤' : emoji,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
      ),
    );
  }
}