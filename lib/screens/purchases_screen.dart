// lib/screens/purchases_screen.dart

import 'package:flutter/material.dart';
import '../models/purchase.dart';
import '../models/purchase_list.dart';
import '../models/purchase_category.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/theme_service.dart';
import '../widgets/modern_app_bar.dart';
import '../widgets/add_purchase_modal.dart';
import 'purchase_templates_screen.dart';
import 'purchase_history_screen.dart';

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
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final _quickController = TextEditingController();
  String _selectedListId = 'common';

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

  void _openQuickModal() {
    final text = _quickController.text.trim();
    _quickController.clear();
    FocusScope.of(context).unfocus();
    _openAddModal(initialText: text);
  }

  void _openAddModal({String initialText = ''}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddPurchaseModal(
        categories: _categories,
        lists: _lists,
        initialListId: _selectedListId,
        initialText: initialText,
        onSave: (p) {
          final list = List<Purchase>.from(_purchases)..add(p);
          widget.storage.purchases = list;
          _load();
          widget.sync.schedulePush();
        },
      ),
    );
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

  void _toggleDone(Purchase p) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = p.copyWith(
      done: !p.done,
      missing: false,
      boughtAt: !p.done ? now : null,
      updatedAt: now,
    );
    _replace(updated);
  }

  void _toggleMissing(Purchase p) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = p.copyWith(
      missing: !p.missing,
      done: false,
      updatedAt: now,
    );
    _replace(updated);
  }

  void _delete(Purchase p) {
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

  Map<String, List<Purchase>> get _groupedByCategory {
    final map = <String, List<Purchase>>{};
    for (final p in _visiblePurchases) {
      map.putIfAbsent(p.category, () => []).add(p);
    }
    return map;
  }

  double get _totalSum {
    return _visiblePurchases
        .where((p) => !p.done && !p.missing)
        .fold<double>(0, (sum, p) => sum + (p.price * p.qty));
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
    final grouped = _groupedByCategory;
    final total = _totalSum;

    return Scaffold(
      backgroundColor: cs.background,
      body: Column(
        children: [
          ModernAppBar(
            title: 'Покупки',
            onAvatarTap: widget.onAvatarTap,
            avatarEmoji: widget.storage.myAvatar,
            actions: [
              IconButton(
                tooltip: 'Шаблоны',
                icon: Icon(Icons.view_list, color: cs.primary),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PurchaseTemplatesScreen(
                    storage: widget.storage,
                    sync: widget.sync,
                  ),
                )),
              ),
              IconButton(
                tooltip: 'История',
                icon: Icon(Icons.history, color: cs.primary),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PurchaseHistoryScreen(
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
                  if (_visiblePurchases.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyPurchases(),
                    )
                  else
                    ...grouped.entries.map((entry) {
                      final cat = _categoryOf(entry.key);
                      return SliverToBoxAdapter(
                        child: _CategoryGroup(
                          category: cat,
                          items: entry.value,
                          onToggleDone: _toggleDone,
                          onToggleMissing: _toggleMissing,
                          onDelete: _delete,
                          onEdit: _openEditModal,
                        ),
                      );
                    }),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: total > 0 ? _TotalBar(total: total) : null,
    );
  }

  Widget _buildListSegments(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: cs.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: _lists.map((l) {
            final selected = l.id == _selectedListId;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedListId = l.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? cs.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: selected
                        ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '${l.emoji} ${l.name}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? cs.onSurface : cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildQuickAdd(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _quickController,
              onSubmitted: (_) => _openQuickModal(),
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'Что купить?',
                filled: true,
                fillColor: cs.surfaceVariant,
                prefixIcon: Icon(Icons.add_shopping_cart, color: cs.onSurfaceVariant, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 52,
            width: 52,
            child: ElevatedButton(
              onPressed: _openQuickModal,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  final PurchaseCategory category;
  final List<Purchase> items;
  final void Function(Purchase) onToggleDone;
  final void Function(Purchase) onToggleMissing;
  final void Function(Purchase) onDelete;
  final void Function(Purchase) onEdit;

  const _CategoryGroup({
    required this.category,
    required this.items,
    required this.onToggleDone,
    required this.onToggleMissing,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Text('${category.emoji} ', style: const TextStyle(fontSize: 14)),
                Text(
                  category.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '· ${items.length}',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          ...items.map((p) => _PurchaseTile(
                purchase: p,
                onToggleDone: () => onToggleDone(p),
                onToggleMissing: () => onToggleMissing(p),
                onDelete: () => onDelete(p),
                onTap: () => onEdit(p),
              )),
        ],
      ),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  final Purchase purchase;
  final VoidCallback onToggleDone;
  final VoidCallback onToggleMissing;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _PurchaseTile({
    required this.purchase,
    required this.onToggleDone,
    required this.onToggleMissing,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDone = purchase.done;
    final isMissing = purchase.missing;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: Key('purchase_${purchase.id}'),
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          decoration: BoxDecoration(
            color: cs.tertiary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.flag_outlined, color: cs.tertiary),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: cs.error.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.delete_outline, color: cs.error),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            onToggleMissing();
            return false;
          } else {
            onDelete();
            return false;
          }
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: cs.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outline, width: 1),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onToggleDone,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? cs.tertiary
                            : (isMissing ? cs.secondary : Colors.transparent),
                        border: Border.all(
                          color: isDone
                              ? cs.tertiary
                              : (isMissing ? cs.secondary : cs.outline),
                          width: 2,
                        ),
                      ),
                      child: isDone
                          ? Icon(Icons.check, size: 14, color: cs.onTertiary)
                          : (isMissing
                              ? Icon(Icons.priority_high, size: 12, color: cs.onSecondary)
                              : null),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          purchase.text,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            decorationColor: cs.onSurfaceVariant,
                          ),
                        ),
                        if (purchase.qty > 1 || purchase.price > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (purchase.qty > 1) '${purchase.qty} ${purchase.unit}',
                              if (purchase.price > 0)
                                '${(purchase.price * purchase.qty).toStringAsFixed(0)} ₽',
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
          Icon(Icons.shopping_bag_outlined, size: 64, color: cs.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            'Список пуст',
            style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _TotalBar extends StatelessWidget {
  final double total;
  const _TotalBar({required this.total});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: 14 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        border: Border(top: BorderSide(color: cs.outline, width: 1)),
      ),
      child: Row(
        children: [
          Icon(Icons.shopping_cart_checkout, color: cs.onPrimaryContainer),
          const SizedBox(width: 10),
          Text(
            'Итого:',
            style: TextStyle(
              fontSize: 14,
              color: cs.onPrimaryContainer.withOpacity(0.8),
            ),
          ),
          const Spacer(),
          Text(
            '${total.toStringAsFixed(0)} ₽',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: cs.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}