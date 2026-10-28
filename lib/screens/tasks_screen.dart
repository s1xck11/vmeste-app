// lib/screens/tasks_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
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
  String? _selectedCategory;

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
    _quickController.dispose();
    super.dispose();
  }

  void _load() {
    if (!mounted) return;
    setState(() {
      _tasks = widget.storage.tasks;
      _categories = widget.storage.taskCategories;
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
        partners: widget.storage.partners,
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
        partners: widget.storage.partners,
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
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (t.comment.isNotEmpty) ...[
              Text(
                t.comment,
                style: TextStyle(fontSize: 15, color: cs.onSurface, height: 1.5),
              ),
              const SizedBox(height: 16),
            ],
            if (t.createdByName != null || t.takenByName != null || t.doneByName != null)
              StatusLine(
                done: t.done,
                doneByName: t.doneByName,
                doneAt: t.doneAt,
                takenByName: t.takenByName,
                takenByAt: t.takenByAt,
                createdByName: t.createdByName,
                createdByAt: t.createdByAt,
              ),
          ],
        ),
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

  List<Task> get _filteredTasks {
    var list = _activeTasks;
    if (_selectedCategory != null) {
      list = list.where((t) => t.category == _selectedCategory).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
                  SliverToBoxAdapter(child: _buildCategoryFilter(cs)),
                  if (_filteredTasks.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyTasks(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 160),
                      sliver: SliverMasonryGrid.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childCount: _filteredTasks.length,
                        itemBuilder: (ctx, i) {
                          final t = _filteredTasks[i];
                          return NoteCard(
                            title: t.text,
                            subtitle: t.deadline.isNotEmpty ? '📅 ${t.deadline}' : null,
                            isHighPriority: t.priority == 'high',
                            onTap: () => _openNoteModal(t),
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
    );
  }

  Widget _buildCategoryFilter(ColorScheme cs) {
    final categories = _categories.where((c) =>
      _activeTasks.any((t) => t.category == c.id)
    ).toList();

    if (categories.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) {
            if (i == 0) {
              final selected = _selectedCategory == null;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = null),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? cs.primary : cs.surfaceVariant,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: selected ? cs.primary : cs.outline.withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    'Все',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? cs.onPrimary : cs.onSurface,
                    ),
                  ),
                ),
              );
            }
            final cat = categories[i - 1];
            final selected = _selectedCategory == cat.id;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? cs.primary : cs.surfaceVariant,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: selected ? cs.primary : cs.outline.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(cat.emoji, style: const TextStyle(fontSize: 16)),
                    if (selected) ...[
                      const SizedBox(width: 6),
                      Text(
                        cat.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.onPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuickAdd(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceVariant,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _quickController,
                onSubmitted: (_) => _quickAdd(),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Что нужно сделать?',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.check_circle_outline, color: cs.primary, size: 24),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_forward, color: cs.onPrimary, size: 20),
                onPressed: _quickAdd,
              ),
            ),
          ],
        ),
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.task_alt, size: 56, color: cs.primary),
          ),
          const SizedBox(height: 20),
          Text(
            'Все задачи выполнены!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Или добавь новую, используя поле выше',
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
