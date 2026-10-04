// lib/screens/avatar_picker_screen.dart

import 'package:flutter/material.dart';

class AvatarPickerScreen extends StatelessWidget {
  final String currentAvatar;

  const AvatarPickerScreen({super.key, required this.currentAvatar});

  static const List<String> _emojis = [
    '👤', '🐉', '❤️', '🌸', '🌹', '⭐', '🌙', '☀️', '🔥', '💎',
    '🐱', '🐶', '🦊', '🐻', '🐼', '🐨', '🦁', '🐯', '🦄', '🐢',
    '🍀', '🌿', '🌷', '🌻', '🍀', '🎨', '🎭', '🎵', '📚', '🎮',
    '🏔', '🌊', '🌈', '☕', '🍕', '🍰', '🍓', '🍀', '💫', '✨',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(title: const Text('Выбор аватарки')),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: _emojis.length,
        itemBuilder: (ctx, i) {
          final e = _emojis[i];
          final selected = e == currentAvatar;
          return GestureDetector(
            onTap: () => Navigator.pop(context, e),
            child: Container(
              decoration: BoxDecoration(
                color: selected ? cs.primaryContainer : cs.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? cs.primary : cs.outline,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(e, style: const TextStyle(fontSize: 26)),
              ),
            ),
          );
        },
      ),
    );
  }
}