import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/task.dart';
import '../models/task_category.dart';
import '../models/partner.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/theme_service.dart';
import '../widgets/modern_app_bar.dart';
import '../widgets/add_task_modal.dart';
import '../widgets/note_card.dart';
import '../widgets/note_modal.dart';
import '../widgets/status_line.dart';
import 'categories_editor_screen.dart';

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
  Set<String> _collapsed = {};

  List<Task> _tasks = [];
  List<TaskCategory> _categories = [];
  List<Partner> _partners = [];

  @override
  void initState() {
    super.initState();
    _loadCollapsed();
    _load();
    widget.sync.addListener(_load);
  }

  @override
  void dispose() {
    widget.sync.removeListener(_load);
    _quickController.dispose();
    super.dispose();
  }

  void _loadCollapsed() {
    final box = Hive.box('vmeste_data');
    final raw = box.get('collapsed_categories_tasks');
    if (raw != null) {
      _collapsed = (raw as List).cast<String>().toSet();
    }
  }

  void _saveCollapsed() {
    Hive.box('vmeste_data').put('collapsed_categories_tasks', _collapsed.toList());
  }

  void _toggleCollapsed(String id) {
    setState(() {
      if (_collapsed.contains(id)) {
        _collapsed.remove(id);
      } else {
        _collapsed.add(id);
      }
      _saveCollapsed();
    });
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
      category: 'home',
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
    widget.storage.tasks = List<Task>.from(_tasks)..add(t);
    _quickController.clear();
    FocusScope.of(context).unfocus();
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
          widget.storage.tasks = List<Task>.from(_tasks)..add(enriched);
          _load();
          widget.sync.schedulePush();
        },
      ),
    );
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

  void _openNoteModal(Task t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NoteModal(
        title: t.text,
        subtitle: t.deadline.isNotEmpty ? '📅 до ${t.deadline}' : null,
        content: t.createdByName != null || t.takenByName != null || t.doneByName != null
            ? StatusLine(
                done: t.done,
                doneByName: t.doneByName,
                doneAt: t.doneAt,
                takenByName: t.takenByName,
                takenByAt: t.takenByAt,
                createdByName: t.createdByName,
                createdByAt: t.createdByAt,
              )
            : null,
        actionButton: t.done
            ? null
            : ElevatedButton.icon(
                onPressed: () {
                  _toggleDone(t);
                  Navigator.pop(ctx);
                },
                icon: const Icon(Icons.check),
                label: const Text('Выполнено'),
              ),
        onEdit: () {
          Navigator.pop(ctx);
          _openEditModal(t);
        },
        onDelete: () {
          Navigator.pop(ctx);
          _delete(t);
        },
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }

  void _toggleDone(Task t) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (t.done) {
      _replace(t.copyWith(done: false, doneAt: null, clearDoneBy: true, updatedAt: now));
    } else {
      _replace(t.copyWith(
        done: true,
        doneAt: now,
        doneBy: widget.storage.myPartnerId,
        doneByName: _myName(),
        updatedAt: now,
      ));
    }
  }

  void _delete(Task t) {
    widget.storage.tasks = List<Task>.from(_tasks)..removeWhere((e) => e.id == t.id);
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

  List<Task> get _activeTasks => _tasks.where((t) => !t.done && !t.archived).toList();

  Map<String, List<Task>> get _groupedByCategory {
    final map = <String, List<Task>>{};
    for (final t in _activeTasks) {
      map.putIfAbsent(t.category, () => []).add(t);
    }
    return map;
  }

  TaskCategory _categoryOf(String id) {
    return _categories.firstWhere(
      (c) => c.id == id,
      orElse: () => TaskCategory(id: id, label: 'Прочее', emoji: '📦', order: 999),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final grouped = _groupedByCategory;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          ModernAppBar(
            title: 'Задачи',
            onAvatarTap: widget.onAvatarTap,
            avatarEmoji: widget.storage.myAvatar,
            actions: [
              IconButton(
                tooltip: 'Категории',
                icon: Icon(Icons.tune, color: cs.primary, size: 22),
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CategoriesEditorScreen(
                      storage: widget.storage,
                      sync: widget.sync,
                      kind: CategoryKind.task,
                    ),
                  ));
                  _load();
                },
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              color: cs.primary,
              backgroundColor: cs.surface,
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildQuickAdd(cs)),
                  if (_activeTasks.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyTasks(),
                    )
                  else
                    ...grouped.entries.map((entry) {
                      final cat = _categoryOf(entry.key);
                      final isCollapsed = _collapsed.contains(entry.key);
                      return SliverToBoxAdapter(
                        child: _buildCategorySection(cat, entry.value, isCollapsed, cs),
                      );
                    }),
                  const SliverToBoxAdapter(child: SizedBox(height: 160)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    TaskCategory cat,
    List<Task> items,
    bool isCollapsed,
    ColorScheme cs,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _toggleCollapsed(cat.id),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  Text('${cat.emoji} ', style: const TextStyle(fontSize: 16)),
                  Text(
                    cat.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurfaceVariant,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('· ${items.length}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  const Spacer(),
                  Icon(isCollapsed ? Icons.expand_more : Icons.expand_less,
                      color: cs.onSurfaceVariant, size: 22),
                ],
              ),
            ),
          ),
          if (!isCollapsed) ...[
            const SizedBox(height: 8),
            MasonryGridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final t = items[i];
                return NoteCard(
                  title: t.text,
                  subtitle: t.deadline.isNotEmpty ? '📅 ${t.deadline}' : null,
                  isHighPriority: t.priority == 'high',
                  onTap: () => _openNoteModal(t),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickAdd(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
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
                prefixIcon: Icon(Icons.check_circle_outline, color: cs.onSurfaceVariant, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 56, width: 56,
            child: ElevatedButton(
              onPressed: _quickAdd,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
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
          Text('Задач нет', style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}