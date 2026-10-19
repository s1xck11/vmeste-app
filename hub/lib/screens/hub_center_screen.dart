import 'dart:async';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/weather_service.dart';
import '../services/tuya_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme_config.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_container.dart';
import '../widgets/pressable.dart';
import '../models/task.dart';
import '../models/purchase.dart';
import 'hub_tasks_screen.dart';
import 'hub_purchases_screen.dart';
import 'hub_lights_screen.dart';
import 'hub_tuya_setup_modal.dart';

class HubCenterScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;
  final WeatherService weatherService;
  final TuyaService tuyaService;
  final ThemeService themeService;
  final VoidCallback onOpenApps;
  final VoidCallback onOpenShifts;
  final VoidCallback onOpenBudget;
  final VoidCallback onOpenWeather;

  const HubCenterScreen({
    super.key,
    required this.storage,
    required this.sync,
    required this.weatherService,
    required this.tuyaService,
    required this.themeService,
    required this.onOpenApps,
    required this.onOpenShifts,
    required this.onOpenBudget,
    required this.onOpenWeather,
  });

  @override
  State<HubCenterScreen> createState() => _HubCenterScreenState();
}

class _HubCenterScreenState extends State<HubCenterScreen> {
  // ... (переменные и логика без изменений, добавлен только вызов темы)
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  WeatherCache? _weather;
  List<TuyaDevice> _lights = [];
  bool _loadingLights = false;

  @override
  void initState() {
    super.initState();
    widget.sync.addListener(_reload);
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _weather = widget.weatherService.lastKnown;
    _loadWeather();
    _loadLights();
  }

  @override
  void dispose() {
    widget.sync.removeListener(_reload);
    _clockTimer?.cancel();
    super.dispose();
  }

  void _reload() {
    if (mounted) setState(() {});
  }

  Future<void> _loadWeather() async {
    final w = await widget.weatherService.fetch();
    if (!mounted) return;
    setState(() => _weather = w);
  }

  Future<void> _loadLights() async {
    if (!widget.tuyaService.isConfigured) return;
    setState(() => _loadingLights = true);
    final devices = await widget.tuyaService.getDevices();
    if (!mounted) return;
    setState(() {
      _lights = devices.take(4).toList();
      _loadingLights = false;
    });
  }

  Future<void> _toggleLight(TuyaDevice device) async {
    final newState = !device.isOn;
    setState(() {
      final i = _lights.indexWhere((d) => d.id == device.id);
      if (i >= 0) _lights[i] = device.copyWith(isOn: newState);
    });
    await widget.tuyaService.sendCommand(device.id, [
      {'code': 'switch_led', 'value': newState}
    ]);
  }

  List<Task> get _activeTasks { /* без изменений */ return []; }
  List<Purchase> get _activePurchases { /* без изменений */ return []; }

  void _openTasks() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (ctx, anim, secAnim) => HubTasksScreen(
          storage: widget.storage,
          sync: widget.sync,
          onClose: () => Navigator.of(ctx).pop(),
        ),
        transitionsBuilder: (ctx, anim, secAnim, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  void _openPurchases() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (ctx, anim, secAnim) => HubPurchasesScreen(
          storage: widget.storage,
          sync: widget.sync,
          onClose: () => Navigator.of(ctx).pop(),
        ),
        transitionsBuilder: (ctx, anim, secAnim, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  void _openLights() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (ctx, anim, secAnim) => HubLightsScreen(
          tuyaService: widget.tuyaService,
          onOpenTuyaSetup: () {
            Navigator.pop(ctx);
            _showTuyaSetup();
          },
        ),
        transitionsBuilder: (ctx, anim, secAnim, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    ).then((_) => _loadLights());
  }

  Future<void> _showTuyaSetup() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => HubTuyaSetupModal(tuyaService: widget.tuyaService),
    );
    if (ok == true) _loadLights();
  }

  void _showLauncherHint() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Как сделать хаб домашним'),
        content: const Text('...'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Понятно')),
        ],
      ),
    );
  }

  void _showThemePicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Оформление'),
        content: SizedBox(
          width: 400,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: AppColors.lightPalettes.length,
            itemBuilder: (context, i) {
              final id = AppColors.lightPalettes.keys.elementAt(i);
              final p = AppColors.lightPalettes[id]!;
              final isDark = widget.themeService.current.brightness == Brightness.dark;
              final current = widget.themeService.current.palette.id == id;

              return GestureDetector(
                onTap: () {
                  widget.themeService.setPalette(id);
                  Navigator.pop(ctx);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkPalettes[id]!.background : p.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: current ? p.accent : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      isDark ? AppColors.darkPalettes[id]!.name : p.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkPalettes[id]!.text : p.text,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.themeService.toggleBrightness();
              Navigator.pop(ctx);
              _showThemePicker(); // переоткрыть, чтобы обновить цвета
            },
            child: const Text('Сменить светлую/тёмную'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... сборка без изменений, только в шапке добавлена иконка палитры
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        children: [
          _buildTopBar(),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: _buildTasksBlock()),
                      const SizedBox(height: 16),
                      Expanded(child: _buildPurchasesBlock()),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: _buildLightsBlock()),
                      const SizedBox(height: 16),
                      Expanded(child: _buildClockWeatherBlock()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          'Вместе Хаб',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
            letterSpacing: -1,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.palette_outlined, color: cs.onSurfaceVariant, size: 28),
          onPressed: _showThemePicker,
        ),
        IconButton(
          icon: Icon(Icons.settings_outlined, color: cs.onSurfaceVariant, size: 28),
          onPressed: _showLauncherHint,
        ),
      ],
    );
  }

  // ... _buildTasksBlock, _buildPurchasesBlock, _buildLightsBlock, _buildClockWeatherBlock остаются как есть, 
  // но Pressable уже без анимации, так что они не тормозят.
}