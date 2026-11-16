// tv/lib/widgets/tv_pointer_overlay.dart
//
// Красивый ТВ-курсор поверх лаунчера в режиме курсора:
// светящееся кольцо с точкой, пульс на клик.

import 'package:flutter/material.dart';

import '../services/input_service.dart';
import '../theme/tv_theme.dart';

class TvPointerOverlay extends StatelessWidget {
  const TvPointerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final input = InputService.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: input.pointerMode,
      builder: (_, on, __) {
        if (!on) return const SizedBox.shrink();
        return ValueListenableBuilder<Offset>(
          valueListenable: input.cursor,
          builder: (_, pos, ___) => ValueListenableBuilder<int>(
            valueListenable: input.clickPulse,
            builder: (_, pulse, ____) => Positioned(
              left: pos.dx - 17,
              top: pos.dy - 17,
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(pulse),
                  tween: Tween(begin: 0.75, end: 1.0),
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  builder: (_, s, child) =>
                      Transform.scale(scale: s, child: child),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: TvColors.focus, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: TvColors.accent.withOpacity(0.55),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                      color: Colors.black.withOpacity(0.25),
                    ),
                    child: Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: TvColors.accent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
