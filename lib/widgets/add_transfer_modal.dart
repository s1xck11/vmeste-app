import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/bank.dart';

class AddTransferModal extends StatefulWidget {
  final List<Bank> banks;
  final void Function(Transaction) onSave;

  const AddTransferModal({
    super.key,
    required this.banks,
    required this.onSave,
  });

  @override
  State<AddTransferModal> createState() => _AddTransferModalState();
}

class _AddTransferModalState extends State<AddTransferModal> {
  final _amountController = TextEditingController();
  
  String? _fromBankId;
  String? _toBankId;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.banks.length >= 2) {
      _fromBankId = widget.banks[0].id;
      _toBankId = widget.banks[1].id;
    } else if (widget.banks.isNotEmpty) {
      _fromBankId = widget.banks[0].id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) return;
    if (_fromBankId == null || _toBankId == null) return;
    if (_fromBankId == _toBankId) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    
    final t = Transaction(
      id: now.toString(),
      type: 'transfer',
      amount: amount,
      categoryId: 'transfer',
      comment: 'Перевод',
      nature: 'conscious',
      date: _selectedDate,
      createdAt: DateTime.now(),
      updatedAt: now,
      bankId: _fromBankId,
      toBankId: _toBankId,
    );

    widget.onSave(t);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
            Text('Перевод между банками', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cs.onSurface, letterSpacing: -0.5)),
            const SizedBox(height: 24),

            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
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

            Text('Откуда', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.banks.map((b) => _bankChip(b, true, cs)).toList(),
            ),
            const SizedBox(height: 24),

            Text('Куда', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.banks.map((b) => _bankChip(b, false, cs)).toList(),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), backgroundColor: cs.secondary, foregroundColor: cs.onSecondary),
              child: const Text('Перевести', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bankChip(Bank b, bool isFrom, ColorScheme cs) {
    final selected = isFrom ? _fromBankId == b.id : _toBankId == b.id;
    return GestureDetector(
      onTap: () => setState(() {
        if (isFrom) {
          _fromBankId = b.id;
        } else {
          _toBankId = b.id;
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? cs.secondary.withOpacity(0.15) : cs.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? cs.secondary : Colors.transparent, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(b.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(b.name, style: TextStyle(fontSize: 15, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? cs.secondary : cs.onSurface)),
        ]),
      ),
    );
  }
}