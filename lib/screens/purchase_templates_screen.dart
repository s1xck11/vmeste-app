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
  List<PurchaseTemplate> _templates = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _templates = widget.storage.purchaseTemplates;
    if (mounted) setState(() {});
  }

  void _save() {
    widget.storage.purchaseTemplates = _templates;
    widget.sync.schedulePush();
    setState(() {});
  }

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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить шаблон?'),
        content: Text(t.name),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () {
              _templates = _templates.where((e) => e.id != t.id).toList();
              _save();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor({PurchaseTemplate? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final emojiCtrl = TextEditingController(text: existing?.emoji ?? '🛒');
    final itemsCtrl = TextEditingController(
      text: existing == null
          ? ''
          : existing.items.map((e) => e.text).join('\n'),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Новый шаблон' : 'Редактировать'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: emojiCtrl,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22),
                      decoration: const InputDecoration(labelText: '📦'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Название'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: itemsCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Товары (по одному на строку)',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final emoji = emojiCtrl.text.trim();
              final items = itemsCtrl.text
                  .split('\n')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
              if (name.isEmpty || items.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Нужно название и хотя бы один товар')),
                );
                return;
              }

              final now = DateTime.now().millisecondsSinceEpoch;
              if (existing == null) {
                _templates.add(PurchaseTemplate(
                  id: 'tpl_$now',
                  name: name,
                  emoji: emoji.isEmpty ? '🛒' : emoji,
                  items: items.map((t) => PurchaseTemplateItem(text: t)).toList(),
                  updatedAt: now,
                ));
              } else {
                final idx = _templates.indexWhere((e) => e.id == existing.id);
                if (idx >= 0) {
                  _templates[idx] = PurchaseTemplate(
                    id: existing.id,
                    name: name,
                    emoji: emoji.isEmpty ? '🛒' : emoji,
                    items: items.map((t) => PurchaseTemplateItem(text: t)).toList(),
                    updatedAt: now,
                  );
                }
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (saved == true) _save();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(title: const Text('Шаблоны покупок')),
      body: _templates.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.view_list, size: 64, color: cs.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('Нет шаблонов',
                      style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text('Нажми «+», чтобы создать',
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: _templates.map((t) => Container(
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
                          Text(t.name,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface)),
                          Text('${t.items.length} товаров',
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _apply(t),
                      icon: Icon(Icons.add_circle_outline, color: cs.primary),
                      tooltip: 'Добавить в покупки',
                    ),
                    IconButton(
                      onPressed: () => _openEditor(existing: t),
                      icon: Icon(Icons.edit_outlined, color: cs.onSurfaceVariant),
                    ),
                    IconButton(
                      onPressed: () => _delete(t),
                      icon: Icon(Icons.delete_outline, color: cs.error),
                    ),
                  ],
                ),
              )).toList(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Создать шаблон'),
      ),
    );
  }
}