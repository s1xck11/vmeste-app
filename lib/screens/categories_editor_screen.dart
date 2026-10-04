// lib/screens/categories_editor_screen.dart

import 'package:flutter/material.dart';
import '../models/purchase_category.dart';
import '../models/task_category.dart';
import '../models/shift_type.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';

enum CategoryKind { purchase, task, shiftType }

class CategoriesEditorScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;
  final CategoryKind kind;

  const CategoriesEditorScreen({
    super.key,
    required this.storage,
    required this.sync,
    required this.kind,
  });

  @override
  State<CategoriesEditorScreen> createState() => _CategoriesEditorScreenState();
}

class _CategoriesEditorScreenState extends State<CategoriesEditorScreen> {
  String _title() {
    switch (widget.kind) {
      case CategoryKind.purchase: return 'Категории покупок';
      case CategoryKind.task: return 'Категории задач';
      case CategoryKind.shiftType: return 'Типы смен';
    }
  }

  Future<void> _add() async {
    switch (widget.kind) {
      case CategoryKind.purchase:
        final list = List<PurchaseCategory>.from(widget.storage.purchaseCategories);
        list.add(PurchaseCategory(
          id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
          label: 'Новая',
          emoji: '📦',
          order: list.length,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ));
        widget.storage.purchaseCategories = list;
        break;
      case CategoryKind.task:
        final list = List<TaskCategory>.from(widget.storage.taskCategories);
        list.add(TaskCategory(
          id: 'tcat_${DateTime.now().millisecondsSinceEpoch}',
          label: 'Новая',
          emoji: '📦',
          order: list.length,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ));
        widget.storage.taskCategories = list;
        break;
      case CategoryKind.shiftType:
        final list = List<ShiftType>.from(widget.storage.shiftTypes);
        list.add(ShiftType(
          id: 'st_${DateTime.now().millisecondsSinceEpoch}',
          label: 'Новый',
          hours: 8,
          color: '#FF8FAB',
        ));
        widget.storage.shiftTypes = list;
        break;
    }
    widget.sync.schedulePush();
    setState(() {});
  }

  Future<void> _delete(int index) async {
    switch (widget.kind) {
      case CategoryKind.purchase:
        final list = List<PurchaseCategory>.from(widget.storage.purchaseCategories)..removeAt(index);
        widget.storage.purchaseCategories = list;
        break;
      case CategoryKind.task:
        final list = List<TaskCategory>.from(widget.storage.taskCategories)..removeAt(index);
        widget.storage.taskCategories = list;
        break;
      case CategoryKind.shiftType:
        final list = List<ShiftType>.from(widget.storage.shiftTypes)..removeAt(index);
        widget.storage.shiftTypes = list;
        break;
    }
    widget.sync.schedulePush();
    setState(() {});
  }

  void _editLabel(int index, String value) {
    switch (widget.kind) {
      case CategoryKind.purchase:
        final list = List<PurchaseCategory>.from(widget.storage.purchaseCategories);
        list[index] = list[index].copyWith(label: value, updatedAt: DateTime.now().millisecondsSinceEpoch);
        widget.storage.purchaseCategories = list;
        break;
      case CategoryKind.task:
        final list = List<TaskCategory>.from(widget.storage.taskCategories);
        list[index] = list[index].copyWith(label: value, updatedAt: DateTime.now().millisecondsSinceEpoch);
        widget.storage.taskCategories = list;
        break;
      case CategoryKind.shiftType:
        final list = List<ShiftType>.from(widget.storage.shiftTypes);
        list[index] = ShiftType(
          id: list[index].id,
          label: value,
          hours: list[index].hours,
          color: list[index].color,
        );
        widget.storage.shiftTypes = list;
        break;
    }
    widget.sync.schedulePush();
  }

  void _editEmoji(int index, String value) {
    switch (widget.kind) {
      case CategoryKind.purchase:
        final list = List<PurchaseCategory>.from(widget.storage.purchaseCategories);
        list[index] = list[index].copyWith(emoji: value, updatedAt: DateTime.now().millisecondsSinceEpoch);
        widget.storage.purchaseCategories = list;
        break;
      case CategoryKind.task:
        final list = List<TaskCategory>.from(widget.storage.taskCategories);
        list[index] = list[index].copyWith(emoji: value, updatedAt: DateTime.now().millisecondsSinceEpoch);
        widget.storage.taskCategories = list;
        break;
      case CategoryKind.shiftType:
        break;
    }
    widget.sync.schedulePush();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        title: Text(_title()),
        actions: [
          IconButton(onPressed: _add, icon: const Icon(Icons.add)),
        ],
      ),
      body: _buildList(cs),
    );
  }

  Widget _buildList(ColorScheme cs) {
    final items = _buildItems();
    if (items.isEmpty) {
      return Center(child: Text('Пусто', style: TextStyle(color: cs.onSurfaceVariant)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      itemBuilder: (ctx, i) => items[i],
    );
  }

  List<Widget> _buildItems() {
    final cs = Theme.of(context).colorScheme;
    switch (widget.kind) {
      case CategoryKind.purchase:
        final cats = widget.storage.purchaseCategories;
        return List.generate(cats.length, (i) {
          final c = cats[i];
          return _row(
            cs: cs,
            emoji: c.emoji,
            label: c.label,
            showEmoji: true,
            onLabel: (v) => _editLabel(i, v),
            onEmoji: (v) => _editEmoji(i, v),
            onDelete: () => _delete(i),
          );
        });
      case CategoryKind.task:
        final cats = widget.storage.taskCategories;
        return List.generate(cats.length, (i) {
          final c = cats[i];
          return _row(
            cs: cs,
            emoji: c.emoji,
            label: c.label,
            showEmoji: true,
            onLabel: (v) => _editLabel(i, v),
            onEmoji: (v) => _editEmoji(i, v),
            onDelete: () => _delete(i),
          );
        });
      case CategoryKind.shiftType:
        final types = widget.storage.shiftTypes;
        return List.generate(types.length, (i) {
          final t = types[i];
          return _row(
            cs: cs,
            emoji: '🎨',
            label: t.label,
            showEmoji: false,
            onLabel: (v) => _editLabel(i, v),
            onEmoji: null,
            onDelete: () => _delete(i),
          );
        });
    }
  }

  Widget _row({
    required ColorScheme cs,
    required String emoji,
    required String label,
    required bool showEmoji,
    required void Function(String) onLabel,
    required void Function(String)? onEmoji,
    required VoidCallback onDelete,
  }) {
    final labelCtrl = TextEditingController(text: label);
    final emojiCtrl = TextEditingController(text: emoji);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          if (showEmoji && onEmoji != null)
            SizedBox(
              width: 48,
              child: TextField(
                controller: emojiCtrl,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22),
                onSubmitted: onEmoji,
                decoration: const InputDecoration(border: InputBorder.none, isDense: true),
              ),
            ),
          Expanded(
            child: TextField(
              controller: labelCtrl,
              onSubmitted: onLabel,
              style: TextStyle(color: cs.onSurface),
              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline, color: cs.error),
          ),
        ],
      ),
    );
  }
}