// tv/lib/screens/tv_embed_screen.dart
//
// Экран встроенной программы: наша панель сверху, окно exe ниже.
// Управление: весь экран / открепить / закрыть программу / назад (B).

import 'package:flutter/material.dart';

import '../services/embed_service.dart';
import '../services/hints_service.dart';
import '../services/sound_service.dart';
import '../services/tiles_service.dart';
import '../theme/tv_theme.dart';
import '../widgets/tv_focusable.dart';

class TvEmbedScreen extends StatefulWidget {
  final TvTile tile;

  const TvEmbedScreen({super.key, required this.tile});

  @override
  State<TvEmbedScreen> createState() => _TvEmbedScreenState();
}

class _TvEmbedScreenState extends State<TvEmbedScreen> {
  String? _error;
  bool _busy = true;
  bool _full = false;
  static const double _chrome = 64;

  @override
  void initState() {
    super.initState();
    HintsService.instance.base([
      'B — назад (открепить)',
      'Панель сверху: экран / открепить / закрыть',
    ]);
    EmbedService.instance.backCallback = _back;
    _start();
  }

  Future<void> _start() async {
    final err = await EmbedService.instance.embed(widget.tile.target, widget.tile.title);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
    if (err != null) SoundService.instance.error();
    _layout();
  }

  void _layout() {
    if (!mounted || _error != null) return;
    final size = MediaQuery.of(context).size;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      EmbedService.instance.setRect(
        0,
        (_chrome * dpr).round(),
        (size.width * dpr).round(),
        ((size.height - _chrome) * dpr).round(),
      );
    });
  }

  void _back() {
    SoundService.instance.back();
    EmbedService.instance.detach();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    EmbedService.instance.backCallback = null;
    if (EmbedService.instance.active.value) EmbedService.instance.detach();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _layout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Container(
            height: _chrome,
            color: TvColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                TvIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Назад (B)',
                  onTap: _back,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.tile.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TvText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (_busy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: TvColors.accent),
                  ),
                const SizedBox(width: 12),
                TvIconButton(
                  icon: _full ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  tooltip: _full ? 'Вернуть панель' : 'На весь экран',
                  onTap: () {
                    final size = MediaQuery.of(context).size;
                    final dpr = MediaQuery.of(context).devicePixelRatio;
                    setState(() => _full = !_full);
                    EmbedService.instance.setFull(
                      _full,
                      0,
                      (_chrome * dpr).round(),
                      (size.width * dpr).round(),
                      (size.height * dpr).round(),
                    );
                  },
                ),
                const SizedBox(width: 8),
                TvIconButton(
                  icon: Icons.open_in_new_rounded,
                  tooltip: 'Открепить в обычное окно',
                  onTap: _back,
                ),
                const SizedBox(width: 8),
                TvIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Закрыть программу',
                  color: TvColors.danger,
                  onTap: () {
                    SoundService.instance.back();
                    EmbedService.instance.closeApp();
                    if (mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _error != null
                ? Center(
                    child: SizedBox(
                      width: 640,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.desktop_access_disabled_rounded,
                              size: 64, color: TvColors.warning),
                          const SizedBox(height: 16),
                          Text(_error!, style: TvText.bodyDim, textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          Text(
                            'Программа запущена обычным окном поверх лаунчера.',
                            style: TvText.caption,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          TvDialogButton(label: 'Назад', primary: true, onTap: _back),
                        ],
                      ),
                    ),
                  )
                : const ColoredBox(color: Colors.black),
          ),
        ],
      ),
    );
  }
}
