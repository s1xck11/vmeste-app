// lib/widgets/add_shift_modal.dart

import 'package:flutter/material.dart';
import '../models/shift.dart';
import '../models/shift_type.dart';
import '../models/partner.dart';

class AddShiftModal extends StatefulWidget {
  final String dateKey;
  final DateTime date;
  final List<ShiftType> types;
  final List<Partner> partners;
  final List<Shift> existingShifts;
  final Function(Shift) onSave;
  final Function(int) onDelete;

  const AddShiftModal({
    super.key,
    required this.dateKey,
    required this.date,
    required this.types,
    required this.partners,
    required this.existingShifts,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<AddShiftModal> createState() => _AddShiftModalState();
}

class _ExtraComponent {
  String typeId;
  String mode; // 'hourly' | 'piecework'
  final TextEditingController hoursCtrl = TextEditingController(text: '0');
  final TextEditingController rateCtrl = TextEditingController(text: '0');
  final TextEditingController amountCtrl = TextEditingController(text: '0');

  _ExtraComponent({required this.typeId, this.mode = 'hourly'});

  void dispose() {
    hoursCtrl.dispose();
    rateCtrl.dispose();
    amountCtrl.dispose();
  }
}

class _AddShiftModalState extends State<AddShiftModal> {
  String _partnerId = '';
  String _typeId = '';
  String _mode = 'hourly'; // НОВОЕ: режим оплаты основной смены
  TimeOfDay _start = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 22, minute: 0);
  final _notesCtrl = TextEditingController();
  final _pieceworkCtrl = TextEditingController();
  final _rateCtrl = TextEditingController(text: '0'); // НОВОЕ: ставка основной смены
  final List<_ExtraComponent> _extras = []; // НОВОЕ: доп. компоненты дохода

  @override
  void initState() {
    super.initState();
    if (widget.partners.isNotEmpty) _partnerId = widget.partners[0].id;
    if (widget.types.isNotEmpty) _typeId = widget.types[0].id;
    _mode = _partner.payType == 'piecework' ? 'piecework' : 'hourly';
    _prefillRate();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _pieceworkCtrl.dispose();
    _rateCtrl.dispose();
    for (final e in _extras) {
      e.dispose();
    }
    super.dispose();
  }

  double get _hours {
    final start = _start.hour * 60 + _start.minute;
    final end = _end.hour * 60 + _end.minute;
    int diff = end - start;
    if (diff < 0) diff += 1440;
    return (diff / 60 * 100) / 100;
  }

  Partner get _partner => widget.partners.firstWhere(
        (p) => p.id == _partnerId,
        orElse: () => Partner(id: _partnerId, name: '', rate: 0, payType: 'hourly'),
      );

  ShiftType get _type => widget.types.firstWhere(
        (t) => t.id == _typeId,
        orElse: () => ShiftType(id: _typeId, label: _typeId, hours: 0, color: '#9E9E9E'),
      );

  double get _rate => double.tryParse(_rateCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _piecework => double.tryParse(_pieceworkCtrl.text.replaceAll(',', '.')) ?? 0;

  /// НОВОЕ: предзаполнение ставки из типа смены или партнёра
  void _prefillRate() {
    final t = _type;
    final fallback = _partner.rate;
    _rateCtrl.text = (t.rate > 0 ? t.rate : fallback).toStringAsFixed(0);
  }

  /// НОВОЕ: итоговая сумма по всем компонентам
  double get _totalPreview {
    double sum = 0;
    if (_mode == 'piecework') {
      sum += _piecework;
    } else {
      sum += _hours * _rate;
    }
    for (final e in _extras) {
      final h = double.tryParse(e.hoursCtrl.text.replaceAll(',', '.')) ?? 0;
      final r = double.tryParse(e.rateCtrl.text.replaceAll(',', '.')) ?? 0;
      final a = double.tryParse(e.amountCtrl.text.replaceAll(',', '.')) ?? 0;
      sum += e.mode == 'piecework' ? a : h * r;
    }
    return sum;
  }

  void _save() {
    final now = DateTime.now().millisecondsSinceEpoch;

    // НОВОЕ: собираем компоненты дохода (основной + дополнительные)
    final components = <ShiftIncomeComponent>[
      ShiftIncomeComponent(
        typeId: _typeId,
        mode: _mode,
        hours: _mode == 'hourly' ? _hours : 0,
        rate: _mode == 'hourly' ? _rate : 0,
        amount: _mode == 'piecework' ? _piecework : 0,
      ),
      ..._extras.map((e) => ShiftIncomeComponent(
            typeId: e.typeId,
            mode: e.mode,
            hours: e.mode == 'hourly'
                ? (double.tryParse(e.hoursCtrl.text.replaceAll(',', '.')) ?? 0)
                : 0,
            rate: e.mode == 'hourly'
                ? (double.tryParse(e.rateCtrl.text.replaceAll(',', '.')) ?? 0)
                : 0,
            amount: e.mode == 'piecework'
                ? (double.tryParse(e.amountCtrl.text.replaceAll(',', '.')) ?? 0)
                : 0,
          )),
    ];

    final s = Shift(
      id: now,
      date: widget.dateKey,
      partner: _partnerId,
      type: _typeId,
      hours: _hours,
      startTime: '${_start.hour.toString().padLeft(2, '0')}:${_start.minute.toString().padLeft(2, '0')}',
      endTime: '${_end.hour.toString().padLeft(2, '0')}:${_end.minute.toString().padLeft(2, '0')}',
      notes: _notesCtrl.text.trim(),
      pieceworkAmount: _mode == 'piecework' ? _piecework : null,
      income: null,
      location: '',
      importedFrom: '',
      notification: 60,
      components: components, // НОВОЕ
      createdAt: now,
      updatedAt: now,
    );
    widget.onSave(s);
    Navigator.pop(context);
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (picked != null) {
      setState(() {
        if (start) _start = picked;
        else _end = picked;
      });
    }
  }

  Color _parseColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return const Color(0xFF9E9E9E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

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
                  decoration: BoxDecoration(
                    color: cs.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Смена ${widget.date.day}.${widget.date.month}.${widget.date.year}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: cs.onSurface),
              ),
              const SizedBox(height: 16),

              if (widget.existingShifts.isNotEmpty) ...[
                _sectionLabel(cs, 'Смены в этот день'),
                const SizedBox(height: 8),
                ...widget.existingShifts.map((s) {
                  final p = widget.partners.firstWhere(
                    (x) => x.id == s.partner,
                    orElse: () => Partner(id: s.partner, name: s.partner, rate: 0, payType: 'hourly'),
                  );
                  final t = widget.types.firstWhere(
                    (x) => x.id == s.type,
                    orElse: () => ShiftType(id: s.type, label: s.type, hours: s.hours, color: '#9E9E9E'),
                  );
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 12, height: 12,
                          decoration: BoxDecoration(
                            color: _parseColor(t.color),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${p.name} · ${t.label}',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
                              Text('${s.startTime}–${s.endTime} · ${s.hours}ч',
                                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            widget.onDelete(s.id);
                            Navigator.pop(context);
                          },
                          icon: Icon(Icons.delete_outline, color: cs.error),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],

              _sectionLabel(cs, 'Кто работает'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: widget.partners.map((p) {
                  final sel = p.id == _partnerId;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _partnerId = p.id;
                      _mode = p.payType == 'piecework' ? 'piecework' : 'hourly';
                      _prefillRate();
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? cs.primaryContainer : cs.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? cs.primary : cs.outline),
                      ),
                      child: Text(p.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                            color: sel ? cs.onPrimaryContainer : cs.onSurface,
                          )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              _sectionLabel(cs, 'Тип смены'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: widget.types.map((t) {
                  final sel = t.id == _typeId;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _typeId = t.id;
                      _prefillRate();
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? cs.primaryContainer : cs.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? cs.primary : cs.outline),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              color: _parseColor(t.color),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(t.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                                color: sel ? cs.onPrimaryContainer : cs.onSurface,
                              )),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              // НОВОЕ: подсказка по типу смены (часы и ставка по умолчанию)
              Text(
                'По умолчанию: ${_type.hours.toStringAsFixed(0)}ч · ${_type.rate.toStringAsFixed(0)} ₽/час',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),

              _sectionLabel(cs, 'Время'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickTime(true),
                      icon: const Icon(Icons.schedule, size: 18),
                      label: Text('Начало: ${_start.hour.toString().padLeft(2, '0')}:${_start.minute.toString().padLeft(2, '0')}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickTime(false),
                      icon: const Icon(Icons.schedule, size: 18),
                      label: Text('Конец: ${_end.hour.toString().padLeft(2, '0')}:${_end.minute.toString().padLeft(2, '0')}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: cs.onPrimaryContainer, size: 18),
                    const SizedBox(width: 8),
                    Text('Часов: ${_hours.toStringAsFixed(1)}',
                        style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // НОВОЕ: режим оплаты
              _sectionLabel(cs, 'Оплата основной смены'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _mode = 'hourly'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _mode == 'hourly' ? cs.primaryContainer : cs.surfaceVariant,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _mode == 'hourly' ? cs.primary : Colors.transparent, width: 1.5),
                        ),
                        child: Center(
                          child: Text('Почасовая',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _mode == 'hourly' ? FontWeight.w700 : FontWeight.w500,
                                color: _mode == 'hourly' ? cs.onPrimaryContainer : cs.onSurface,
                              )),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _mode = 'piecework'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _mode == 'piecework' ? cs.primaryContainer : cs.surfaceVariant,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _mode == 'piecework' ? cs.primary : Colors.transparent, width: 1.5),
                        ),
                        child: Center(
                          child: Text('Сдельная',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _mode == 'piecework' ? FontWeight.w700 : FontWeight.w500,
                                color: _mode == 'piecework' ? cs.onPrimaryContainer : cs.onSurface,
                              )),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_mode == 'hourly')
                TextField(
                  controller: _rateCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Ставка за час',
                    suffixText: '₽/час',
                  ),
                )
              else
                TextField(
                  controller: _pieceworkCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Сумма за смену (сдельная)',
                    suffixText: '₽',
                  ),
                ),
              const SizedBox(height: 16),

              // НОВОЕ: дополнительные компоненты дохода
              _sectionLabel(cs, 'Дополнительный доход'),
              const SizedBox(height: 8),
              ..._extras.asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outline.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: e.typeId,
                              isExpanded: true,
                              items: widget.types
                                  .map((t) => DropdownMenuItem(value: t.id, child: Text(t.label)))
                                  .toList(),
                              onChanged: (v) => setState(() => e.typeId = v ?? e.typeId),
                              decoration: const InputDecoration(
                                labelText: 'Тип',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() => e.mode = e.mode == 'hourly' ? 'piecework' : 'hourly'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: cs.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: cs.outline),
                              ),
                              child: Text(
                                e.mode == 'hourly' ? '₽/час' : 'сдел.',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.primary),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: 18, color: cs.error),
                            onPressed: () {
                              setState(() {
                                _extras.removeAt(i).dispose();
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (e.mode == 'hourly') ...[
                            Expanded(
                              child: TextField(
                                controller: e.hoursCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Часы', isDense: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: e.rateCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Ставка', isDense: true),
                              ),
                            ),
                          ] else
                            Expanded(
                              child: TextField(
                                controller: e.amountCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Сумма', isDense: true),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _extras.add(_ExtraComponent(
                    typeId: _typeId,
                    mode: 'hourly',
                  )..rateCtrl.text = _type.rate > 0 ? _type.rate.toStringAsFixed(0) : _partner.rate.toStringAsFixed(0));
                }),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Добавить доход'),
              ),
              const SizedBox(height: 16),

              // НОВОЕ: итоговая превью-сумма
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary.withOpacity(0.15), cs.secondary.withOpacity(0.15)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.payments_outlined, color: cs.primary, size: 20),
                    const SizedBox(width: 10),
                    Text('Итого за смену:',
                        style: TextStyle(fontSize: 13, color: cs.onSurface)),
                    const Spacer(),
                    Text('${_totalPreview.toStringAsFixed(0)} ₽',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cs.primary)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _sectionLabel(cs, 'Заметки'),
              const SizedBox(height: 8),
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Заметки о смене...'),
              ),
              const SizedBox(height: 20),

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

  Widget _sectionLabel(ColorScheme cs, String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700,
        color: cs.onSurfaceVariant, letterSpacing: 0.5,
      ),
    );
  }
}