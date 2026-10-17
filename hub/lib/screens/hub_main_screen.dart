import 'package:flutter/material.dart';
import 'package:flutter_device_apps/flutter_device_apps.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/theme_service.dart';
import '../services/weather_service.dart';
import '../services/apps_service.dart';
import '../services/launcher_service.dart';
import 'hub_center_screen.dart';
import 'hub_apps_screen.dart';
import 'hub_shifts_screen.dart';
import 'hub_budget_screen.dart';
import 'hub_weather_screen.dart';

class HubMainScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;
  final ThemeService themeService;
  final WeatherService weatherService;
  final AppsService appsService;
  final LauncherService launcherService;

  const HubMainScreen({
    super.key,
    required this.storage,
    required this.sync,
    required this.themeService,
    required this.weatherService,
    required this.appsService,
    required this.launcherService,
  });

  @override
  State<HubMainScreen> createState() => _HubMainScreenState();
}

class _HubMainScreenState extends State<HubMainScreen> {
  int _position = 0;
  DateTime _lastInteraction = DateTime.now();
  bool _returningToCenter = false;

  @override
  void initState() {
    super.initState();
    _startIdleWatcher();
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

  void _onSwipe(DragEndDetails details) {
    final v = details.velocity.pixelsPerSecond;
    const threshold = 300.0;

    final absX = v.dx.abs();
    final absY = v.dy.abs();
    final isHorizontal = absX > absY;

    if (isHorizontal) {
      if (absX < threshold) return;
      if (v.dx > 0) {
        if (_position == 1) _goTo(0);
        else if (_position == 0) _goTo(-1);
        else if (_position == 2 || _position == 3) _goTo(0);
      } else {
        if (_position == -1) _goTo(0);
        else if (_position == 0) _goTo(1);
        else if (_position == 2 || _position == 3) _goTo(0);
      }
    } else {
      if (absY < threshold) return;
      if (v.dy < 0) {
        if (_position == 3) _goTo(0);
        else if (_position == 0) _goTo(2);
        else if (_position == -1 || _position == 1) _goTo(0);
      } else {
        if (_position == 2) _goTo(0);
        else if (_position == 0) _goTo(3);
        else if (_position == -1 || _position == 1) _goTo(0);
      }
    }
  }

  Future<void> _launchApp(String packageName) async {
    try {
      await FlutterDeviceApps.launchApp(packageName);
    } catch (_) {}
  }

  Widget _buildScreen(int position) {
    switch (position) {
      case -1:
        return HubAppsScreen(
          storage: widget.storage,
          appsService: widget.appsService,
          onLaunchApp: _launchApp,
        );
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
        return HubWeatherScreen(
          storage: widget.storage,
          weatherService: widget.weatherService,
        );
      case 0:
      default:
        return HubCenterScreen(
          storage: widget.storage,
          sync: widget.sync,
          weatherService: widget.weatherService,
          launcherService: widget.launcherService,
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
            _buildEdgeIndicators(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildEdgeIndicators(ColorScheme cs) {
    return Stack(
      children: [
        if (_position != 2)
          Positioned(top: 8, left: 0, right: 0, child: Center(child: _edgePill(cs))),
        if (_position != 3)
          Positioned(bottom: 8, left: 0, right: 0, child: Center(child: _edgePill(cs))),
        if (_position != -1)
          Positioned(left: 8, top: 0, bottom: 0, child: Center(child: _edgePill(cs, vertical: true))),
        if (_position != 1)
          Positioned(right: 8, top: 0, bottom: 0, child: Center(child: _edgePill(cs, vertical: true))),
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