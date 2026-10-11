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
import '../widgets/status_line.dart';
import '../widgets/glass_container.dart';
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

  String _myName() {
    return widget.storage.myName.isEmpty
        ? (widget.storage.myPartnerId ?? '')
        : widget.storage.myName;
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
          final now = DateTime.now().millisecondsSinceEpoch;
          final enriched = p.copyWith(
            createdBy: widget.storage.myPartnerId,
            createdByName: _myName(),
            createdByAt: now,
          );
          final list = List<Purchase>.from(_purchases)..add(enriched);
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
        takenBy: p.takenBy ?? widget.storage.myPartnerId,
        takenByName: p.takenByName ?? _myName(),
        takenByAt: p.takenByAt ?? now,
        updatedAt: now,
      ));
    }
  }

  void _toggleMissing(Purchase p) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _replace(p.copyWith(missing: !p.missing, done: false, updatedAt: now));
  }

  void _delete(Purchase p) {
    final list = List<Purchase>.from(_purchases)
      ..removeWhere((e) => e.id == p.id);
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
    final list =
        _purchases.where((p) => p.listId == _selectedListId).toList();
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
      orElse: () =>
          PurchaseCategory(id: id, label: 'Прочее', emoji: '📦', order: 999),
    );
  }

  bool _isMine(Purchase p) => p.takenBy == widget.storage.myPartnerId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final grouped = _groupedByCategory;
    final total = _totalSum;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              ModernAppBar(
                title: 'Покупки',
                onAvatarTap: widget.onAvatarTap,
                avatarEmoji: widget.storage.myAvatar,
                actions: [
                  IconButton(
                    tooltip: 'Шаблоны',
                    icon: Icon(Icons.view_list, color: cs.primary, size: 22),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PurchaseTemplatesScreen(
                          storage: widget.storage,
                          sync: widget.sync,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'История',
                    icon: Icon(Icons.history, color: cs.primary, size: 22),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PurchaseHistoryScreen(
                          storage: widget.storage,
                          sync: widget.sync,
                        ),
                      ),
                    ),
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
                              isMine: _isMine,
                              onToggleDone: _toggleDone,
                              onToggleMissing: _toggleMissing,
                              onDelete: _delete,
                              onEdit: _openEditModal,
                              onTake: _take,
                              onUntake: _untake,
                            ),
                          );
                        }),
                      // Отступ снизу — чтобы контент не терялся за суммой + навбаром
                      const SliverToBoxAdapter(child: SizedBox(height: 180)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Итоговая сумма — над навбаром (навбар в main.dart на bottom: ~14)
          if (total > 0)
            Positioned(
              left: 16,
              right: 16,
              bottom: 14 + bottomInset * 0.5 + 68 + 10, // над навбаром
              child: GlassContainer(
                radius: 24,
                showAllBorder: false,
                shadow: true,
                opacity: 0.92,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.shopping_cart_checkout,
                          color: cs.primary, size: 22),
                      const SizedBox(width: 12),
                      Text(
                        'Итого',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${total.toStringAsFixed(0)} ₽',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Сегмент-контрол списков.
  /// Если список один — не растягиваем на всю ширину.
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? cs.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${l.emoji} ${l.name}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color:
                          selected ? cs.onPrimary : cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                prefixIcon: Icon(Icons.add_shopping_cart,
                    color: cs.onSurfaceVariant, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 56,
            width: 56,
            child: ElevatedButton(
              onPressed: _openQuickModal,
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

class _CategoryGroup extends StatelessWidget {
  final PurchaseCategory category;
  final List<Purchase> items;
  final bool Function(Purchase) isMine;
  final void Function(Purchase) onToggleDone;
  final void Function(Purchase) onToggleMissing;
  final void Function(Purchase) onDelete;
  final void Function(Purchase) onEdit;
  final void Function(Purchase) onTake;
  final void Function(Purchase) onUntake;

  const _CategoryGroup({
    required this.category,
    required this.items,
    required this.isMine,
    required this.onToggleDone,
    required this.onToggleMissing,
    required this.onDelete,
    required this.onEdit,
    required this.onTake,
    required this.onUntake,
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
            padding: const EdgeInsets.only(left: 6, bottom: 10),
            child: Row(
              children: [
                Text('${category.emoji} ',
                    style: const TextStyle(fontSize: 14)),
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
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          ...items.map((p) => _PurchaseTile(
                purchase: p,
                mine: isMine(p),
                onToggleDone: () => onToggleDone(p),
                onToggleMissing: () => onToggleMissing(p),
                onDelete: () => onDelete(p),
                onTap: () => onEdit(p),
                onTake: () => onTake(p),
                onUntake: () => onUntake(p),
              )),
        ],
      ),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  final Purchase purchase;
  final bool mine;
  final VoidCallback onToggleDone;
  final VoidCallback onToggleMissing;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final VoidCallback onTake;
  final VoidCallback onUntake;

  const _PurchaseTile({
    required this.purchase,
    required this.mine,
    required this.onToggleDone,
    required this.onToggleMissing,
    required this.onDelete,
    required this.onTap,
    required this.onTake,
    required this.onUntake,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDone = purchase.done;
    final isMissing = purchase.missing;
    final isTaken = purchase.takenBy != null && !isDone;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key('purchase_${purchase.id}'),
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24),
          decoration: BoxDecoration(
            color: cs.tertiary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(Icons.flag_outlined, color: cs.tertiary),
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
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                        color: isDone
                            ? cs.tertiary
                            : (isMissing
                                ? cs.secondary
                                : Colors.transparent),
                        border: Border.all(
                          color: isDone
                              ? cs.tertiary
                              : (isMissing ? cs.secondary : cs.outline),
                          width: 2,
                        ),
                      ),
                      child: isDone
                          ? Icon(Icons.check,
                              size: 15, color: cs.onTertiary)
                          : (isMissing
                              ? Icon(Icons.priority_high,
                                  size: 13, color: cs.onSecondary)
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
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                            decoration: isDone
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: cs.onSurfaceVariant,
                          ),
                        ),
                        if (purchase.qty > 1 || purchase.price > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (purchase.qty > 1)
                                '${purchase.qty} ${purchase.unit}',
                              if (purchase.price > 0)
                                '${(purchase.price * purchase.qty).toStringAsFixed(0)} ₽',
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        StatusLine(
                          done: isDone,
                          doneByName: purchase.doneByName,
                          doneAt: purchase.boughtAt,
                          takenByName: purchase.takenByName,
                          takenByAt: purchase.takenByAt,
                          createdByName: purchase.createdByName,
                          createdByAt: purchase.createdByAt,
                        ),
                      ],
                    ),
                  ),
                  if (!isDone && !isMissing)
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
          ),
        ),
      ),
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
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'Взять',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
          ),
        ),
      );
    }

    if (mine) {
      return GestureDetector(
        onTap: onUntake,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline),
          ),
          child: Text(
            'Отменить',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
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

class _EmptyPurchases extends StatelessWidget {
  const _EmptyPurchases();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined,
              size: 64, color: cs.onSurfaceVariant),
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