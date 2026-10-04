// lib/widgets/app_background.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/background_service.dart';

class AppBackground extends StatelessWidget {
  final Widget child;
  final BackgroundService? service;

  const AppBackground({super.key, required this.child, this.service});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bytes = service?.getImageBytes();

    if (bytes == null || bytes.isEmpty || service == null) {
      return Container(color: cs.background, child: child);
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => Container(color: cs.background),
          ),
        ),
        if (service!.blur > 0)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: service!.blur, sigmaY: service!.blur),
              child: const SizedBox.shrink(),
            ),
          ),
        Positioned.fill(
          child: Container(color: cs.background.withOpacity(0.45)),
        ),
        child,
      ],
    );
  }
}