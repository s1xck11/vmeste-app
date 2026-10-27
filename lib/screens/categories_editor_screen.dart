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
  // Работаем с копией, сохраняем только по кнопке
  late List<PurchaseCategory> _purchaseCats;
  late List<TaskCategory> _taskCats;
  late List<ShiftType> _shiftTypes;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _purchaseCats = List<PurchaseCategory>.from(widget.storage.purchaseCategories);
    _taskCats = List<TaskCategory>.from(widget.storage.taskCategories);
    _shiftTypes = List<ShiftType>.from(widget.storage.shiftTypes);
  }

  String _title() {
    switch (widget.kind) {
      case CategoryKind.purchase:
        return 'Категории покупок';
      case CategoryKind.task:
        return 'Категории задач';
      case CategoryKind.shiftType:
        return 'Типы смен';
    }
  }

  void _save() {
    setState(() => _saving = true);
    switch (widget.kind) {
      case CategoryKind.purchase:
        widget.storage.purchaseCategories = _purchaseCats;
        break;
      case CategoryKind.task:
        widget.storage.taskCategories = _taskCats;
        break;
      case CategoryKind.shiftType:
        widget.storage.shiftTypes = _shiftTypes;
        break;
    }
    widget.sync.schedulePush();
    Navigator.pop(context);
  }

  void _add() {
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      switch (widget.kind) {
        case CategoryKind.purchase:
          _purchaseCats.add(PurchaseCategory(
            id: 'cat_$now',
            label: 'Новая',
            emoji: '📦',
            order: _purchaseCats.length,
            updatedAt: now,
          ));
          break;
        case CategoryKind.task:
          _taskCats.add(TaskCategory(
            id: 'tcat_$now',
            label: 'Новая',
            emoji: '📦',
            order: _taskCats.length,
            updatedAt: now,
          ));
          break;
        case CategoryKind.shiftType:
          _shiftTypes.add(ShiftType(
            id: 'st_$now',
            label: 'Новый',
            hours: 8,
            color: '#FF8FAB',
          ));
          break;
      }
    });
  }

  void _delete(int index) {
    setState(() {
      switch (widget.kind) {
        case CategoryKind.purchase:
          _purchaseCats.removeAt(index);
          break;
        case CategoryKind.task:
          _taskCats.removeAt(index);
          break;
        case CategoryKind.shiftType:
          _shiftTypes.removeAt(index);
          break;
      }
    });
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              minimumSize: const Size(double.infinity, 0),
            ),
            child: const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }

  Widget _buildList(ColorScheme cs) {
    final items = _buildItems();
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 64, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Пусто', style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('Нажми «+», чтобы добавить', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: items,
    );
  }

  List<Widget> _buildItems() {
    final cs = Theme.of(context).colorScheme;
    switch (widget.kind) {
      case CategoryKind.purchase:
        return List.generate(_purchaseCats.length, (i) {
          final c = _purchaseCats[i];
          return _row(
            cs: cs,
            emoji: c.emoji,
            label: c.label,
            showEmoji: true,
            onLabel: (v) {
              setState(() {
                _purchaseCats[i] = PurchaseCategory(
                  id: c.id, label: v, emoji: c.emoji,
                  order: c.order, updatedAt: DateTime.now().millisecondsSinceEpoch,
                );
              });
            },
            onEmoji: (v) {
              setState(() {
                _purchaseCats[i] = PurchaseCategory(
                  id: c.id, label: c.label, emoji: v,
                  order: c.order, updatedAt: DateTime.now().millisecondsSinceEpoch,
                );
              });
            },
            onDelete: () => _delete(i),
          );
        });
      case CategoryKind.task:
        return List.generate(_taskCats.length, (i) {
          final c = _taskCats[i];
          return _row(
            cs: cs,
            emoji: c.emoji,
            label: c.label,
            showEmoji: true,
            onLabel: (v) {
              setState(() {
                _taskCats[i] = TaskCategory(
                  id: c.id, label: v, emoji: c.emoji,
                  order: c.order, updatedAt: DateTime.now().millisecondsSinceEpoch,
                );
              });
            },
            onEmoji: (v) {
              setState(() {
                _taskCats[i] = TaskCategory(
                  id: c.id, label: c.label, emoji: v,
                  order: c.order, updatedAt: DateTime.now().millisecondsSinceEpoch,
                );
              });
            },
            onDelete: () => _delete(i),
          );
        });
      case CategoryKind.shiftType:
        return List.generate(_shiftTypes.length, (i) {
          final t = _shiftTypes[i];
          return _row(
            cs: cs,
            emoji: '🎨',
            label: t.label,
            showEmoji: false,
            onLabel: (v) {
              setState(() {
                _shiftTypes[i] = ShiftType(
                  id: t.id, label: v, hours: t.hours, color: t.color,
                );
              });
            },
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