import 'package:flutter/material.dart';
import '../models/recurring_payment.dart';
import '../models/budget_category.dart';
import '../models/bank.dart';

class AddRecurringModal extends StatefulWidget {
  final List<BudgetCategory> categories;
  final List<Bank> banks;
  final RecurringPayment? initialPayment;
  final void Function(RecurringPayment) onSave;

  const AddRecurringModal({
    super.key,
    required this.categories,
    required this.banks,
    this.initialPayment,
    required this.onSave,
  });

  @override
  State<AddRecurringModal> createState() => _AddRecurringModalState();
}

class _AddRecurringModalState extends State<AddRecurringModal> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  
  String _selectedCategory = 'cat_other_expense';
  String? _selectedBankId;
  int _selectedDay = 1;
  bool _isExpense = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialPayment != null) {
      final p = widget.initialPayment!;
      _nameController.text = p.name;
      _amountController.text = p.amount.toStringAsFixed(0);
      _selectedCategory = p.categoryId;
      _selectedBankId = p.bankId;
      _selectedDay = p.dayOfMonth;
      _isExpense = p.type == 'expense';
    } else if (widget.banks.isNotEmpty) {
      _selectedBankId = widget.banks.first.id;
    }
    if (widget.categories.isNotEmpty) {
      _selectedCategory = widget.categories.first.id;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
    final name = _nameController.text.trim();
    if (name.isEmpty || amount <= 0) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final p = RecurringPayment(
      id: widget.initialPayment?.id ?? now.toString(),
      name: name,
      amount: amount,
      type: _isExpense ? 'expense' : 'income',
      categoryId: _selectedCategory,
      bankId: _selectedBankId,
      dayOfMonth: _selectedDay,
      enabled: true,
      createdAt: widget.initialPayment?.createdAt ?? now,
      updatedAt: now,
    );

    widget.onSave(p);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEdit = widget.initialPayment != null;

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
            Text(isEdit ? 'Редактировать платёж' : 'Регулярный платёж', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cs.onSurface, letterSpacing: -0.5)),
            const SizedBox(height: 24),

            TextField(
              controller: _nameController,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: cs.onSurface),
              decoration: InputDecoration(
                labelText: 'Название',
                filled: true, fillColor: cs.surfaceVariant,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: cs.onSurface),
              decoration: InputDecoration(
                labelText: 'Сумма',
                suffixText: '₽',
                filled: true, fillColor: cs.surfaceVariant,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    title: Text('Это расход', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface)),
                    value: _isExpense,
                    onChanged: (v) => setState(() => _isExpense = v),
                    activeColor: cs.error,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Text('Списать/зачислить с банка', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: widget.banks.map((b) {
                final selected = _selectedBankId == b.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedBankId = b.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? cs.primary.withOpacity(0.15) : cs.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: selected ? cs.primary : Colors.transparent, width: 1.5),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(b.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(b.name, style: TextStyle(fontSize: 15, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? cs.primary : cs.onSurface)),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            Text('День месяца', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _selectedDay.toDouble(),
                    min: 1, max: 31,
                    divisions: 30,
                    label: '$_selectedDay',
                    onChanged: (v) => setState(() => _selectedDay = v.round()),
                  ),
                ),
                Container(
                  width: 50,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: cs.surfaceVariant, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text('$_selectedDay', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface))),
                ),
              ],
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
              child: Text(isEdit ? 'Сохранить' : 'Создать платёж', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}