import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../widgets/glass_container.dart';
import '../models/task.dart';
import '../models/purchase.dart';

/// Главный (центральный) экран хаба.
/// 
/// Левая половина:
///   - сверху: блок Задачи (2×2)
///   - снизу: блок Покупки (2×2)
/// 
/// Правая половина:
///   - сверху: блок Свет (пока заглушка)
///   - снизу: блок Время + Погода
class HubCenterScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;
  final VoidCallback onOpenApps;
  final VoidCallback onOpenShifts;
  final VoidCallback onOpenBudget;
  final VoidCallback onOpenWeather;

  const HubCenterScreen({
    super.key,
    required this.storage,
    required this.sync,
    required this.onOpenApps,
    required this.onOpenShifts,
    required this.onOpenBudget,
    required this.onOpenWeather,
  });

  @override
  State<HubCenterScreen> createState() => _HubCenterScreenState();
}

class _HubCenterScreenState extends State<HubCenterScreen> {
  @override
  void initState() {
    super.initState();
    widget.sync.addListener(_reload);
  }

  @override
  void dispose() {
    widget.sync.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (mounted) setState(() {});
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        children: [
          // Верхняя панель — маленькая шапка
          _buildTopBar(),
          const SizedBox(height: 16),
          // Основная сетка 2×2
          Expanded(
            child: Row(
              children: [
                // Левая половина
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _buildTasksBlock(),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _buildPurchasesBlock(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Правая половина
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _buildLightsBlock(),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _buildClockWeatherBlock(),
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
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const Spacer(),
        // Кнопка настроек — позже подключим
        IconButton(
          icon: Icon(Icons.settings_outlined, color: cs.onSurfaceVariant),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Настройки появятся позже')),
            );
          },
        ),
      ],
    );
  }

  /// Блок «Задачи» — 4-6 активных
  Widget _buildTasksBlock() {
    final cs = Theme.of(context).colorScheme;
    final tasks = _activeTasks.take(5).toList();

    return GlassContainer(
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
              Text(
                '${_activeTasks.length}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.tertiary,
                ),
              ),
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
    );
  }

  /// Блок «Покупки» — активные
  Widget _buildPurchasesBlock() {
    final cs = Theme.of(context).colorScheme;
    final items = _activePurchases.take(5).toList();

    return GlassContainer(
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
              Text(
                '${_activePurchases.length}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
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
    );
  }

  /// Блок «Свет» — пока заглушка
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

  /// Блок «Время + Погода» — компакт
  Widget _buildClockWeatherBlock() {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final date = '${now.day}.${now.month}.${now.year}';

    return GlassContainer(
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
          Row(
            children: [
              Icon(Icons.cloud_outlined, color: cs.info, size: 22),
              const SizedBox(width: 8),
              Text(
                'Погода — этап 4',
                style: TextStyle(
                  fontSize: 13,
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