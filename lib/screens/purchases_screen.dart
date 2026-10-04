import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import '../models/purchase.dart';
import '../models/purchase_category.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../widgets/add_purchase_modal.dart';

/// Экран покупок.
/// 
/// Вкладки: «Общий» и «Мой» (личный список партнёра).
/// Чужие личные списки не показываются.
class PurchasesScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;

  const PurchasesScreen({
    super.key,
    required this.storage,
    required this.sync,
  });

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  String _currentListId = 'common';
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

  /// Список покупок, которые надо показать
  List<Purchase> get _visiblePurchases {
    final myRole = widget.storage.myPartnerId;
    return widget.storage.purchases.where((p) {
      if (p.deletedAt != null) return false;
      if (p.listId == 'common') return true;
      // Личные списки видит только их владелец
      if (p.listId == myRole) return true;
      // Legacy: 'default' показываем в общий
      if (p.listId == 'default' && _currentListId == 'common') return true;
      return false;
    }).toList();
  }

  /// Покупки текущего списка
  List<Purchase> get _currentPurchases {
    return _visiblePurchases
        .where((p) =>
            p.listId == _currentListId ||
            (_currentListId == 'common' && p.listId == 'default'))
        .toList();
  }

  /// Итоговая сумма
  double get _total {
    return _currentPurchases
        .where((p) => !p.done && !p.missing)
        .fold(0.0, (sum, p) => sum + p.total);
  }

  /// Активные покупки
  int get _activeCount =>
      _currentPurchases.where((p) => !p.done && !p.missing).length;

  // ============ ДОБАВЛЕНИЕ ============

  Future<void> _quickAdd() async {
    final text = _quickAddController.text.trim();
    if (text.isEmpty) return;
    _quickAddController.clear();
    await _openAddModal(defaultText: text);
  }

  Future<void> _openAddModal({String defaultText = ''}) async {
    final result = await showModalBottomSheet<Purchase>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddPurchaseModal(
        listId: _currentListId,
        defaultText: defaultText,
        categories: widget.storage.purchaseCategories,
        currentUserIdGetter: () => widget.storage.currentUserId,
      ),
    );

    if (result != null) {
      final list = widget.storage.purchases;
      list.add(result);
      widget.storage.purchases = list;
      widget.sync.schedulePush();
      _refresh();
    }
  }

  Future<void> _edit(Purchase p) async {
    final result = await showModalBottomSheet<Purchase>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddPurchaseModal(
        existing: p,
        listId: _currentListId,
        categories: widget.storage.purchaseCategories,
        currentUserIdGetter: () => widget.storage.currentUserId,
      ),
    );

    if (result != null) {
      final list = widget.storage.purchases;
      final idx = list.indexWhere((x) => x.id == result.id);
      if (idx >= 0) list[idx] = result;
      widget.storage.purchases = list;
      widget.sync.schedulePush();
      _refresh();
    }
  }

  void _toggle(Purchase p) {
    final list = widget.storage.purchases;
    final idx = list.indexWhere((x) => x.id == p.id);
    if (idx < 0) return;

    final item = list[idx];
    if (item.missing) {
      item.missing = false;
    } else {
      item.done = !item.done;
      item.boughtAt = item.done ? DateTime.now().millisecondsSinceEpoch : null;
    }
    item.updatedAt = DateTime.now().millisecondsSinceEpoch;
    item.updatedBy = widget.storage.currentUserId;

    list[idx] = item;
    widget.storage.purchases = list;
    widget.sync.schedulePush();
    _refresh();
  }

  void _toggleMissing(Purchase p) {
    final list = widget.storage.purchases;
    final idx = list.indexWhere((x) => x.id == p.id);
    if (idx < 0) return;

    final item = list[idx];
    item.missing = !item.missing;
    if (item.missing) item.done = false;
    item.updatedAt = DateTime.now().millisecondsSinceEpoch;
    item.updatedBy = widget.storage.currentUserId;

    list[idx] = item;
    widget.storage.purchases = list;
    widget.sync.schedulePush();
    _refresh();
  }

  void _delete(Purchase p) {
    final list = widget.storage.purchases;
    list.removeWhere((x) => x.id == p.id);

    final deleted = widget.storage.deletedPurchaseIds;
    deleted.add(p.id);
    widget.storage.deletedPurchaseIds = deleted;
    widget.storage.purchases = list;

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

    // Формируем вкладки
    final tabs = <Map<String, String>>[
      {'id': 'common', 'label': 'Общий', 'emoji': '🛒'},
      if (myRole != null) {'id': myRole, 'label': myName, 'emoji': '👤'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Покупки'),
        actions: [
          // Индикатор статуса
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
          preferredSize: const Size.fromHeight(50),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: tabs.map((t) {
                final selected = _currentListId == t['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _currentListId = t['id']!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white
                            : Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(t['emoji']!),
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
                              fontSize: 13,
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
                      hintText: 'Что купить?',
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

          // Итого
          if (_total > 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accent, AppColors.info],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '💰 Итого:',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${_total.toStringAsFixed(0)} ₽',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),

          // Счётчик
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                Text(
                  _currentPurchases.isEmpty
                      ? ''
                      : '$_activeCount из ${_currentPurchases.length}',
                  style: const TextStyle(
                    fontSize: 13,
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
            child: _currentPurchases.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🛒', style: TextStyle(fontSize: 60)),
                        const SizedBox(height: 12),
                        const Text(
                          'Список пуст',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : _buildGroupedList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList() {
    // Группируем по категориям
    final grouped = <String, List<Purchase>>{};
    for (final p in _currentPurchases) {
      grouped.putIfAbsent(p.category, () => []).add(p);
    }

    // Сортируем категории по order
    final cats = widget.storage.purchaseCategories;
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final ca = cats.firstWhere(
          (c) => c.id == a,
          orElse: () => PurchaseCategory(id: a, label: 'Other', emoji: '📦', order: 999),
        );
        final cb = cats.firstWhere(
          (c) => c.id == b,
          orElse: () => PurchaseCategory(id: b, label: 'Other', emoji: '📦', order: 999),
        );
        return ca.order.compareTo(cb.order);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: sortedKeys.map((catId) {
        final cat = cats.firstWhere(
          (c) => c.id == catId,
          orElse: () => PurchaseCategory(id: catId, label: 'Прочее', emoji: '📦'),
        );
        final items = grouped[catId]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
              child: Text(
                '${cat.emoji} ${cat.label.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: items.map((p) => _buildItem(p)).toList(),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildItem(Purchase p) {
    return InkWell(
      onTap: () => _edit(p),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            // Чекбокс
            GestureDetector(
              onTap: () => _toggle(p),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: p.done
                      ? AppColors.success
                      : p.missing
                          ? AppColors.warning
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: p.done
                        ? AppColors.success
                        : p.missing
                            ? AppColors.warning
                            : AppColors.textSecondary,
                    width: 2,
                  ),
                ),
                child: p.done
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : p.missing
                        ? const Icon(Icons.priority_high, size: 14, color: Colors.white)
                        : null,
              ),
            ),
            const SizedBox(width: 12),

            // Текст + мета
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.text,
                    style: TextStyle(
                      fontSize: 15,
                      decoration: p.done ? TextDecoration.lineThrough : null,
                      color: p.done ? AppColors.textSecondary : null,
                    ),
                  ),
                  if (p.qty != 1 || p.price > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (p.qty != 1) '${p.qty} ${p.unit}',
                        if (p.price > 0) '💰 ${(p.price * p.qty).toStringAsFixed(0)} ₽',
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Кнопки
            IconButton(
              onPressed: () => _toggleMissing(p),
              icon: Icon(
                Icons.warning_amber,
                size: 20,
                color: p.missing ? AppColors.warning : AppColors.textSecondary,
              ),
              tooltip: 'Нет в наличии',
            ),
            IconButton(
              onPressed: () => _delete(p),
              icon: const Icon(
                Icons.close,
                size: 18,
                color: AppColors.textSecondary,
              ),
              tooltip: 'Удалить',
            ),
          ],
        ),
      ),
    );
  }
}