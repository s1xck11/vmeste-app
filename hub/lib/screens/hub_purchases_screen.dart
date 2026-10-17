import 'package:flutter/material.dart';
import '../models/purchase.dart';
import '../models/purchase_category.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../widgets/glass_container.dart';

/// Полноэкранный список покупок для хаба.
/// Две колонки: активные слева, купленные справа.
class HubPurchasesScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;
  final VoidCallback onClose;

  const HubPurchasesScreen({
    super.key,
    required this.storage,
    required this.sync,
    required this.onClose,
  });

  @override
  State<HubPurchasesScreen> createState() => _HubPurchasesScreenState();
}

class _HubPurchasesScreenState extends State<HubPurchasesScreen> {
  List<Purchase> _purchases = [];
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
    super.dispose();
  }

  void _load() {
    if (!mounted) return;
    setState(() {
      _purchases = widget.storage.purchases;
      _categories = widget.storage.purchaseCategories;
    });
  }

  String _myName() {
    return widget.storage.myName.isEmpty
        ? (widget.storage.myPartnerId ?? '')
        : widget.storage.myName;
  }

  void _toggleDone(Purchase p) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = p.done
        ? p.copyWith(done: false, clearDoneBy: true, updatedAt: now)
        : p.copyWith(
            done: true,
            boughtAt: now,
            doneBy: widget.storage.myPartnerId,
            doneByName: _myName(),
            updatedAt: now,
          );
    _replace(updated);
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

  void _replace(Purchase updated) {
    final list = List<Purchase>.from(_purchases);
    final i = list.indexWhere((e) => e.id == updated.id);
    if (i >= 0) list[i] = updated;
    widget.storage.purchases = list;
    _load();
    widget.sync.schedulePush();
  }

  PurchaseCategory _catOf(String id) {
    return _categories.firstWhere(
      (c) => c.id == id,
      orElse: () => PurchaseCategory(id: id, label: 'Прочее', emoji: '📦', order: 999),
    );
  }

  List<Purchase> get _active => _purchases
      .where((p) => !p.done && !p.missing)
      .toList()
    ..sort((a, b) => a.order.compareTo(b.order));

  List<Purchase> get _done => _purchases
      .where((p) => p.done)
      .toList()
    ..sort((a, b) => (b.boughtAt ?? 0).compareTo(a.boughtAt ?? 0));

  bool _isMine(Purchase p) => p.takenBy == widget.storage.myPartnerId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.shopping_bag, color: cs.primary, size: 28),
              const SizedBox(width: 10),
              Text(
                'Покупки',
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
          Expanded(
            child: Row(
              children: [
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
                              ? Center(child: Text('Список пуст', style: TextStyle(color: cs.onSurfaceVariant)))
                              : ListView.separated(
                                  itemCount: _active.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (ctx, i) {
                                    final p = _active[i];
                                    return _PurchaseRow(
                                      purchase: p,
                                      category: _catOf(p.category),
                                      mine: _isMine(p),
                                      onToggle: () => _toggleDone(p),
                                      onTake: () => _take(p),
                                      onUntake: () => _untake(p),
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
                            'КУПЛЕНО · ${_done.length}',
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
                                    final p = _done[i];
                                    return _PurchaseRow(
                                      purchase: p,
                                      category: _catOf(p.category),
                                      mine: _isMine(p),
                                      onToggle: () => _toggleDone(p),
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

class _PurchaseRow extends StatelessWidget {
  final Purchase purchase;
  final PurchaseCategory category;
  final bool mine;
  final VoidCallback onToggle;
  final VoidCallback onTake;
  final VoidCallback onUntake;
  final ColorScheme cs;

  const _PurchaseRow({
    required this.purchase,
    required this.category,
    required this.mine,
    required this.onToggle,
    required this.onTake,
    required this.onUntake,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = purchase.done;
    final isTaken = purchase.takenBy != null && !isDone;

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
                  purchase.text,
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
                  [
                    '${category.emoji} ${category.label}',
                    if (purchase.qty > 1) '${purchase.qty} ${purchase.unit}',
                  ].join(' · '),
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