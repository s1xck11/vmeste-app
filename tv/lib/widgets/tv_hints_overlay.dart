// tv/lib/widgets/tv_hints_overlay.dart
//
// Подсказки управления в правом нижнем углу: появляются, когда применимы.

import 'package:flutter/material.dart';

import '../services/hints_service.dart';
import '../theme/tv_theme.dart';

class TvHintsOverlay extends StatelessWidget {
  const TvHintsOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final hints = HintsService.instance;
    return AnimatedBuilder(
      animation: hints,
      builder: (_, __) {
        return Positioned(
          right: 24,
          bottom: 24,
          child: AnimatedOpacity(
            opacity: hints.visible && hints.lines.isNotEmpty ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.62),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: TvColors.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.gamepad_rounded,
                            size: 18, color: TvColors.accent),
                        const SizedBox(width: 8),
                        Text('Управление', style: TvText.caption),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (final l in hints.lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          l,
                          style: TvText.caption.copyWith(color: TvColors.text),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
