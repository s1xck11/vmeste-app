// lib/screens/purchases_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../models/purchase.dart';
import '../models/purchase_list.dart';
import '../models/purchase_category.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/theme_service.dart';
import '../widgets/modern_app_bar.dart';
import '../widgets/add_purchase_modal.dart';
import '../widgets/note_card.dart';
import '../widgets/note_modal.dart';
import '../widgets/status_line.dart';
import 'purchase_templates_screen.dart';
import 'purchase_history_screen.dart';
import 'categories_editor_screen.dart';

class PurchasesScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;
  final ThemeService themeService;
  final VoidCallback onAvatarTap;

  const PurchasesScreen({
    super.key,
    required this.storage,
    required this.sync,
    required this.themeService,
    required this.onAvatarTap,
  });

  @override
  State<PurchasesScreen> createState() => PurchasesScreenState();
}

class PurchasesScreenState extends State<PurchasesScreen> {
  final _quickController = TextEditingController();
  String _selectedListId = 'common';
  String? _selectedCategory;

  List<Purchase> _purchases = [];
  List<PurchaseList> _lists = [];
  List<PurchaseCategory> _categories = [];

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
      _purchases = widget.storage.purchases;
      _lists = widget.storage.purchaseLists;
      _categories = widget.storage.purchaseCategories;
      if (_lists.isNotEmpty && !_lists.any((l) => l.id == _selectedListId)) {
        _selectedListId = _lists.first.id;
      }
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

  void _openAddModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddPurchaseModal(
        categories: _categories,
        lists: _lists,
        initialListId: _selectedListId,
        initialText: _quickController.text.trim(),
        onSave: (p) {
          final now = DateTime.now().millisecondsSinceEpoch;
          final enriched = p.copyWith(
            createdBy: widget.storage.myPartnerId,
            createdByName: _myName(),
            createdByAt: now,
          );
          final list = List<Purchase>.from(_purchases)..add(enriched);
          widget.storage.purchases = list;
          _quickController.clear();
          _load();
          widget.sync.schedulePush();
        },
      ),
    );
  }

  void openAddModal() {
    _openAddModal();
  }

  void _openEditModal(Purchase p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddPurchaseModal(
        categories: _categories,
        lists: _lists,
        initialListId: _selectedListId,
        initialPurchase: p,
        onSave: (updated) {
          final list = List<Purchase>.from(_purchases);
          final i = list.indexWhere((e) => e.id == updated.id);
          if (i >= 0) list[i] = updated;
          widget.storage.purchases = list;
          _load();
          widget.sync.schedulePush();
        },
      ),
    );
  }

  void _openNoteModal(Purchase p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return NoteModal(
          title: p.text,
          subtitle: [
            if (p.qty > 1) '${p.qty} ${p.unit}',
            if (p.price > 0) '${(p.price * p.qty).toStringAsFixed(0)} ₽',
          ].join(' · '),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.comment.isNotEmpty) ...[
                Text(
                  p.comment,
                  style: TextStyle(fontSize: 15, color: cs.onSurface, height: 1.5),
                ),
                const SizedBox(height: 16),
              ],
              if (p.createdByName != null || p.takenByName != null || p.doneByName != null)
                StatusLine(
                  done: p.done,
                  doneByName: p.doneByName,
                  doneAt: p.boughtAt,
                  takenByName: p.takenByName,
                  takenByAt: p.takenByAt,
                  createdByName: p.createdByName,
                  createdByAt: p.createdByAt,
                ),
            ],
          ),
          actionButton: p.done
              ? null
              : ElevatedButton.icon(
                  onPressed: () {
                    _toggleDone(p);
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Куплено'),
                ),
          onEdit: () {
            Navigator.pop(ctx);
            _openEditModal(p);
          },
          onDelete: () {
            Navigator.pop(ctx);
            _delete(p);
          },
          onClose: () => Navigator.pop(ctx),
        );
      },
    );
  }

  void _take(Purchase p) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _replace(p.copyWith(
      takenBy: widget.storage.myPartnerId,
      takenByName: _myName(),
      takenByAt: now,
      updatedAt: now,
    ));
  }

  void _untake(Purchase p) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _replace(p.copyWith(clearTakenBy: true, updatedAt: now));
  }

  void _toggleDone(Purchase p) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (p.done) {
      _replace(p.copyWith(done: false, clearDoneBy: true, updatedAt: now));
    } else {
      _replace(p.copyWith(
        done: true,
        missing: false,
        boughtAt: now,
        doneBy: widget.storage.myPartnerId,
        doneByName: _myName(),
        updatedAt: now,
      ));
    }
  }

  void _delete(Purchase p) {
    final now = DateTime.now().millisecondsSinceEpoch;
    // 1. Создаём tombstone
    widget.storage.addTombstone('purchases', p.id.toString(), now, widget.storage.myPartnerId ?? 'unknown');

    // 2. Удаляем из локального списка
    final list = List<Purchase>.from(_purchases)..removeWhere((e) => e.id == p.id);
    widget.storage.purchases = list;

    _load();
    widget.sync.schedulePush();
  }

  void _replace(Purchase updated) {
    final list = List<Purchase>.from(_purchases);
    final i = list.indexWhere((e) => e.id == updated.id);
    if (i >= 0) list[i] = updated;
    widget.storage.purchases = list;
    _load();
    widget.sync.schedulePush();
  }

  List<Purchase> get _visiblePurchases {
    final list = _purchases.where((p) => p.listId == _selectedListId).toList();
    list.sort((a, b) {
      int rank(Purchase p) => p.done ? 2 : (p.missing ? 1 : 0);
      final ra = rank(a), rb = rank(b);
      if (ra != rb) return ra.compareTo(rb);
      return (a.order).compareTo(b.order);
    });
    return list;
  }

  List<Purchase> get _filteredPurchases {
    var list = _visiblePurchases;
    if (_selectedCategory != null) {
      list = list.where((p) => p.category == _selectedCategory).toList();
    }
    return list;
  }

  PurchaseCategory _categoryOf(String id) {
    return _categories.firstWhere(
      (c) => c.id == id,
      orElse: () => PurchaseCategory(id: id, label: 'Прочее', emoji: '📦', order: 999),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          ModernAppBar(
            title: 'Покупки',
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
                      kind: CategoryKind.purchase,
                    ),
                  ));
                  _load();
                },
              ),
              IconButton(
                tooltip: 'Шаблоны',
                icon: Icon(Icons.view_list, color: cs.primary, size: 22),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PurchaseTemplatesScreen(
                    storage: widget.storage,
                    sync: widget.sync,
                  ),
                )),
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
                  SliverToBoxAdapter(child: _buildListSegments(cs)),
                  SliverToBoxAdapter(child: _buildQuickAdd(cs)),
                  SliverToBoxAdapter(child: _buildCategoryFilter(cs)),
                  if (_filteredPurchases.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyPurchases(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 160),
                      sliver: SliverMasonryGrid.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childCount: _filteredPurchases.length,
                        itemBuilder: (ctx, i) {
                          final p = _filteredPurchases[i];
                          return NoteCard(
                            title: p.text,
                            subtitle: [
                              if (p.qty > 1) '${p.qty} ${p.unit}',
                              if (p.price > 0) '${(p.price * p.qty).toStringAsFixed(0)} ₽',
                            ].join(' · '),
                            isDone: p.done,
                            onTap: () => _openNoteModal(p),
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
      _visiblePurchases.any((p) => p.category == c.id)
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

  Widget _buildListSegments(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: cs.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: _lists.map((l) {
              final selected = l.id == _selectedListId;
              return GestureDetector(
                onTap: () => setState(() => _selectedListId = l.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? cs.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${l.emoji} ${l.name}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
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
                onSubmitted: (_) => _openAddModal(),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Что купить?',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.add_shopping_cart, color: cs.primary, size: 24),
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
                onPressed: _openAddModal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPurchases extends StatelessWidget {
  const _EmptyPurchases();

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
              color: cs.secondaryContainer.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shopping_bag_outlined, size: 56, color: cs.secondary),
          ),
          const SizedBox(height: 20),
          Text(
            'Список покупок пуст',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Добавь первый товар, чтобы ничего не забыть',
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
