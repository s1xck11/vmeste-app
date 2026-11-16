// tv/lib/screens/tv_home_screen.dart
//
// Главный экран: обои, топбар (звук/курсор/обновление/настройки/питание),
// часы + погода, ряд виджетов «Сегодня», ряд плиток «Приложения».

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart' show sync, tiles, showExitDialog;
import '../services/gamepad_service.dart';
import '../services/hints_service.dart';
import '../services/input_service.dart';
import '../services/sound_service.dart';
import '../services/tiles_service.dart';
import '../services/tv_sync_service.dart';
import '../services/update_service.dart';
import '../services/wallpaper_service.dart';
import '../services/weather_service.dart';
import '../theme/tv_theme.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/tv_tile.dart';
import '../widgets/tv_widget_cards.dart';
import 'tv_browser_screen.dart';
import 'tv_detail_screen.dart';
import 'tv_embed_screen.dart';
import 'tv_settings_screen.dart';

class TvHomeScreen extends StatefulWidget {
  const TvHomeScreen({super.key});

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends State<TvHomeScreen> {
  Timer? _tick;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    HintsService.instance.base([
      'Крестовина / стик — выбор',
      'A — открыть, B — назад',
      'Y — клавиатура, R3 — курсор',
      'Start — домой',
    ], isHome: true);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String get _greeting {
    final h = _now.hour;
    if (h < 5) return 'Доброй ночи';
    if (h < 12) return 'Доброе утро';
    if (h < 18) return 'Добрый день';
    return 'Добрый вечер';
  }

  void _openDetail(TvDetailType type) {
    SoundService.instance.open();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TvDetailScreen(type: type)),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TvSettingsScreen()),
    );
  }

  Future<void> _launch(TvTile tile) async {
    if (tile.kind == TvTileKind.web) {
      if (!mounted) return;
      SoundService.instance.open();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TvBrowserScreen(url: tile.target, title: tile.title),
        ),
      );
      return;
    }
    if (tile.kind == TvTileKind.embed) {
      if (!mounted) return;
      SoundService.instance.open();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TvEmbedScreen(tile: tile)),
      );
      return;
    }
    final err = await tiles.launch(tile);
    if (err != null && mounted) {
      SoundService.instance.error();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: TvColors.cardHi,
          content: Text(err, style: TvText.body),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WallpaperService.instance.background(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(TvSpace.screenH, 20, TvSpace.screenH, 0),
          child: Column(
            children: [
              _topBar(),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  clipBehavior: Clip.none,
                  children: [
                    _hero(),
                    const SizedBox(height: TvSpace.rowGap),
                    const TvSectionTitle('Сегодня'),
                    SizedBox(
                      height: 262,
                      child: ListView(
                        clipBehavior: Clip.none,
                        scrollDirection: Axis.horizontal,
                        children: [
                          TasksCard(onTap: () => _openDetail(TvDetailType.tasks), autofocus: true),
                          const SizedBox(width: TvSpace.cardGap),
                          PurchasesCard(onTap: () => _openDetail(TvDetailType.purchases)),
                          const SizedBox(width: TvSpace.cardGap),
                          ShiftsCard(onTap: () => _openDetail(TvDetailType.shifts)),
                          const SizedBox(width: TvSpace.cardGap),
                          BudgetCard(onTap: () => _openDetail(TvDetailType.budget)),
                        ],
                      ),
                    ),
                    const SizedBox(height: TvSpace.rowGap),
                    TvSectionTitle(
                      'Приложения',
                      trailing: TvIconButton(
                        icon: Icons.add_rounded,
                        tooltip: 'Добавить плитку',
                        onTap: _openSettings,
                      ),
                    ),
                    SizedBox(
                      height: 185,
                      child: AnimatedBuilder(
                        animation: tiles,
                        builder: (_, __) => ListView(
                          clipBehavior: Clip.none,
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final t in tiles.tiles)
                              Padding(
                                padding: const EdgeInsets.only(right: TvSpace.cardGap),
                                child: TvTileWidget(tile: t, onTap: () => _launch(t)),
                              ),
                            TvTileAdd(onTap: _openSettings),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        const Icon(Icons.favorite_rounded, color: TvColors.accent, size: 28),
        const SizedBox(width: 10),
        Text('Вместе ТВ', style: TvText.rowTitle),
        const Spacer(),
        ValueListenableBuilder<bool>(
          valueListenable: GamepadService.instance.connected,
          builder: (_, connected, __) => Icon(
            Icons.gamepad_rounded,
            size: 26,
            color: connected ? TvColors.success : TvColors.textFaint,
          ),
        ),
        const SizedBox(width: 18),
        AnimatedBuilder(
          animation: sync,
          builder: (_, __) {
            final (Color, String) info = switch (sync.status) {
              TvSyncStatus.online => (TvColors.success, 'Онлайн'),
              TvSyncStatus.connecting => (TvColors.warning, 'Подключение…'),
              TvSyncStatus.offline => (TvColors.danger, 'Офлайн'),
              TvSyncStatus.noGroup => (TvColors.textFaint, 'Нет группы'),
            };
            return Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: info.$1, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(info.$2, style: TvText.caption),
              ],
            );
          },
        ),
        const SizedBox(width: 18),
        AnimatedBuilder(
          animation: UpdateService.instance,
          builder: (_, __) => UpdateService.instance.ready
              ? Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: TvIconButton(
                    icon: Icons.system_update_alt_rounded,
                    tooltip: 'Доступно обновление ${UpdateService.instance.latestTag}',
                    color: TvColors.success,
                    onTap: _openSettings,
                  ),
                )
              : const SizedBox.shrink(),
        ),
        AnimatedBuilder(
          animation: SoundService.instance,
          builder: (_, __) => TvIconButton(
            icon: SoundService.instance.enabled
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            tooltip: SoundService.instance.enabled ? 'Звук включён' : 'Звук выключен',
            color: SoundService.instance.enabled ? TvColors.text : TvColors.textFaint,
            onTap: () => SoundService.instance.setEnabled(!SoundService.instance.enabled),
          ),
        ),
        const SizedBox(width: 10),
        ValueListenableBuilder<bool>(
          valueListenable: InputService.instance.pointerMode,
          builder: (_, on, __) => TvIconButton(
            icon: Icons.mouse_rounded,
            tooltip: 'Режим курсора (R3)',
            color: on ? TvColors.accent : TvColors.text,
            onTap: () {
              InputService.instance.setPointerMode(!on);
              HintsService.instance.context(
                on
                    ? HintsService.instance.homeLines
                    : [
                        'Правый стик — курсор',
                        'Левый стик — скролл',
                        'A — клик, X — правый клик',
                        'R3 — выйти из курсора',
                      ],
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        TvIconButton(
          icon: Icons.settings_rounded,
          tooltip: 'Настройки',
          onTap: _openSettings,
        ),
        const SizedBox(width: 10),
        TvIconButton(
          icon: Icons.power_settings_new_rounded,
          tooltip: 'Выход',
          onTap: () => showExitDialog(context),
        ),
      ],
    );
  }

  Widget _hero() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(DateFormat('HH:mm').format(_now), style: TvText.clock),
        const SizedBox(width: 24),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _weatherPill(),
        ),
        const SizedBox(width: 24),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting, style: TvText.cardTitle),
              const SizedBox(height: 4),
              Text(
                '${tvWeekdays[_now.weekday - 1]}, ${_now.day} ${tvMonths[_now.month - 1]}',
                style: TvText.date,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _weatherPill() {
    final w = WeatherService.instance;
    return AnimatedBuilder(
      animation: w,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TvColors.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(w.icon, size: 36, color: TvColors.warning),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  w.temp == null ? '—°' : '${w.temp!.round()}°',
                  style: TvText.heroNumber.copyWith(fontSize: 34),
                ),
                Text(w.label, style: TvText.caption),
              ],
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  w.tmin == null || w.tmax == null
                      ? w.city
                      : '${w.tmin!.round()}° / ${w.tmax!.round()}°',
                  style: TvText.caption,
                ),
                const SizedBox(height: 3),
                Text(
                  '${w.city} • ${w.wind.round()} км/ч',
                  style: TvText.caption.copyWith(color: TvColors.textFaint),
                ),
              ],
            ),
            if (w.loading) ...[
              const SizedBox(width: 12),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: TvColors.accent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
