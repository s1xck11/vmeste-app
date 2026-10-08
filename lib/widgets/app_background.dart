// lib/widgets/app_background.dart

import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/background_service.dart';

class AppBackground extends StatefulWidget {
  final Widget child;
  final BackgroundService? service;

  const AppBackground({super.key, required this.child, this.service});

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground> {
  Uint8List? _bytes;
  double _blur = 0;

  @override
  void initState() {
    super.initState();
    _load();
    widget.service?.notifier.addListener(_onNotifierChange);
  }

  @override
  void dispose() {
    widget.service?.notifier.removeListener(_onNotifierChange);
    super.dispose();
  }

  void _onNotifierChange() {
    _load();
  }

  Future<void> _load() async {
    if (widget.service == null) {
      if (mounted) setState(() { _bytes = null; _blur = 0; });
      return;
    }
    final bytes = await widget.service!.loadImageBytes();
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _blur = widget.service!.blur;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_bytes == null || widget.service == null) {
      return Container(color: cs.background, child: widget.child);
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Image.memory(
            _bytes!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => Container(color: cs.background),
          ),
        ),
        if (_blur > 0)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
              child: const SizedBox.shrink(),
            ),
          ),
        Positioned.fill(
          child: Container(color: cs.background.withOpacity(0.45)),
        ),
        widget.child,
      ],
    );
  }
}