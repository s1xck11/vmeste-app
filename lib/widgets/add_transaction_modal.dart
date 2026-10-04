// lib/widgets/add_transaction_modal.dart

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
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
  final _amountController = TextEditingController();
  final _commentController = TextEditingController();

  String _type = 'expense';
  String _nature = 'conscious';
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTransaction != null) {
      final t = widget.initialTransaction!;
      _amountController.text = t.amount.toString();
      _commentController.text = t.comment;
      _type = t.type;
      _nature = t.nature;
      _selectedCategoryId = t.categoryId;
      _selectedDate = t.date;
    } else {
      if (widget.categories.isNotEmpty) {
        _selectedCategoryId = widget.categories.first.id;
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) {
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка распознавания: $val')),
          );
        },
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            setState(() {
              _commentController.text = val.recognizedWords;
              final numberRegex = RegExp(r'\d+([.,]\d+)?');
              final match = numberRegex.firstMatch(val.recognizedWords);
              if (match != null && _amountController.text.isEmpty) {
                _amountController.text = match.group(0)!.replaceAll(',', '.');
              }
            });
          },
          localeId: 'ru_RU',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Голосовой ввод недоступен на этом устройстве')),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _save() {
    final amountText = _amountController.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(amountText) ?? 0.0;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введи сумму больше нуля')),
      );
      return;
    }

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выбери категорию')),
      );
      return;
    }

    final newTransaction = Transaction(
      id: widget.initialTransaction?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: _type,
      amount: amount,
      categoryId: _selectedCategoryId!,
      comment: _commentController.text.trim(),
      nature: _nature,
      date: _selectedDate,
      createdAt: widget.initialTransaction?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    widget.onSave(newTransaction);
    Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = widget.categories.where((c) => c.type == _type).toList();

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.initialTransaction == null ? 'Новая транзакция' : 'Редактировать',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Расход'),
                    selected: _type == 'expense',
                    onSelected: (val) => setState(() {
                      _type = 'expense';
                      _selectedCategoryId = null;
                    }),
                    selectedColor: Colors.red.withOpacity(0.2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Доход'),
                    selected: _type == 'income',
                    onSelected: (val) => setState(() {
                      _type = 'income';
                      _selectedCategoryId = null;
                    }),
                    selectedColor: Colors.green.withOpacity(0.2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Сумма',
                      border: OutlineInputBorder(),
                      prefixText: '₽ ',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _listen,
                  icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                  color: _isListening ? Colors.red : null,
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Комментарий (например, Пятёрочка)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            const Text('Категория', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            if (filteredCategories.isEmpty)
              const Text('Нет категорий. Создай их в разделе "Категории".', style: TextStyle(color: Colors.grey))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: filteredCategories.map((cat) {
                  final isSelected = cat.id == _selectedCategoryId;
                  return ChoiceChip(
                    label: Text('${cat.emoji} ${cat.name}'),
                    selected: isSelected,
                    onSelected: (val) => setState(() => _selectedCategoryId = cat.id),
                    selectedColor: cat.color.withOpacity(0.3),
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),

            if (_type == 'expense') ...[
              const Text('Тип траты', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('🔴 Обязательное'),
                    selected: _nature == 'obligatory',
                    onSelected: (val) => setState(() => _nature = 'obligatory'),
                  ),
                  ChoiceChip(
                    label: const Text('🟡 Осознанное'),
                    selected: _nature == 'conscious',
                    onSelected: (val) => setState(() => _nature = 'conscious'),
                  ),
                  ChoiceChip(
                    label: const Text('🟢 Импульсивное'),
                    selected: _nature == 'impulsive',
                    onSelected: (val) => setState(() => _nature = 'impulsive'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20),
                    const SizedBox(width: 8),
                    Text('${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8FAB),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Сохранить', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}