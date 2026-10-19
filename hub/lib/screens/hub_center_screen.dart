import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dpad/dpad.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/weather_service.dart';
import '../services/tuya_service.dart';
import '../services/theme_service.dart';
import '../services/update_service.dart';
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

  List<Task> get _activeTasks {
    final list = widget.storage.tasks
        .where((t) => !t.done && !t.archived)
        .toList()
      ..sort((a, b) {
        int rank(String p) {
          if (p == 'high') return 0;
          if (p == 'med') return 1;
          return 2;
        }
        final ra = rank(a.priority), rb = rank(b.priority);
        if (ra != rb) return ra.compareTo(rb);
        return a.order.compareTo(b.order);
      });
    return list;
  }

  List<Purchase> get _activePurchases {
    final list = widget.storage.purchases
        .where((p) => !p.done && !p.missing)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassContainer(
        radius: 32,
        showAllBorder: true,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Настройки', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Оформление'),
              onTap: () {
                Navigator.pop(ctx);
                _showThemePicker();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Как сделать хаб домашним'),
              onTap: () {
                Navigator.pop(ctx);
                _showHomeHint();
              },
            ),
            ListTile(
              leading: const Icon(Icons.tv),
              title: const Text('Режим ТВ'),
              subtitle: const Text('Управление пультом (D-pad)'),
              onTap: () {
                Navigator.pop(ctx);
                // TODO: включение/выключение ТВ-режима (позже)
              },
            ),
            ListTile(
              leading: const Icon(Icons.system_update_alt),
              title: const Text('Проверить обновления'),
              subtitle: Text('Версия ${UpdateService.currentFull}'),
              onTap: () {
                Navigator.pop(ctx);
                // TODO: проверка обновлений
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showHomeHint() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Домашний экран'),
        content: const Text(
          '1. Нажми кнопку «Домой» на планшете\n'
          '2. В списке выбери «Вместе Хаб»\n'
          '3. Поставь галочку «Всегда»\n\n'
          'Теперь кнопка «Домой» будет возвращать в хаб.',
        ),
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
              _showThemePicker();
            },
            child: const Text('Сменить светлую/тёмную'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      Expanded(
                        child: DpadFocusable(
                          autofocus: true,
                          onSelect: _openTasks,
                          effects: [
                            const DpadScaleEffect(scale: 1.03),
                            DpadBorderEffect(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3,
                            ),
                          ],
                          child: _buildTasksBlock(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: DpadFocusable(
                          onSelect: _openPurchases,
                          effects: [
                            const DpadScaleEffect(scale: 1.03),
                            DpadBorderEffect(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3,
                            ),
                          ],
                          child: _buildPurchasesBlock(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: DpadFocusable(
                          onSelect: widget.tuyaService.isConfigured ? _openLights : _showTuyaSetup,
                          effects: [
                            const DpadScaleEffect(scale: 1.03),
                            DpadBorderEffect(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3,
                            ),
                          ],
                          child: _buildLightsBlock(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: DpadFocusable(
                          onSelect: widget.onOpenWeather,
                          effects: [
                            const DpadScaleEffect(scale: 1.03),
                            DpadBorderEffect(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3,
                            ),
                          ],
                          child: _buildClockWeatherBlock(),
                        ),
                      ),
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
          icon: Icon(Icons.settings_outlined, color: cs.onSurfaceVariant, size: 28),
          onPressed: _showLauncherHint,
        ),
      ],
    );
  }

  Widget _buildTasksBlock() {
    final cs = Theme.of(context).colorScheme;
    final tasks = _activeTasks.take(5).toList();

    return GlassContainer(
      radius: 32,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: cs.tertiary, size: 28),
              const SizedBox(width: 12),
              Text(
                'Задачи',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.tertiary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${_activeTasks.length}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: cs.tertiary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.open_in_full, color: cs.onSurfaceVariant, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Text(
                      'Все задачи выполнены',
                      style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final t = tasks[i];
                      final isHigh = t.priority == 'high';
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isHigh ? cs.error : cs.tertiary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              t.text,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchasesBlock() {
    final cs = Theme.of(context).colorScheme;
    final items = _activePurchases.take(5).toList();

    return GlassContainer(
      radius: 32,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_bag_outlined, color: cs.primary, size: 28),
              const SizedBox(width: 12),
              Text(
                'Покупки',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${_activePurchases.length}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.open_in_full, color: cs.onSurfaceVariant, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      'Всё куплено',
                      style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final p = items[i];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: p.takenBy != null ? cs.secondary : cs.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              p.text,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLightsBlock() {
    final cs = Theme.of(context).colorScheme;

    if (!widget.tuyaService.isConfigured) {
      return GlassContainer(
        radius: 32,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: cs.secondary, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Свет',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.settings_outlined, size: 48, color: cs.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text(
                      'Настроить Tuya',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GlassContainer(
      radius: 32,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: cs.secondary, size: 28),
              const SizedBox(width: 12),
              Text(
                'Свет',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              Icon(Icons.open_in_full, color: cs.onSurfaceVariant, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loadingLights
                ? const Center(child: CircularProgressIndicator())
                : _lights.isEmpty
                    ? Center(
                        child: Text('Лампы не найдены',
                            style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant)),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _lights.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final d = _lights[i];
                          return GestureDetector(
                            onTap: () => _toggleLight(d),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: d.isOn ? cs.secondary.withOpacity(0.15) : cs.surface.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: d.isOn ? cs.secondary.withOpacity(0.5) : cs.outline.withOpacity(0.5),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    d.isOn ? Icons.lightbulb : Icons.lightbulb_outline,
                                    size: 20,
                                    color: d.isOn ? cs.secondary : cs.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      d.name,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: cs.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildClockWeatherBlock() {
    final cs = Theme.of(context).colorScheme;
    final now = _now;
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final date = '${now.day}.${now.month}.${now.year}';

    final w = _weather;
    final hasWeather = w?.now != null;

    return GlassContainer(
      radius: 32,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            time,
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              letterSpacing: -2.5,
              height: 0.95,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            date,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          if (hasWeather)
            Row(
              children: [
                Text(w!.now!.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Text(
                  '${w.now!.temperature.round()}°',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    w.now!.description,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(Icons.cloud_outlined, color: cs.secondary, size: 24),
                const SizedBox(width: 12),
                Text(
                  widget.weatherService.hasCity ? 'Загрузка...' : 'Выбери город',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}