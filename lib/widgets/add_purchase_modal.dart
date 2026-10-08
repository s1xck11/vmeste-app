// lib/widgets/add_purchase_modal.dart

import 'package:flutter/material.dart';
import '../models/purchase.dart';
import '../models/purchase_list.dart';
import '../models/purchase_category.dart';

class AddPurchaseModal extends StatefulWidget {
  final List<PurchaseCategory> categories;
  final List<PurchaseList> lists;
  final String initialListId;
  final String initialText;
  final Purchase? initialPurchase;
  final Function(Purchase) onSave;

  const AddPurchaseModal({
    super.key,
    required this.categories,
    required this.lists,
    required this.initialListId,
    this.initialText = '',
    this.initialPurchase,
    required this.onSave,
  });

  @override
  State<AddPurchaseModal> createState() => _AddPurchaseModalState();
}

class _AddPurchaseModalState extends State<AddPurchaseModal> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  String _unit = 'шт';
  String _categoryId = 'other';
  late String _listId;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _listId = widget.initialListId;
    if (widget.initialPurchase != null) {
      final p = widget.initialPurchase!;
      _nameCtrl.text = p.text;
      _qtyCtrl.text = p.qty.toString();
      _priceCtrl.text = p.price > 0 ? p.price.toString() : '';
      _unit = p.unit;
      _categoryId = p.category;
      _listId = p.listId;
      _showDetails = true;
    } else {
      _nameCtrl.text = widget.initialText;
      if (widget.categories.isNotEmpty) {
        _categoryId = widget.categories.first.id;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    FocusScope.of(context).unfocus();
    final qty = double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 1;
    final price = double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    final p = Purchase(
      id: widget.initialPurchase?.id ?? now,
      text: name,
      done: widget.initialPurchase?.done ?? false,
      missing: widget.initialPurchase?.missing ?? false,
      category: _categoryId,
      qty: qty,
      unit: _unit,
      price: price,
      listId: _listId,
      order: widget.initialPurchase?.order ?? now,
      createdAt: widget.initialPurchase?.createdAt ?? now,
      updatedAt: now,
    );
    widget.onSave(p);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.initialPurchase == null ? 'Новая покупка' : 'Редактировать',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _nameCtrl,
                autofocus: widget.initialPurchase == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  hintText: 'Молоко',
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'КАТЕГОРИЯ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.categories.map((c) {
                  final sel = c.id == _categoryId;
                  return GestureDetector(
                    onTap: () => setState(() => _categoryId = c.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? cs.primaryContainer : cs.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel ? cs.primary : cs.outline,
                          width: sel ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        '${c.emoji} ${c.label}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                          color: sel ? cs.onPrimaryContainer : cs.onSurface,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Кнопка «С деталями»
              InkWell(
                onTap: () => setState(() => _showDetails = !_showDetails),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(_showDetails ? Icons.expand_less : Icons.expand_more,
                          color: cs.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _showDetails ? 'Скрыть детали' : 'Количество и цена',
                        style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),

              if (_showDetails) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Кол-во'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: DropdownButtonFormField<String>(
                        value: _unit,
                        items: const [
                          DropdownMenuItem(value: 'шт', child: Text('шт')),
                          DropdownMenuItem(value: 'кг', child: Text('кг')),
                          DropdownMenuItem(value: 'г', child: Text('г')),
                          DropdownMenuItem(value: 'л', child: Text('л')),
                          DropdownMenuItem(value: 'мл', child: Text('мл')),
                          DropdownMenuItem(value: 'упак', child: Text('упак')),
                        ],
                        onChanged: (v) => setState(() => _unit = v ?? 'шт'),
                        decoration: const InputDecoration(labelText: 'Ед.'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Цена за единицу',
                    suffixText: '₽',
                  ),
                ),
              ],

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        Navigator.pop(context);
                      },
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Добавить'),
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
}