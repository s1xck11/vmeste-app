// lib/widgets/add_transaction_modal.dart

import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/budget_category.dart';

class AddTransactionModal extends StatefulWidget {
  final List<BudgetCategory> categories;
  final Transaction? initialTransaction;
  final Function(Transaction) onSave;

  const AddTransactionModal({
    super.key,
    required this.categories,
    this.initialTransaction,
    required this.onSave,
  });

  @override
  State<AddTransactionModal> createState() => _AddTransactionModalState();
}

class _AddTransactionModalState extends State<AddTransactionModal> {
  final _amountCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  String _type = 'expense';
  String _nature = 'conscious';
  String _categoryId = '';
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.initialTransaction != null) {
      final t = widget.initialTransaction!;
      _amountCtrl.text = t.amount.toStringAsFixed(0);
      _commentCtrl.text = t.comment;
      _type = t.type;
      _nature = t.nature;
      _categoryId = t.categoryId;
      _date = t.date;
    } else {
      final first = widget.categories.where((c) => c.type == 'expense').toList();
      if (first.isNotEmpty) _categoryId = first.first.id;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) return;
    if (_categoryId.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final t = Transaction(
      id: widget.initialTransaction?.id ?? now.toString(),
      type: _type,
      amount: amount,
      categoryId: _categoryId,
      comment: _commentCtrl.text.trim(),
      nature: _nature,
      date: _date,
      createdAt: widget.initialTransaction?.createdAt ?? DateTime.now(),
      updatedAt: now,
    );
    widget.onSave(t);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final filtered = widget.categories.where((c) => c.type == _type).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: cs.outline, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.initialTransaction == null ? 'Новая транзакция' : 'Редактировать',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: cs.onSurface),
              ),
              const SizedBox(height: 16),

              // Тип
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(child: _typeChip('expense', 'Расход', cs)),
                    Expanded(child: _typeChip('income', 'Доход', cs)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Сумма
              TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: widget.initialTransaction == null,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  labelText: 'Сумма',
                  suffixText: '₽',
                ),
              ),
              const SizedBox(height: 12),

              // Комментарий
              TextField(
                controller: _commentCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Комментарий',
                  hintText: 'Пятёрочка',
                ),
              ),
              const SizedBox(height: 16),

              // Категории
              Text('КАТЕГОРИЯ',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: filtered.map((c) {
                  final sel = c.id == _categoryId;
                  return GestureDetector(
                    onTap: () => setState(() => _categoryId = c.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? cs.primaryContainer : cs.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? cs.primary : cs.outline),
                      ),
                      child: Text('${c.emoji} ${c.name}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                            color: sel ? cs.onPrimaryContainer : cs.onSurface,
                          )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Метка
              if (_type == 'expense') ...[
                Text('ТИП ТРАТЫ',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  _natureChip('obligatory', '🔴 Обязательное', cs),
                  _natureChip('conscious', '🟡 Осознанное', cs),
                  _natureChip('impulsive', '🟢 Импульсивное', cs),
                ]),
                const SizedBox(height: 16),
              ],

              // Кнопки
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Сохранить'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeChip(String value, String label, ColorScheme cs) {
    final sel = _type == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _type = value;
          final filtered = widget.categories.where((c) => c.type == value).toList();
          _categoryId = filtered.isNotEmpty ? filtered.first.id : '';
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? cs.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                color: sel ? cs.onSurface : cs.onSurfaceVariant,
              )),
        ),
      ),
    );
  }

  Widget _natureChip(String value, String label, ColorScheme cs) {
    final sel = _nature == value;
    return GestureDetector(
      onTap: () => setState(() => _nature = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? cs.primaryContainer : cs.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? cs.primary : cs.outline),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
              color: sel ? cs.onPrimaryContainer : cs.onSurface,
            )),
      ),
    );
  }
}