import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/budget_category.dart';
import '../models/bank.dart';

class AddIncomeModal extends StatefulWidget {
  final List<BudgetCategory> categories;
  final List<Bank> banks;
  final Transaction? initialTransaction;
  final void Function(Transaction) onSave;

  const AddIncomeModal({
    super.key,
    required this.categories,
    required this.banks,
    this.initialTransaction,
    required this.onSave,
  });

  @override
  State<AddIncomeModal> createState() => _AddIncomeModalState();
}

class _AddIncomeModalState extends State<AddIncomeModal> {
  final _amountController = TextEditingController();
  final _commentController = TextEditingController();
  
  String _selectedCategory = 'income_salary';
  String? _selectedBankId;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.initialTransaction != null) {
      final t = widget.initialTransaction!;
      _amountController.text = t.amount.toStringAsFixed(0);
      _commentController.text = t.comment;
      _selectedCategory = t.categoryId;
      _selectedBankId = t.bankId;
      _selectedDate = t.date;
    } else if (widget.banks.isNotEmpty) {
      _selectedBankId = widget.banks.first.id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    
    final t = Transaction(
      id: widget.initialTransaction?.id ?? now.toString(),
      type: 'income',
      amount: amount,
      categoryId: _selectedCategory,
      comment: _commentController.text.trim(),
      nature: 'conscious',
      date: _selectedDate,
      createdAt: widget.initialTransaction?.createdAt ?? DateTime.now(),
      updatedAt: now,
      bankId: _selectedBankId,
    );

    widget.onSave(t);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEdit = widget.initialTransaction != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outline, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(isEdit ? 'Редактировать доход' : 'Новый доход', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cs.onSurface, letterSpacing: -0.5)),
            const SizedBox(height: 24),

            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: !isEdit,
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: cs.onSurface, letterSpacing: -1.5),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.5), fontSize: 40),
                suffixText: '₽',
                suffixStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Divider(color: cs.outline, height: 1),
            const SizedBox(height: 24),

            Text('Зачислить на', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.banks.map((b) => _bankChip(b, cs)).toList(),
            ),
            const SizedBox(height: 24),

            Text('Тип дохода', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('income_salary', 'Зарплата', '💰', cs),
                _chip('income_bonus', 'Премия', '🏆', cs),
                _chip('income_other', 'Иной доход', '✨', cs),
              ],
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(flex: 2, child: TextField(
                  controller: _commentController,
                  style: TextStyle(fontSize: 16, color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Комментарий',
                    prefixIcon: Icon(Icons.edit_note, color: cs.onSurfaceVariant),
                    filled: true, fillColor: cs.surfaceVariant,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(flex: 1, child: GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                    if (picked != null) setState(() => _selectedDate = picked);
                  },
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(color: cs.surfaceVariant, borderRadius: BorderRadius.circular(16)),
                    child: Center(child: Text('${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface))),
                  ),
                )),
              ],
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), backgroundColor: cs.tertiary, foregroundColor: cs.onTertiary),
              child: Text(isEdit ? 'Сохранить' : 'Добавить доход', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bankChip(Bank b, ColorScheme cs) {
    final selected = _selectedBankId == b.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedBankId = b.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? cs.tertiary.withOpacity(0.15) : cs.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? cs.tertiary : Colors.transparent, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(b.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(b.name, style: TextStyle(fontSize: 15, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? cs.tertiary : cs.onSurface)),
        ]),
      ),
    );
  }

  Widget _chip(String id, String label, String emoji, ColorScheme cs) {
    final selected = _selectedCategory == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? cs.tertiary.withOpacity(0.15) : cs.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? cs.tertiary : Colors.transparent, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 15, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? cs.tertiary : cs.onSurface)),
        ]),
      ),
    );
  }
}