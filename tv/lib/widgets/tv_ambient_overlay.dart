// tv/lib/widgets/tv_ambient_overlay.dart
//
// Живые обои амбиента: aurora-градиенты + дрейфующие частицы,
// огромные часы, погода, ближайшая смена, счётчики. Один ticker на всё.

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart' show sync;
import '../services/ambient_service.dart';
import '../services/weather_service.dart';
import '../theme/tv_theme.dart';
import 'tv_widget_cards.dart';

class TvAmbientOverlay extends StatefulWidget {
  const TvAmbientOverlay({super.key});

  @override
  State<TvAmbientOverlay> createState() => _TvAmbientOverlayState();
}

class _TvAmbientOverlayState extends State<TvAmbientOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 120),
  );
  DateTime _now = DateTime.now();
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    AmbientService.instance.active.addListener(_onActive);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && AmbientService.instance.active.value) {
        setState(() => _now = DateTime.now());
      }
    });
    if (AmbientService.instance.active.value) _c.repeat();
  }

  void _onActive() {
    if (!mounted) return;
    if (AmbientService.instance.active.value) {
      setState(() => _now = DateTime.now());
      _c.repeat();
    } else {
      _c.stop();
    }
    setState(() {});
  }

  @override
  void dispose() {
    AmbientService.instance.active.removeListener(_onActive);
    _clock?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amb = AmbientService.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: amb.active,
      builder: (_, on, __) => AnimatedOpacity(
        opacity: on ? 1 : 0,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOut,
        child: IgnorePointer(
          ignoring: !on,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _AmbientPainter(
                    t: _c.value * 120,
                    particles: amb.particles,
                  ),
                ),
                Container(color: Colors.black.withOpacity(0.35)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 72, vertical: 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.favorite_rounded,
                              color: TvColors.accent, size: 26),
                          const SizedBox(width: 10),
                          Text('Вместе ТВ', style: TvText.cardTitle),
                          const Spacer(),
                          Text('амбиент', style: TvText.caption),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('HH:mm').format(_now),
                        style: TvText.clock.copyWith(
                          fontSize: 168,
                          letterSpacing: -6,
                          shadows: [
                            Shadow(
                              color: TvColors.accent.withOpacity(0.35),
                              blurRadius: 60,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${tvWeekdays[_now.weekday - 1]}, ${_now.day} ${tvMonths[_now.month - 1]}',
                        style: TvText.date.copyWith(fontSize: 30),
                      ),
                      const SizedBox(height: 28),
                      if (amb.showWeather) _weatherRow(),
                      const Spacer(),
                      _infoChips(),
                      const SizedBox(height: 18),
                      Text(
                        'Нажми любую кнопку или двинь мышью, чтобы вернуться',
                        style: TvText.caption.copyWith(color: TvColors.textFaint),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _weatherRow() {
    final w = WeatherService.instance;
    return AnimatedBuilder(
      animation: w,
      builder: (_, __) => Row(
        children: [
          Icon(w.icon, size: 44, color: TvColors.warning),
          const SizedBox(width: 16),
          Text(
            w.temp == null ? '—°' : '${w.temp!.round()}°',
            style: TvText.heroNumber.copyWith(fontSize: 52),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(w.label, style: TvText.body),
              Text(
                '${w.city} • ${w.tmin?.round() ?? '—'}° / ${w.tmax?.round() ?? '—'}°',
                style: TvText.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChips() {
    final today = todayStr();
    final upcoming = sync.shifts.where((s) => s.date.compareTo(today) >= 0).toList()
      ..sort((a, b) {
        final d = a.date.compareTo(b.date);
        return d != 0 ? d : a.startTime.compareTo(b.startTime);
      });
    final tasks = sync.tasks.where((t) => !t.done && !t.archived).length;
    final buys = sync.purchases.where((p) => p.listId == 'common' && !p.done).length;
    String shiftLabel = 'Смен нет';
    if (upcoming.isNotEmpty) {
      final s = upcoming.first;
      final when = s.date == today ? 'сегодня' : shortDate(s.date);
      shiftLabel = '$when ${s.startTime} • ${partnerName(sync.partners, s.partner)}';
    }
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _chip(Icons.work_outline_rounded, shiftLabel, TvColors.warning),
        _chip(Icons.check_circle_outline_rounded, 'Задач: $tasks', TvColors.info),
        _chip(Icons.shopping_cart_outlined, 'Покупок: $buys', TvColors.success),
      ],
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 10),
          Text(label, style: TvText.body),
        ],
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  final double t;
  final bool particles;

  _AmbientPainter({required this.t, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, size.height),
          [const Color(0xFF07080F), const Color(0xFF101430), const Color(0xFF1A0B14)],
        ),
    );

    void blob(double cx, double cy, double r, Color c, double phase) {
      final x = cx + math.sin(t * 0.05 + phase) * size.width * 0.12;
      final y = cy + math.cos(t * 0.04 + phase * 1.7) * size.height * 0.10;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(x, y),
            r,
            [c.withOpacity(0.30), Colors.transparent],
          ),
      );
    }

    blob(size.width * 0.22, size.height * 0.30, size.width * 0.42,
        const Color(0xFFE8A0B5), 0);
    blob(size.width * 0.78, size.height * 0.24, size.width * 0.38,
        const Color(0xFF6A5CFF), 2.1);
    blob(size.width * 0.60, size.height * 0.82, size.width * 0.46,
        const Color(0xFF2DD4BF), 4.2);

    if (particles) {
      final rnd = math.Random(7);
      final p = Paint()..color = Colors.white.withOpacity(0.35);
      for (var i = 0; i < 70; i++) {
        final bx = rnd.nextDouble();
        final by = rnd.nextDouble();
        final sp = 0.008 + rnd.nextDouble() * 0.02;
        final drift = math.sin(t * 0.3 + i) * 0.01;
        final y = (by - t * sp) % 1.0;
        final yy = y < 0 ? y + 1.0 : y;
        final r = 0.8 + rnd.nextDouble() * 1.8;
        p.color = (i % 5 == 0 ? TvColors.accent : Colors.white)
            .withOpacity(0.12 + rnd.nextDouble() * 0.3);
        canvas.drawCircle(
          Offset((bx + drift) * size.width, yy * size.height),
          r,
          p,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter old) =>
      old.t != t || old.particles != particles;
}
