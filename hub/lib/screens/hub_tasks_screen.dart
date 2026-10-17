import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/task_category.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../widgets/glass_container.dart';
import '../widgets/pressable.dart';

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
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: cs.tertiary, size: 32),
              const SizedBox(width: 14),
              Text(
                'Задачи',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                  letterSpacing: -1,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, color: cs.onSurface, size: 32),
                onPressed: widget.onClose,
                style: IconButton.styleFrom(
                  backgroundColor: cs.surfaceVariant,
                  padding: const EdgeInsets.all(14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: GlassContainer(
                    radius: 32,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Text(
                            'АКТИВНЫЕ · ${_active.length}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: cs.onSurfaceVariant,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _active.isEmpty
                              ? Center(child: Text('Все выполнено', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)))
                              : ListView.separated(
                                  itemCount: _active.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
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
                const SizedBox(width: 20),
                Expanded(
                  child: GlassContainer(
                    radius: 32,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Text(
                            'ВЫПОЛНЕНО · ${_done.length}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: cs.onSurfaceVariant,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _done.isEmpty
                              ? Center(child: Text('Пока ничего', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)))
                              : ListView.separated(
                                  itemCount: _done.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
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

    return Pressable(
      onTap: onToggle, // В iOS тап по карточке часто отмечает выполнение
      enableHaptic: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isTaken ? cs.primary.withOpacity(0.5) : cs.outline.withOpacity(0.5),
            width: isTaken ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? cs.tertiary : Colors.transparent,
                border: Border.all(
                  color: isDone ? cs.tertiary : cs.outline,
                  width: 2,
                ),
              ),
              child: isDone ? Icon(Icons.check, size: 16, color: cs.onTertiary) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      decorationColor: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${category.emoji} ${category.label}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (!isDone && !isTaken)
              TextButton(
                onPressed: onTake,
                style: TextButton.styleFrom(
                  foregroundColor: cs.primary,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                child: const Text('Взять'),
              )
            else if (!isDone && mine)
              TextButton(
                onPressed: onUntake,
                style: TextButton.styleFrom(
                  foregroundColor: cs.onSurfaceVariant,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                child: const Text('Отменить'),
              ),
          ],
        ),
      ),
    );
  }
}