// lib/screens/purchase_templates_screen.dart

import 'package:flutter/material.dart';
import '../models/purchase_template.dart';
import '../models/purchase.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';

class PurchaseTemplatesScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;

  const PurchaseTemplatesScreen({
    super.key,
    required this.storage,
    required this.sync,
  });

  @override
  State<PurchaseTemplatesScreen> createState() => _PurchaseTemplatesScreenState();
}

class _PurchaseTemplatesScreenState extends State<PurchaseTemplatesScreen> {
  void _apply(PurchaseTemplate t) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final list = List<Purchase>.from(widget.storage.purchases);
    for (int i = 0; i < t.items.length; i++) {
      final item = t.items[i];
      list.add(Purchase(
        id: now + i,
        text: item.text,
        done: false, missing: false,
        category: item.category,
        qty: item.qty, unit: item.unit, price: 0,
        listId: 'default',
        order: list.length,
        createdAt: now, updatedAt: now,
      ));
    }
    widget.storage.purchases = list;
    widget.sync.schedulePush();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Добавлено ${t.items.length} товаров')),
    );
    Navigator.pop(context);
  }

  void _delete(PurchaseTemplate t) {
    final list = List<PurchaseTemplate>.from(widget.storage.purchaseTemplates)..removeWhere((e) => e.id == t.id);
    widget.storage.purchaseTemplates = list;
    widget.sync.schedulePush();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final list = widget.storage.purchaseTemplates;
    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(title: const Text('Шаблоны покупок')),
      body: list.isEmpty
          ? Center(child: Text('Пока нет шаблонов', style: TextStyle(color: cs.onSurfaceVariant)))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: list.map((t) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.outline),
                ),
                child: Row(
                  children: [
                    Text(t.emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface)),
                          Text('${t.items.length} товаров', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => _apply(t), icon: Icon(Icons.add_circle_outline, color: cs.primary)),
                    IconButton(onPressed: () => _delete(t), icon: Icon(Icons.delete_outline, color: cs.error)),
                  ],
                ),
              )).toList(),
            ),
    );
  }
}