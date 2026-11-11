import 'package:flutter/material.dart';
import '../models/budget_category.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../widgets/modern_app_bar.dart';

class BudgetCategoriesEditorScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;

  const BudgetCategoriesEditorScreen({
    super.key,
    required this.storage,
    required this.sync,
  });

  @override
  State<BudgetCategoriesEditorScreen> createState() => _BudgetCategoriesEditorScreenState();
}

class _BudgetCategoriesEditorScreenState extends State<BudgetCategoriesEditorScreen> {
  List<BudgetCategory> _categories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _categories = widget.storage.budgetCategories;
    });
  }

  void _save(List<BudgetCategory> list) {
    widget.storage.budgetCategories = list;
    _load();
    widget.sync.schedulePush();
  }

  void _openEditModal(BudgetCategory? cat) {
    final isEdit = cat != null;
    final nameCtrl = TextEditingController(text: cat?.name ?? '');
    final emojiCtrl = TextEditingController(text: cat?.emoji ?? '📦');
    String type = cat?.type ?? 'expense';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: StatefulBuilder(
              builder: (ctx, setModalState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: cs.outline.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(isEdit ? 'Редактировать категорию' : 'Новая категория',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface)),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: cs.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: emojiCtrl,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 22, height: 1.0),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: nameCtrl,
                            autofocus: true,
                            maxLines: 1,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.2),
                            decoration: InputDecoration(
                              labelText: 'Название',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: cs.surfaceVariant,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => type = 'expense'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: type == 'expense' ? cs.error.withOpacity(0.15) : cs.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: type == 'expense' ? cs.error : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text('Расход',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.2,
                                      fontWeight: FontWeight.w600,
                                      color: type == 'expense' ? cs.error : cs.onSurfaceVariant,
                                    )),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => type = 'income'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: type == 'income' ? cs.tertiary.withOpacity(0.15) : cs.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: type == 'income' ? cs.tertiary : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text('Доход',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.2,
                                      fontWeight: FontWeight.w600,
                                      color: type == 'income' ? cs.tertiary : cs.onSurfaceVariant,
                                    )),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Отмена'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty) return;
                              final emoji = emojiCtrl.text.trim().isEmpty ? '📦' : emojiCtrl.text.trim();
                              final now = DateTime.now().millisecondsSinceEpoch;

                              if (isEdit) {
                                final updated = cat.copyWith(
                                  name: name,
                                  emoji: emoji,
                                  type: type,
                                  updatedAt: now,
                                );
                                final list = List<BudgetCategory>.from(_categories);
                                final i = list.indexWhere((e) => e.id == updated.id);
                                if (i >= 0) list[i] = updated;
                                _save(list);
                              } else {
                                final newCat = BudgetCategory(
                                  id: 'cat_$now',
                                  name: name,
                                  emoji: emoji,
                                  type: type,
                                  createdAt: DateTime.now(),
                                  updatedAt: now,
                                );
                                _save([..._categories, newCat]);
                              }
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(isEdit ? 'Сохранить' : 'Создать'),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BudgetCategory cat) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Удалить категорию?', style: TextStyle(color: cs.onSurface)),
        content: Text(
          'Категория "${cat.name}" будет удалена. Транзакции с этой категорией останутся, но будут показываться как "Другое".',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              _save(_categories.where((e) => e.id != cat.id).toList());
              Navigator.pop(ctx);
            },
            child: Text('Удалить', style: TextStyle(color: cs.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final expenses = _categories.where((c) => c.type == 'expense').toList();
    final incomes = _categories.where((c) => c.type == 'income').toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          ModernAppBar(
            title: 'Категории бюджета',
            onAvatarTap: () => Navigator.pop(context),
            avatarEmoji: '⬅️',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                Text('Расходы', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant, letterSpacing: 0.4)),
                const SizedBox(height: 10),
                ...expenses.map((c) => _tile(c, cs)),
                const SizedBox(height: 20),
                Text('Доходы', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant, letterSpacing: 0.4)),
                const SizedBox(height: 10),
                ...incomes.map((c) => _tile(c, cs)),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditModal(null),
        backgroundColor: cs.primary,
        child: Icon(Icons.add, color: cs.onPrimary),
      ),
    );
  }

  Widget _tile(BudgetCategory c, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withOpacity(0.5)),
      ),
      child: ListTile(
        onTap: () => _openEditModal(c),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.type == 'income' ? cs.tertiary.withOpacity(0.1) : cs.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(c.emoji, style: const TextStyle(fontSize: 18, height: 1.0)),
        ),
        title: Text(
          c.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface, height: 1.2),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: cs.error, size: 20),
          onPressed: () => _confirmDelete(c),
        ),
      ),
    );
  }
}