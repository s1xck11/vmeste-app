// lib/screens/tasks_screen.dart

import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/task_category.dart';
import '../models/partner.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/theme_service.dart';
import '../widgets/modern_app_bar.dart';
import '../widgets/add_task_modal.dart';
import '../widgets/status_line.dart';

class TasksScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;
  final ThemeService themeService;
  final VoidCallback onAvatarTap;

  const TasksScreen({
    super.key,
    required this.storage,
    required this.sync,
    required this.themeService,
    required this.onAvatarTap,
  });

  @override
  State<TasksScreen> createState() => TasksScreenState();
}

class TasksScreenState extends State<TasksScreen> {
  final _quickController = TextEditingController();
  String _filter = 'all';

  List<Task> _tasks = [];
  List<TaskCategory> _categories = [];
  List<Partner> _partners = [];

  @override
  void initState() {
    super.initState();
    _load();
    widget.sync.addListener(_load);
  }

  @override
  void dispose() {
    widget.sync.removeListener(_load);
    _quickController.dispose();
    super.dispose();
  }

  void _load() {
    if (!mounted) return;
    setState(() {
      _tasks = widget.storage.tasks;
      _categories = widget.storage.taskCategories;
      _partners = widget.storage.partners;
    });
  }

  Future<void> _refresh() async {
    await widget.sync.forcePullNow();
    _load();
  }

  String _myName() {
    return widget.storage.myName.isEmpty
        ? (widget.storage.myPartnerId ?? '')
        : widget.storage.myName;
  }

  void _quickAdd() {
    final text = _quickController.text.trim();
    if (text.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final t = Task(
      id: now,
      text: text,
      done: false,
      priority: 'med',
      category: 'home',
      assignee: 'any',
      deadline: '',
      repeat: 'none',
      comment: '',
      order: _tasks.length,
      archived: false,
      createdAt: now,
      updatedAt: now,
      createdBy: widget.storage.myPartnerId,
      createdByName: _myName(),
      createdByAt: now,
    );
    final list = List<Task>.from(_tasks)..add(t);
    widget.storage.tasks = list;
    _quickController.clear();
    FocusScope.of(context).unfocus();
    _load();
    widget.sync.schedulePush();
  }

  void _take(Task t) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = t.copyWith(
      takenBy: widget.storage.myPartnerId,
      takenByName: _myName(),
      takenByAt: now,
      updatedAt: now,
    );
    _replace(updated);
  }

  void _untake(Task t) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _replace(t.copyWith(clearTakenBy: true, updatedAt: now));
  }

  void _toggleDone(Task t) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (t.done) {
      _replace(t.copyWith(
        done: false,
        doneAt: null,
        clearDoneBy: true,
        updatedAt: now,
      ));
    } else {
      _replace(t.copyWith(
        done: true,
        doneAt: now,
        doneBy: widget.storage.myPartnerId,
        doneByName: _myName(),
        takenBy: t.takenBy ?? widget.storage.myPartnerId,
        takenByName: t.takenByName ?? _myName(),
        takenByAt: t.takenByAt ?? now,
        updatedAt: now,
      ));
    }
  }

  void _archive(Task t) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _replace(t.copyWith(archived: true, updatedAt: now));
  }

  void _delete(Task t) {
    final list = List<Task>.from(_tasks)..removeWhere((e) => e.id == t.id);
    widget.storage.tasks = list;
    _load();
    widget.sync.schedulePush();
  }

  void _replace(Task updated) {
    final list = List<Task>.from(_tasks);
    final i = list.indexWhere((e) => e.id == updated.id);
    if (i >= 0) list[i] = updated;
    widget.storage.tasks = list;
    _load();
    widget.sync.schedulePush();
  }

  void _openAddModal() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTaskModal(
        categories: _categories,
        partners: _partners,
        onSave: (t) {
          final now = DateTime.now().millisecondsSinceEpoch;
          final enriched = t.copyWith(
            createdBy: widget.storage.myPartnerId,
            createdByName: _myName(),
            createdByAt: now,
          );
          final list = List<Task>.from(_tasks)..add(enriched);
          widget.storage.tasks = list;
          _load();
          widget.sync.schedulePush();
        },
      ),
    );
  }

  /// Публичный — для вызова из MainScreen через GlobalKey
  void openAddModal() {
    _openAddModal();
  }

  void _openEditModal(Task t) {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTaskModal(
        categories: _categories,
        partners: _partners,
        initialTask: t,
        onSave: _replace,
      ),
    );
  }

  List<Task> get _filtered {
    final now = DateTime.now();
    final today = '${now.year}-${_two(now.month)}-${_two(now.day)}';
    final base = _tasks.where((t) => !t.archived).toList();
    switch (_filter) {
      case 'active':
        return base.where((t) => !t.done).toList();
      case 'high':
        return base.where((t) => t.priority == 'high' && !t.done).toList();
      case 'today':
        return base.where((t) => t.deadline == today).toList();
      case 'archive':
        return _tasks.where((t) => t.archived).toList();
      default:
        return base;
    }
  }

  String _two(int n) => n < 10 ? '0$n' : '$n';

  int get _doneToday {
    final now = DateTime.now();
    final today = '${now.year}-${_two(now.month)}-${_two(now.day)}';
    return _tasks.where((t) {
      if (t.doneAt == null) return false;
      final d = DateTime.fromMillisecondsSinceEpoch(t.doneAt!);
      return '${d.year}-${_two(d.month)}-${_two(d.day)}' == today;
    }).length;
  }

  int get _totalToday {
    final now = DateTime.now();
    final today = '${now.year}-${_two(now.month)}-${_two(now.day)}';
    return _doneToday +
        _tasks
            .where((t) => !t.done && !t.archived && t.deadline == today)
            .length;
  }

  bool _isMine(Task t) => t.takenBy == widget.storage.myPartnerId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final list = _filtered;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          ModernAppBar(
            title: 'Задачи',
            onAvatarTap: widget.onAvatarTap,
            avatarEmoji: widget.storage.myAvatar,
          ),
          Expanded(
            child: RefreshIndicator(
              color: cs.primary,
              backgroundColor: cs.surface,
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildProgress(cs)),
                  SliverToBoxAdapter(child: _buildFilters(cs)),
                  SliverToBoxAdapter(child: _buildQuickAdd(cs)),
                  if (list.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyTasks(),
                    )
                  else
                    SliverList.builder(
                      itemCount: list.length,
                      itemBuilder: (ctx, i) => Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                        child: _TaskTile(
                          task: list[i],
                          category: _categories.firstWhere(
                            (c) => c.id == list[i].category,
                            orElse: () => TaskCategory(
                                id: list[i].category,
                                label: 'Прочее',
                                emoji: '📦',
                                order: 999),
                          ),
                          assigneeName: _assigneeName(list[i].assignee),
                          mine: _isMine(list[i]),
                          onToggleDone: () => _toggleDone(list[i]),
                          onArchive: () => _archive(list[i]),
                          onDelete: () => _delete(list[i]),
                          onTap: () => _openEditModal(list[i]),
                          onTake: () => _take(list[i]),
                          onUntake: () => _untake(list[i]),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 180)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _assigneeName(String id) {
    if (id == 'any' || id.isEmpty) return null;
    final p = _partners.where((x) => x.id == id).toList();
    if (p.isEmpty) return null;
    return p.first.name;
  }

  Widget _buildProgress(ColorScheme cs) {
    if (_totalToday == 0) return const SizedBox.shrink();
    final ratio = _doneToday / _totalToday;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Выполнено сегодня',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              const Spacer(),
              Text('$_doneToday из $_totalToday',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cs.primary)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: cs.surfaceVariant,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(ColorScheme cs) {
    final filters = [
      ('all', 'Все'),
      ('active', 'Активные'),
      ('high', 'Важные'),
      ('today', 'Сегодня'),
      ('archive', 'Архив'),
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final (id, label) = filters[i];
          final sel = id == _filter;
          return GestureDetector(
            onTap: () => setState(() => _filter = id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: sel ? cs.primary : cs.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: sel ? cs.onPrimary : cs.onSurface,
                    )),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickAdd(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _quickController,
              onSubmitted: (_) => _quickAdd(),
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'Что сделать?',
                filled: true,
                fillColor: cs.surfaceVariant,
                prefixIcon: Icon(Icons.check_circle_outline,
                    color: cs.onSurfaceVariant, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 56,
            width: 56,
            child: ElevatedButton(
              onPressed: _quickAdd,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final Task task;
  final TaskCategory category;
  final String? assigneeName;
  final bool mine;
  final VoidCallback onToggleDone;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final VoidCallback onTake;
  final VoidCallback onUntake;

  const _TaskTile({
    required this.task,
    required this.category,
    required this.assigneeName,
    required this.mine,
    required this.onToggleDone,
    required this.onArchive,
    required this.onDelete,
    required this.onTap,
    required this.onTake,
    required this.onUntake,
  });

  Color _priorityColor(ColorScheme cs) {
    switch (task.priority) {
      case 'high':
        return cs.error;
      case 'low':
        return cs.tertiary;
      default:
        return cs.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDone = task.done;
    final prioColor = _priorityColor(cs);
    final isTaken = task.takenBy != null && !isDone;

    return Dismissible(
      key: Key('task_${task.id}'),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        decoration: BoxDecoration(
          color: cs.tertiary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(Icons.archive_outlined, color: cs.tertiary),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: cs.error.withOpacity(0.2),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(Icons.delete_outline, color: cs.error),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onArchive();
        } else {
          onDelete();
        }
        return false;
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isTaken
                        ? cs.primary.withOpacity(0.5)
                        : cs.outline,
                    width: isTaken ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: onToggleDone,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        margin: const EdgeInsets.only(top: 2),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone ? cs.tertiary : Colors.transparent,
                          border: Border.all(
                            color: isDone ? cs.tertiary : cs.outline,
                            width: 2,
                          ),
                        ),
                        child: isDone
                            ? Icon(Icons.check,
                                size: 15, color: cs.onTertiary)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),
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
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _tag('${category.emoji} ${category.label}',
                                  cs.surface, cs.onSurfaceVariant),
                              if (task.priority == 'high')
                                _tag('🔴 Важно',
                                    cs.error.withOpacity(0.15), cs.error),
                              if (task.deadline.isNotEmpty)
                                _tag('📅 ${task.deadline}', cs.surface,
                                    cs.onSurfaceVariant),
                              if (assigneeName != null)
                                _tag('👤 $assigneeName', cs.surface,
                                    cs.onSurfaceVariant),
                            ],
                          ),
                          const SizedBox(height: 8),
                          StatusLine(
                            done: isDone,
                            doneByName: task.doneByName,
                            doneAt: task.doneAt,
                            takenByName: task.takenByName,
                            takenByAt: task.takenByAt,
                            createdByName: task.createdByName,
                            createdByAt: task.createdByAt,
                          ),
                        ],
                      ),
                    ),
                    if (!isDone)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 2),
                        child: _TakeButton(
                          taken: isTaken,
                          mine: mine,
                          onTake: onTake,
                          onUntake: onUntake,
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                top: 10,
                bottom: 10,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: prioColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, color: fg, fontWeight: FontWeight.w500)),
    );
  }
}

class _TakeButton extends StatelessWidget {
  final bool taken;
  final bool mine;
  final VoidCallback onTake;
  final VoidCallback onUntake;

  const _TakeButton({
    required this.taken,
    required this.mine,
    required this.onTake,
    required this.onUntake,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!taken) {
      return GestureDetector(
        onTap: onTake,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text('Взять',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.primary)),
        ),
      );
    }

    if (mine) {
      return GestureDetector(
        onTap: onUntake,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline),
          ),
          child: Text('Отменить',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.lock_outline, size: 14, color: cs.primary),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt, size: 64, color: cs.tertiary),
          const SizedBox(height: 16),
          Text('Задач нет',
              style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}