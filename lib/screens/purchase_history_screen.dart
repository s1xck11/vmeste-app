// lib/screens/purchase_history_screen.dart

import 'package:flutter/material.dart';
import '../models/purchase_history_entry.dart';
import '../models/purchase.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;

  const PurchaseHistoryScreen({
    super.key,
    required this.storage,
    required this.sync,
  });

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  void _repeat(PurchaseHistoryEntry h) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final list = List<Purchase>.from(widget.storage.purchases);
    for (int i = 0; i < h.items.length; i++) {
      final item = h.items[i];
      list.add(Purchase(
        id: now + i,
        text: item.text,
        done: false, missing: false,
        category: item.category,
        qty: item.qty, unit: item.unit, price: item.price,
        listId: 'default',
        order: list.length,
        createdAt: now, updatedAt: now,
      ));
    }
    widget.storage.purchases = list;
    widget.sync.schedulePush();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Добавлено ${h.items.length} товаров')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final list = widget.storage.purchaseHistory;
    if (list.isEmpty) {
      return Scaffold(
        backgroundColor: cs.background,
        appBar: AppBar(title: const Text('История покупок')),
        body: Center(child: Text('История пуста', style: TextStyle(color: cs.onSurfaceVariant))),
      );
    }
    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(title: const Text('История покупок')),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: list.length,
        itemBuilder: (ctx, i) {
          final h = list[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('📅 ${h.date}', style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _repeat(h),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  h.items.map((e) => e.text).take(5).join(' · ') + (h.items.length > 5 ? ' …' : ''),
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}