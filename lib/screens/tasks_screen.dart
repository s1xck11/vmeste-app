import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import '../models/task.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../widgets/add_task_modal.dart';

/// Экран задач.
/// 
/// Вкладки: «Общий» и «Мой» (личные задачи партнёра).
/// Фильтры: Все / Активные / Важные / Сегодня / Архив.
class TasksScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;

  const TasksScreen({
    super.key,
    required this.storage,
    required this.sync,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String _currentListId = 'common';
  String _filter = 'all';
  final TextEditingController _quickAddController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.sync.onDataChanged = _refresh;
  }

  @override
  void dispose() {
    _quickAddController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  /// Видимые задачи (не показываем чужие личные)
  List<Task> get _visibleTasks {
    final myRole = widget.storage.myPartnerId;
    return widget.storage.tasks.where((t) {
      if (t.deletedAt != null) return false;
      if (t.listId == 'common' || t.listId == 'default') return true;
      if (t.listId == myRole) return true;
      return false;
    }).toList();
  }

  /// Задачи текущего списка
  List<Task> get _currentTasks {
    return _visibleTasks
        .where((t) =>
            t.listId == _currentListId ||
            (_currentListId == 'common' && t.listId == 'default'))
        .toList();
  }

  /// Задачи после фильтра
  List<Task> get _filteredTasks {
    var list = _currentTasks;

    switch (_filter) {
      case 'active':
        list = list.where((t) => !t.done && !t.archived).toList();
        break;
      case 'high':
        list = list
            .where((t) => t.priority == 'high' && !t.done && !t.archived)
            .toList();
        break;
      case 'today':
        final today = _todayKey();
        list = list
            .where((t) => t.deadline == today && !t.archived)
            .toList();
        break;
      case 'archive':
        list = list.where((t) => t.archived).toList();
        break;
      default:
        list = list.where((t) => !t.archived).toList();
    }

    // Сортировка: сначала невыполненные, потом по приоритету
    list.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      const prio = {'high': 0, 'med': 1, 'low': 2};
      final pa = prio[a.priority] ?? 1;
      final pb = prio[b.priority] ?? 1;
      if (pa != pb) return pa.compareTo(pb);
      if (a.deadline.isNotEmpty && b.deadline.isNotEmpty) {
        return a.deadline.compareTo(b.deadline);
      }
      if (a.deadline.isNotEmpty) return -1;
      if (b.deadline.isNotEmpty) return 1;
      return a.order.compareTo(b.order);
    });

    return list;
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  int get _activeCount =>
      _currentTasks.where((t) => !t.done && !t.archived).length;

  // ============ ДОБАВЛЕНИЕ ============

  Future<void> _quickAdd() async {
    final text = _quickAddController.text.trim();
    if (text.isEmpty) return;
    _quickAddController.clear();
    await _openAddModal(defaultText: text);
  }

  Future<void> _openAddModal({String defaultText = ''}) async {
    final result = await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTaskModal(
        listId: _currentListId,
        defaultText: defaultText,
        categories: widget.storage.taskCategories,
        partners: widget.storage.partners,
        currentUserIdGetter: () => widget.storage.currentUserId,
      ),
    );

    if (result != null) {
      final list = widget.storage.tasks;
      list.add(result);
      widget.storage.tasks = list;
      widget.sync.schedulePush();
      _refresh();
    }
  }

  Future<void> _edit(Task t) async {
    final result = await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTaskModal(
        existing: t,
        listId: _currentListId,
        categories: widget.storage.taskCategories,
        partners: widget.storage.partners,
        currentUserIdGetter: () => widget.storage.currentUserId,
      ),
    );

    if (result != null) {
      final list = widget.storage.tasks;
      final idx = list.indexWhere((x) => x.id == result.id);
      if (idx >= 0) list[idx] = result;
      widget.storage.tasks = list;
      widget.sync.schedulePush();
      _refresh();
    }
  }

  void _toggle(Task t) {
    final list = widget.storage.tasks;
    final idx = list.indexWhere((x) => x.id == t.id);
    if (idx < 0) return;

    final item = list[idx];
    item.done = !item.done;
    item.doneAt = item.done ? DateTime.now().millisecondsSinceEpoch : null;
    item.updatedAt = DateTime.now().millisecondsSinceEpoch;
    item.updatedBy = widget.storage.currentUserId;

    // Повторяющиеся задачи — создаём следующую
    if (item.done && item.repeat != 'none' && item.deadline.isNotEmpty) {
      final next = _createNextRepeat(item);
      if (next != null) list.add(next);
    }

    list[idx] = item;
    widget.storage.tasks = list;
    widget.sync.schedulePush();
    _refresh();
  }

  Task? _createNextRepeat(Task parent) {
    try {
      final parts = parent.deadline.split('-');
      if (parts.length != 3) return null;
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );

      DateTime next;
      switch (parent.repeat) {
        case 'daily':
          next = date.add(const Duration(days: 1));
          break;
        case 'weekly':
          next = date.add(const Duration(days: 7));
          break;
        case 'monthly':
          next = DateTime(date.year, date.month + 1, date.day);
          break;
        default:
          return null;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final deadlineStr =
          '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';

      return Task(
        id: now + 1,
        text: parent.text,
        priority: parent.priority,
        category: parent.category,
        assignee: parent.assignee,
        listId: parent.listId,
        deadline: deadlineStr,
        repeat: parent.repeat,
        comment: parent.comment,
        createdAt: now,
        updatedAt: now,
        updatedBy: widget.storage.currentUserId,
        order: parent.order,
      );
    } catch (e) {
      return null;
    }
  }

  void _archive(Task t) {
    final list = widget.storage.tasks;
    final idx = list.indexWhere((x) => x.id == t.id);
    if (idx < 0) return;
    final item = list[idx];
    item.archived = true;
    item.updatedAt = DateTime.now().millisecondsSinceEpoch;
    item.updatedBy = widget.storage.currentUserId;
    list[idx] = item;
    widget.storage.tasks = list;
    widget.sync.schedulePush();
    _refresh();
  }

  void _delete(Task t) {
    final list = widget.storage.tasks;
    list.removeWhere((x) => x.id == t.id);
    final deleted = widget.storage.deletedTaskIds;
    deleted.add(t.id);
    widget.storage.deletedTaskIds = deleted;
    widget.storage.tasks = list;
    widget.sync.schedulePush();
    _refresh();
  }

  // ============ UI ============

  @override
  Widget build(BuildContext context) {
    final myRole = widget.storage.myPartnerId;
    final myName = widget.storage.myName.isNotEmpty
        ? widget.storage.myName
        : 'Мой список';

    final tabs = <Map<String, String>>[
      {'id': 'common', 'label': 'Общий', 'emoji': '👥'},
      if (myRole != null) {'id': myRole, 'label': myName, 'emoji': '👤'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Задачи'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Icon(
                widget.sync.status == 'online'
                    ? Icons.cloud_done
                    : Icons.cloud_off,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Вкладки списков
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: tabs.map((t) {
                    final selected = _currentListId == t['id'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _currentListId = t['id']!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.white
                                : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(t['emoji']!,
                                  style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Text(
                                t['label']!,
                                style: TextStyle(
                                  color: selected
                                      ? AppColors.accent
                                      : Colors.white,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              // Фильтры
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _filterChip('all', 'Все'),
                    _filterChip('active', 'Активные'),
                    _filterChip('high', '🔴 Важные'),
                    _filterChip('today', '📅 Сегодня'),
                    _filterChip('archive', '📦 Архив'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Быстрое добавление
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quickAddController,
                    decoration: InputDecoration(
                      hintText: 'Что сделать?',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (_) => _quickAdd(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 56,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _quickAdd,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Icon(Icons.add, size: 24),
                  ),
                ),
              ],
            ),
          ),

          // Счётчик
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Text(
                  _filteredTasks.isEmpty
                      ? ''
                      : '${_filteredTasks.length} задач · активных $_activeCount',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _openAddModal,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('С деталями'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.info,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),

          // Список
          Expanded(
            child: _filteredTasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('✅', style: TextStyle(fontSize: 60)),
                        const SizedBox(height: 12),
                        Text(
                          _filter == 'archive'
                              ? 'Архив пуст'
                              : 'Задач нет',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _filteredTasks.length,
                    itemBuilder: (_, i) => _buildItem(_filteredTasks[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent
                : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(Task t) {
    const prioColors = {
      'high': Color(0xFFFF3B30),
      'med': Color(0xFFFF9500),
      'low': Color(0xFF34C759),
    };
    final prioColor = prioColors[t.priority] ?? AppColors.textSecondary;
    final cat = widget.storage.taskCategories.firstWhere(
      (c) => c.id == t.category,
      orElse: () => widget.storage.taskCategories.last,
    );

    final isOverdue = t.deadline.isNotEmpty &&
        !t.done &&
        t.deadline.compareTo(_todayKey()) < 0;

    // Имя ответственного
    String assigneeName = '';
    if (t.assignee != 'any') {
      final p = widget.storage.partners.firstWhere(
        (p) => p.id == t.assignee,
        orElse: () => widget.storage.partners.first,
      );
      assigneeName = p.name;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: prioColor, width: 4),
        ),
      ),
      child: InkWell(
        onTap: () => _edit(t),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Чекбокс
              GestureDetector(
                onTap: () => _toggle(t),
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: t.done ? AppColors.success : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: t.done
                          ? AppColors.success
                          : AppColors.textSecondary,
                      width: 2,
                    ),
                  ),
                  child: t.done
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),

              // Контент
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.text,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        decoration:
                            t.done ? TextDecoration.lineThrough : null,
                        color: t.done ? AppColors.textSecondary : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _tag('${cat.emoji} ${cat.label}', null),
                        if (t.priority == 'high')
                          _tag('🔴 Срочно', const Color(0xFFFF3B30)),
                        if (t.deadline.isNotEmpty)
                          _tag(
                            '📅 ${t.deadline}',
                            isOverdue ? const Color(0xFFFF3B30) : null,
                          ),
                        if (assigneeName.isNotEmpty)
                          _tag('👤 $assigneeName', null),
                        if (t.repeat != 'none')
                          _tag(
                            t.repeat == 'daily'
                                ? '🔁 ежедневно'
                                : t.repeat == 'weekly'
                                    ? '🔁 еженедельно'
                                    : '🔁 ежемесячно',
                            null,
                          ),
                        if (t.archived)
                          _tag('📦 Архив', AppColors.success),
                      ],
                    ),
                  ],
                ),
              ),

              // Кнопки
              if (!t.archived && t.done)
                IconButton(
                  onPressed: () => _archive(t),
                  icon: const Icon(Icons.archive_outlined,
                      size: 18, color: AppColors.textSecondary),
                  tooltip: 'В архив',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              IconButton(
                onPressed: () => _delete(t),
                icon: const Icon(Icons.close,
                    size: 18, color: AppColors.textSecondary),
                tooltip: 'Удалить',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, Color? bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg ?? AppColors.accentLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: bg != null ? Colors.white : null,
        ),
      ),
    );
  }
}