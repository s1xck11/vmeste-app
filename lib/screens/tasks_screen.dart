// lib/screens/tasks_screen.dart

import 'dart:math' as math;
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

class _TaskParse {
  final String text;
  final String priority;
  final String deadline;
  const _TaskParse(this.text, this.priority, this.deadline);
}

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
  String _viewMode = 'grid';

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
    return widget.storage.myName.isEmpty ? (widget.storage.myPartnerId ?? '') : widget.storage.myName;
  }

  String _two(int n) => n < 10 ? '0$n' : '$n';

  String _dateKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  // ==================== УМНЫЙ ВВОД ====================

  _TaskParse _parseSmart(String input) {
    var rest = input.trim();
    String priority = 'med';
    String deadline = '';

    if (RegExp(r'(^|\s)(!|важно|срочно)(\s|$)', caseSensitive: false).hasMatch(rest)) {
      priority = 'high';
      rest = rest.replaceAll(RegExp(r'(^|\s)(!|важно|срочно)(\s|$)', caseSensitive: false), ' ');
    }

    final now = DateTime.now();
    if (RegExp(r'(^|\s)послезавтра(\s|$)', caseSensitive: false).hasMatch(rest)) {
      deadline = _dateKey(now.add(const Duration(days: 2)));
      rest = rest.replaceAll(RegExp(r'(^|\s)послезавтра(\s|$)', caseSensitive: false), ' ');
    } else if (RegExp(r'(^|\s)завтра(\s|$)', caseSensitive: false).hasMatch(rest)) {
      deadline = _dateKey(now.add(const Duration(days: 1)));
      rest = rest.replaceAll(RegExp(r'(^|\s)завтра(\s|$)', caseSensitive: false), ' ');
    } else if (RegExp(r'(^|\s)сегодня(\s|$)', caseSensitive: false).hasMatch(rest)) {
      deadline = _dateKey(now);
      rest = rest.replaceAll(RegExp(r'(^|\s)сегодня(\s|$)', caseSensitive: false), ' ');
    }

    var text = rest.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) text = input.trim();
    return _TaskParse(text, priority, deadline);
  }

  void _quickAdd() {
    final raw = _quickController.text.trim();
    if (raw.isEmpty) return;
    final parsed = _parseSmart(raw);
    final now = DateTime.now().millisecondsSinceEpoch;
    final t = Task(
      id: now,
      text: parsed.text,
      category: 'home',
      deadline: parsed.deadline,
      repeat: 'none',
      comment: '',
      priority: parsed.priority,
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
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return NoteModal(
          title: t.text,
          subtitle: t.deadline.isNotEmpty ? '📅 до ${t.deadline}' : null,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (t.comment.isNotEmpty) ...[
                Text(t.comment, style: TextStyle(fontSize: 15, color: cs.onSurface, height: 1.5)),
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
        );
      },
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

  Future<bool> _confirmDelete(Task t) async {
    final cs = Theme.of(context).colorScheme;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Удалить задачу?', style: TextStyle(color: cs.onSurface)),
        content: Text('"${t.text}" будет удалена у обоих.', style: TextStyle(color: cs.onSurfaceVariant)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Удалить', style: TextStyle(color: cs.error)),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  void _delete(Task t) {
    final now = DateTime.now().millisecondsSinceEpoch;
    widget.storage.addTombstone('tasks', t.id.toString(), now, widget.storage.myPartnerId ?? 'unknown');
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

  List<Task> get _activeTasks => _tasks.where((t) => !t.done && !t.archived).toList();

  List<Task> get _filteredTasks {
    var list = _activeTasks;
    if (_selectedCategory != null) {
      list = list.where((t) => t.category == _selectedCategory).toList();
    }
    return list;
  }

  List<Task> get _allVisible => _tasks.where((t) => !t.archived).toList();
  int get _doneCount => _allVisible.where((t) => t.done).length;
  int get _totalCount => _allVisible.length;
  double get _progress => _totalCount == 0 ? 0 : _doneCount / _totalCount;

  Partner? _partnerFor(String id) {
    for (final p in widget.storage.partners) {
      if (p.id == id) return p;
    }
    return null;
  }

  Color _partnerColor(int index, ColorScheme cs) {
    const palette = [
      Color(0xFF5B8DEF),
      Color(0xFFEC407A),
      Color(0xFF26A69A),
      Color(0xFFFFA726),
      Color(0xFF7E57C2),
      Color(0xFF66BB6A),
    ];
    if (index < 0) return cs.onSurfaceVariant;
    return palette[index % palette.length];
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
                tooltip: _viewMode == 'grid' ? 'Списком' : 'Сеткой',
                icon: Icon(_viewMode == 'grid' ? Icons.view_agenda_outlined : Icons.grid_view_outlined, color: cs.primary, size: 22),
                onPressed: () => setState(() => _viewMode = _viewMode == 'grid' ? 'list' : 'grid'),
              ),
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
                  SliverToBoxAdapter(child: _buildProgressCard(cs)),
                  SliverToBoxAdapter(child: _buildQuickAdd(cs)),
                  SliverToBoxAdapter(child: _buildCategoryFilter(cs)),
                  if (_filteredTasks.isEmpty)
                    const SliverFillRemaining(hasScrollBody: false, child: _EmptyTasks())
                  else
                    _buildCardsSliver(cs),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardsSliver(ColorScheme cs) {
    if (_viewMode == 'list') {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 160),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _swipeCard(_filteredTasks[i], cs),
            ),
            childCount: _filteredTasks.length,
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 160),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childCount: _filteredTasks.length,
        itemBuilder: (ctx, i) => _swipeCard(_filteredTasks[i], cs),
      ),
    );
  }

  Widget _swipeCard(Task t, ColorScheme cs) {
    final pi = widget.storage.partners.indexWhere((p) => p.id == t.assignee);
    final partner = pi >= 0 ? widget.storage.partners[pi] : null;
    final avatarText = partner == null
        ? '∗'
        : (partner.name.trim().isNotEmpty ? partner.name.trim()[0].toUpperCase() : '?');
    final avatarColor = _partnerColor(pi, cs);

    return Dismissible(
      key: ValueKey('t_${t.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          _toggleDone(t);
          return false;
        }
        return await _confirmDelete(t);
      },
      onDismissed: (dir) {
        if (dir == DismissDirection.endToStart) _delete(t);
      },
      background: _swipeBg(cs, done: true),
      secondaryBackground: _swipeBg(cs, done: false),
      child: NoteCard(
        title: t.text,
        subtitle: t.deadline.isNotEmpty ? '📅 ${t.deadline}' : null,
        isHighPriority: t.priority == 'high',
        avatarText: avatarText,
        avatarColor: avatarColor,
        onTap: () => _openNoteModal(t),
      ),
    );
  }

  Widget _swipeBg(ColorScheme cs, {required bool done}) {
    final color = done ? cs.tertiary : cs.error;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: done ? Alignment.centerLeft : Alignment.centerRight,
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(done ? Icons.check_circle : Icons.delete_outline, color: color, size: 22),
          const SizedBox(width: 8),
          Text(done ? 'Выполнено' : 'Удалить', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildProgressCard(ColorScheme cs) {
    final percent = (_progress * 100).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primaryContainer.withOpacity(0.55), cs.surfaceVariant],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outline.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: _progress),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return CustomPaint(
                  size: const Size(58, 58),
                  painter: _RingPainter(
                    progress: value,
                    track: cs.surface.withOpacity(0.7),
                    color: cs.primary,
                  ),
                  child: SizedBox(
                    width: 58,
                    height: 58,
                    child: Center(
                      child: Text('$percent%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface, height: 1.0)),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Прогресс задач', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: cs.onSurface, height: 1.2)),
                  const SizedBox(height: 4),
                  Text('$_doneCount из $_totalCount выполнено', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.3)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _miniBadge(cs, 'Активно ${_activeTasks.length}', cs.primary),
                      _miniBadge(cs, 'Готово $_doneCount', cs.tertiary),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniBadge(ColorScheme cs, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, height: 1.2)),
    );
  }

  Widget _buildCategoryFilter(ColorScheme cs) {
    final categories = _categories.where((c) => _activeTasks.any((t) => t.category == c.id)).toList();
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
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? cs.primary : cs.surfaceVariant,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: selected ? cs.primary : cs.outline.withOpacity(0.5)),
                  ),
                  child: Text('Все',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, height: 1.2, fontWeight: FontWeight.w600, color: selected ? cs.onPrimary : cs.onSurface)),
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
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? cs.primary : cs.surfaceVariant,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: selected ? cs.primary : cs.outline.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(width: 20, child: Text(cat.emoji, style: const TextStyle(fontSize: 16, height: 1.0), textAlign: TextAlign.center)),
                    if (selected) ...[
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 110),
                        child: Text(cat.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, height: 1.2, fontWeight: FontWeight.w600, color: cs.onPrimary)),
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _quickController,
                onSubmitted: (_) => _quickAdd(),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Что нужно сделать? Можно: завтра врач !',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.check_circle_outline, color: cs.primary, size: 24),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(20)),
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

class _RingPainter extends CustomPainter {
  final double progress;
  final Color track;
  final Color color;

  _RingPainter({required this.progress, required this.track, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 8) / 2;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.track != track || oldDelegate.color != color;
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
            decoration: BoxDecoration(color: cs.primaryContainer.withOpacity(0.3), shape: BoxShape.circle),
            child: Icon(Icons.task_alt, size: 56, color: cs.primary),
          ),
          const SizedBox(height: 20),
          Text('Все задачи выполнены!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface)),
          const SizedBox(height: 8),
          Text('Или добавь новую, используя поле выше', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
