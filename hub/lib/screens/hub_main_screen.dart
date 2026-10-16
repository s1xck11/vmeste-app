import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/theme_service.dart';
import 'hub_center_screen.dart';
import 'hub_apps_screen.dart';
import 'hub_shifts_screen.dart';
import 'hub_budget_screen.dart';
import 'hub_weather_screen.dart';

/// Крестовина навигации.
/// 
///     [Смены]
///        ↑
/// [Приложения] ← [Центр] → [Бюджет]
///        ↓
///     [Погода]
/// 
/// Свайпы между экранами, возврат в центр через 60 секунд бездействия.
class HubMainScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;
  final ThemeService themeService;

  const HubMainScreen({
    super.key,
    required this.storage,
    required this.sync,
    required this.themeService,
  });

  @override
  State<HubMainScreen> createState() => _HubMainScreenState();
}

class _HubMainScreenState extends State<HubMainScreen> {
  /// -1 = приложения (слева)
  ///  0 = центр
  ///  1 = бюджет (справа)
  ///  2 = смены (сверху)
  ///  3 = погода (снизу)
  int _position = 0;

  /// Таймер возврата в центр
  DateTime _lastInteraction = DateTime.now();
  bool _returningToCenter = false;

  @override
  void initState() {
    super.initState();
    _startIdleWatcher();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _startIdleWatcher() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return false;

      final idle = DateTime.now().difference(_lastInteraction).inSeconds;
      if (idle >= 60 && _position != 0 && !_returningToCenter) {
        _returningToCenter = true;
        _goTo(0);
        await Future.delayed(const Duration(milliseconds: 400));
        _returningToCenter = false;
      }
      return true;
    });
  }

  void _goTo(int pos) {
    if (_position == pos) return;
    _lastInteraction = DateTime.now();
    setState(() => _position = pos);
  }

  /// Обработка свайпов в главном Stack
  void _onSwipe(DragEndDetails details) {
    final v = details.velocity.pixelsPerSecond;
    const threshold = 200.0;

    if (v.dy < -threshold) {
      // свайп вверх → смены
      _goTo(2);
    } else if (v.dy > threshold) {
      // свайп вниз → погода
      _goTo(3);
    } else if (v.dx < -threshold) {
      // свайп влево → бюджет
      _goTo(1);
    } else if (v.dx > threshold) {
      // свайп вправо → приложения
      _goTo(-1);
    }
  }

  /// Строит целевой экран по позиции
  Widget _buildScreen(int position) {
    switch (position) {
      case -1:
        return HubAppsScreen(storage: widget.storage);
      case 1:
        return HubBudgetScreen(
          storage: widget.storage,
          sync: widget.sync,
        );
      case 2:
        return HubShiftsScreen(
          storage: widget.storage,
          sync: widget.sync,
        );
      case 3:
        return HubWeatherScreen(storage: widget.storage);
      case 0:
      default:
        return HubCenterScreen(
          storage: widget.storage,
          sync: widget.sync,
          onOpenApps: () => _goTo(-1),
          onOpenShifts: () => _goTo(2),
          onOpenBudget: () => _goTo(1),
          onOpenWeather: () => _goTo(3),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: _onSwipe,
      onVerticalDragEnd: _onSwipe,
      onTap: () {
        _lastInteraction = DateTime.now();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Основное содержимое — текущий экран
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.96, end: 1.0).animate(animation),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_position),
                child: _buildScreen(_position),
              ),
            ),

            // Индикаторы — точки по краям (показывают, куда свайпнуть)
            _buildEdgeIndicators(cs),
          ],
        ),
      ),
    );
  }

  /// Тонкие «язычки» по краям — показывают возможные направления
  Widget _buildEdgeIndicators(ColorScheme cs) {
    return Stack(
      children: [
        // Верх — смены
        if (_position != 2)
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(child: _edgePill(cs)),
          ),
        // Низ — погода
        if (_position != 3)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(child: _edgePill(cs)),
          ),
        // Лево — приложения
        if (_position != -1)
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(child: _edgePill(cs, vertical: true)),
          ),
        // Право — бюджет
        if (_position != 1)
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(child: _edgePill(cs, vertical: true)),
          ),
      ],
    );
  }

  Widget _edgePill(ColorScheme cs, {bool vertical = false}) {
    return Opacity(
      opacity: 0.35,
      child: Container(
        width: vertical ? 4 : 40,
        height: vertical ? 40 : 4,
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}