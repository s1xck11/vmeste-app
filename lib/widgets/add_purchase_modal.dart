import 'package:flutter/material.dart';
import '../models/purchase.dart';
import '../models/purchase_category.dart';
import '../main.dart' show AppColors;

/// Модалка добавления/редактирования покупки.
class AddPurchaseModal extends StatefulWidget {
  final Purchase? existing;
  final String listId;
  final String defaultText;
  final List<PurchaseCategory> categories;
  final String? Function() currentUserIdGetter;

  const AddPurchaseModal({
    super.key,
    this.existing,
    required this.listId,
    this.defaultText = '',
    required this.categories,
    required this.currentUserIdGetter,
  });

  @override
  State<AddPurchaseModal> createState() => _AddPurchaseModalState();
}

class _AddPurchaseModalState extends State<AddPurchaseModal> {
  late TextEditingController _textController;
  late TextEditingController _qtyController;
  late TextEditingController _priceController;

  String _category = 'other';
  String _unit = 'шт';

  final List<String> _units = ['шт', 'кг', 'г', 'л', 'мл', 'упак'];

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _textController = TextEditingController(text: p?.text ?? widget.defaultText);
    _qtyController = TextEditingController(
      text: (p?.qty ?? 1).toString().replaceAll('.0', ''),
    );
    _priceController = TextEditingController(
      text: (p?.price ?? 0).toString().replaceAll('.0', ''),
    );
    _category = p?.category ?? 'other';
    _unit = p?.unit ?? 'шт';
  }

  @override
  void dispose() {
    _textController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _save() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введи название')),
      );
      return;
    }

    final qty = double.tryParse(_qtyController.text.replaceAll(',', '.')) ?? 1;
    final price = double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0;

    final now = DateTime.now().millisecondsSinceEpoch;
    final result = widget.existing != null
        ? widget.existing!.copyWith(
            text: text,
            category: _category,
            qty: qty,
            unit: _unit,
            price: price,
            updatedAt: now,
            updatedBy: widget.currentUserIdGetter(),
          )
        : Purchase(
            id: now,
            text: text,
            category: _category,
            qty: qty,
            unit: _unit,
            price: price,
            listId: widget.listId,
            createdAt: now,
            updatedAt: now,
            updatedBy: widget.currentUserIdGetter(),
          );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Заголовок
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.existing == null ? 'Новый товар' : 'Редактировать',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Название
                TextField(
                  controller: _textController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Название',
                    hintText: 'Молоко',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Категория
                const Text(
                  'Категория',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.categories.map((c) {
                    final selected = _category == c.id;
                    return GestureDetector(
                      onTap: () => setState(() => _category = c.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.accentLight
                              : AppColors.cardLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? AppColors.accent
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(c.emoji),
                            const SizedBox(width: 4),
                            Text(
                              c.label,
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Количество + единица
                const Text(
                  'Количество',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _qtyController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText: '1',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _unit,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _units.map((u) {
                          return DropdownMenuItem(value: u, child: Text(u));
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _unit = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Цена
                const Text(
                  'Цена за единицу (₽)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Кнопки
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Сохранить',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}