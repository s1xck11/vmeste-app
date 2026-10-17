import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/task_category.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../widgets/glass_container.dart';

/// Полноэкранный список задач для хаба.
/// Две колонки: активные слева, выполненные справа.
class HubTasksScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;
  final VoidCallback onClose;

  const HubTasksScreen({
    super.key,
    required this.storage,
    required this.sync,
    required this.onClose,
  });

  @override
  State<HubTasksScreen> createState() => _HubTasksScreenState();
}

class _HubTasksScreenState extends State<HubTasksScreen> {
  List<Task> _tasks = [];
  List<TaskCategory> _categories = [];

  @override
  void initState() {
    super.initState();
    _load();
    widget.sync.addListener(_load);
  }

  @override
  void dispose() {
    widget.sync.removeListener(_load);
    super.dispose();
  }

  void _load() {
    if (!mounted) return;
    setState(() {
      _tasks = widget.storage.tasks;
      _categories = widget.storage.taskCategories;
    });
  }

  String _myName() {
    return widget.storage.myName.isEmpty
        ? (widget.storage.myPartnerId ?? '')
        : widget.storage.myName;
  }

  void _toggleDone(Task t) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = t.done
        ? t.copyWith(done: false, doneAt: null, clearDoneBy: true, updatedAt: now)
        : t.copyWith(
            done: true,
            doneAt: now,
            doneBy: widget.storage.myPartnerId,
            doneByName: _myName(),
            updatedAt: now,
          );
    _replace(updated);
  }

  void _take(Task t) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _replace(t.copyWith(
      takenBy: widget.storage.myPartnerId,
      takenByName: _myName(),
      takenByAt: now,
      updatedAt: now,
    ));
  }

  void _untake(Task t) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _replace(t.copyWith(clearTakenBy: true, updatedAt: now));
  }

  void _replace(Task updated) {
    final list = List<Task>.from(_tasks);
    final i = list.indexWhere((e) => e.id == updated.id);
    if (i >= 0) list[i] = updated;
    widget.storage.tasks = list;
    _load();
    widget.sync.schedulePush();
  }

  TaskCategory _catOf(String id) {
    return _categories.firstWhere(
      (c) => c.id == id,
      orElse: () => TaskCategory(id: id, label: 'Прочее', emoji: '📦', order: 999),
    );
  }

  List<Task> get _active => _tasks
      .where((t) => !t.done && !t.archived)
      .toList()
    ..sort((a, b) {
      int rank(String p) {
        if (p == 'high') return 0;
        if (p == 'med') return 1;
        return 2;
      }
      return rank(a.priority).compareTo(rank(b.priority));
    });

  List<Task> get _done => _tasks
      .where((t) => t.done && !t.archived)
      .toList()
    ..sort((a, b) => (b.doneAt ?? 0).compareTo(a.doneAt ?? 0));

  bool _isMine(Task t) => t.takenBy == widget.storage.myPartnerId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        children: [
          // Шапка
          Row(
            children: [
              Icon(Icons.check_circle, color: cs.tertiary, size: 28),
              const SizedBox(width: 10),
              Text(
                'Задачи',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, color: cs.onSurface, size: 28),
                onPressed: widget.onClose,
                style: IconButton.styleFrom(
                  backgroundColor: cs.surfaceVariant,
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Два столбца
          Expanded(
            child: Row(
              children: [
                // Активные
                Expanded(
                  child: GlassContainer(
                    radius: 28,
                    showAllBorder: true,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            'АКТИВНЫЕ · ${_active.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurfaceVariant,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _active.isEmpty
                              ? Center(child: Text('Все выполнено', style: TextStyle(color: cs.onSurfaceVariant)))
                              : ListView.separated(
                                  itemCount: _active.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (ctx, i) {
                                    final t = _active[i];
                                    return _TaskRow(
                                      task: t,
                                      category: _catOf(t.category),
                                      mine: _isMine(t),
                                      onToggle: () => _toggleDone(t),
                                      onTake: () => _take(t),
                                      onUntake: () => _untake(t),
                                      cs: cs,
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Выполненные
                Expanded(
                  child: GlassContainer(
                    radius: 28,
                    showAllBorder: true,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            'ВЫПОЛНЕНО · ${_done.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurfaceVariant,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _done.isEmpty
                              ? Center(child: Text('Пока ничего', style: TextStyle(color: cs.onSurfaceVariant)))
                              : ListView.separated(
                                  itemCount: _done.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (ctx, i) {
                                    final t = _done[i];
                                    return _TaskRow(
                                      task: t,
                                      category: _catOf(t.category),
                                      mine: _isMine(t),
                                      onToggle: () => _toggleDone(t),
                                      onTake: () {},
                                      onUntake: () {},
                                      cs: cs,
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final Task task;
  final TaskCategory category;
  final bool mine;
  final VoidCallback onToggle;
  final VoidCallback onTake;
  final VoidCallback onUntake;
  final ColorScheme cs;

  const _TaskRow({
    required this.task,
    required this.category,
    required this.mine,
    required this.onToggle,
    required this.onTake,
    required this.onUntake,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = task.done;
    final isTaken = task.takenBy != null && !isDone;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isTaken ? cs.primary.withOpacity(0.4) : cs.outline,
          width: isTaken ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? cs.tertiary : Colors.transparent,
                border: Border.all(
                  color: isDone ? cs.tertiary : cs.outline,
                  width: 2,
                ),
              ),
              child: isDone ? Icon(Icons.check, size: 14, color: cs.onTertiary) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.text,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    decorationColor: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${category.emoji} ${category.label}',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (!isDone && !isTaken)
            TextButton(
              onPressed: onTake,
              child: const Text('Взять', style: TextStyle(fontSize: 12)),
            )
          else if (!isDone && mine)
            TextButton(
              onPressed: onUntake,
              child: Text('Отменить', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}