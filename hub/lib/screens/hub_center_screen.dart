import 'dart:async';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/weather_service.dart';
import '../services/launcher_service.dart';
import '../widgets/glass_container.dart';
import '../models/task.dart';
import '../models/purchase.dart';
import 'hub_tasks_screen.dart';
import 'hub_purchases_screen.dart';
import 'hub_pin_setup_modal.dart';

class HubCenterScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;
  final WeatherService weatherService;
  final LauncherService launcherService;
  final VoidCallback onOpenApps;
  final VoidCallback onOpenShifts;
  final VoidCallback onOpenBudget;
  final VoidCallback onOpenWeather;

  const HubCenterScreen({
    super.key,
    required this.storage,
    required this.sync,
    required this.weatherService,
    required this.launcherService,
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

  @override
  void initState() {
    super.initState();
    widget.sync.addListener(_reload);
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _weather = widget.weatherService.lastKnown;
    _loadWeather();
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
          return FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
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
          return FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Future<void> _showLauncherDialog() async {
    final cs = Theme.of(context).colorScheme;
    final ls = widget.launcherService;

    if (!ls.isEnabled) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Включить режим хаба?'),
          content: const Text(
            'Приложение станет домашним экраном планшета. Кнопка «Домой» будет возвращать в хаб. Чтобы выйти, потребуется PIN-код.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Включить')),
          ],
        ),
      );

      if (ok == true) {
        if (ls.pin.isEmpty) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => HubPinSetupModal(
              launcherService: ls,
              forceSet: true,
            ),
          );
        }
        final success = await ls.enableKiosk();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Режим хаба включён. Нажми «Домой» на планшете.'
                : 'Не удалось включить режим'),
          ),
        );
      }
    } else {
      final pinCtrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ввести PIN'),
          content: TextField(
            controller: pinCtrl,
            obscureText: true,
            keyboardType: TextInputType.number,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, letterSpacing: 6),
            decoration: const InputDecoration(hintText: '••••'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () {
                if (ls.checkPin(pinCtrl.text.trim())) {
                  Navigator.pop(ctx, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Неверный PIN', style: TextStyle(color: cs.error))),
                  );
                }
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (ok == true) {
        await ls.disableKiosk();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Режим хаба выключен')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        children: [
          _buildTopBar(),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: _buildTasksBlock()),
                      const SizedBox(height: 12),
                      Expanded(child: _buildPurchasesBlock()),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: _buildLightsBlock()),
                      const SizedBox(height: 12),
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
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.settings_outlined, color: cs.onSurfaceVariant),
          onPressed: _showLauncherDialog,
        ),
      ],
    );
  }

  Widget _buildTasksBlock() {
    final cs = Theme.of(context).colorScheme;
    final tasks = _activeTasks.take(5).toList();

    return GestureDetector(
      onTap: _openTasks,
      child: GlassContainer(
        radius: 28,
        showAllBorder: true,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_outline, color: cs.tertiary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Задачи',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.tertiary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_activeTasks.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: cs.tertiary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.open_in_full, color: cs.onSurfaceVariant, size: 16),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Text(
                        'Все задачи выполнены',
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: tasks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final t = tasks[i];
                        final isHigh = t.priority == 'high';
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isHigh ? cs.error : cs.tertiary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                t.text,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
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
      ),
    );
  }

  Widget _buildPurchasesBlock() {
    final cs = Theme.of(context).colorScheme;
    final items = _activePurchases.take(5).toList();

    return GestureDetector(
      onTap: _openPurchases,
      child: GlassContainer(
        radius: 28,
        showAllBorder: true,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_bag_outlined, color: cs.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Покупки',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_activePurchases.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.open_in_full, color: cs.onSurfaceVariant, size: 16),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        'Всё куплено',
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final p = items[i];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: p.takenBy != null
                                    ? cs.secondary
                                    : cs.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                p.text,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
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
      ),
    );
  }

  Widget _buildLightsBlock() {
    final cs = Theme.of(context).colorScheme;

    return GlassContainer(
      radius: 28,
      showAllBorder: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: cs.secondary, size: 22),
              const SizedBox(width: 8),
              Text(
                'Свет',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lightbulb_outline,
                      size: 48, color: cs.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(
                    'Подключим на этапе 9',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
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

    return GestureDetector(
      onTap: widget.onOpenWeather,
      child: GlassContainer(
        radius: 28,
        showAllBorder: true,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              time,
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
                letterSpacing: -1.5,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              date,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (hasWeather)
              Row(
                children: [
                  Text(w!.now!.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(
                    '${w.now!.temperature.round()}°',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      w.now!.description,
                      style: TextStyle(
                        fontSize: 13,
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
                  Icon(Icons.cloud_outlined, color: cs.secondary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    widget.weatherService.hasCity
                        ? 'Загрузка...'
                        : 'Выбери город',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}