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
  final Function(String) onDelete;

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

class _AddShiftModalState extends State<AddShiftModal> {
  String _partnerId = '';
  String _typeId = '';
  TimeOfDay _start = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 22, minute: 0);
  final _notesCtrl = TextEditingController();
  final _pieceworkCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.partners.isNotEmpty) _partnerId = widget.partners[0].id;
    if (widget.types.isNotEmpty) _typeId = widget.types[0].id;
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _pieceworkCtrl.dispose();
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

  void _save() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final s = Shift(
      id: now,
      date: widget.dateKey,
      partner: _partnerId,
      type: _typeId,
      hours: _hours,
      startTime: '${_start.hour.toString().padLeft(2, '0')}:${_start.minute.toString().padLeft(2, '0')}',
      endTime: '${_end.hour.toString().padLeft(2, '0')}:${_end.minute.toString().padLeft(2, '0')}',
      notes: _notesCtrl.text.trim(),
      pieceworkAmount: _partner.payType == 'piecework'
          ? double.tryParse(_pieceworkCtrl.text.replaceAll(',', '.'))
          : null,
      income: null,
      location: '',
      importedFrom: '',
      notification: 60,
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

              // Существующие смены
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
                    orElse: () => ShiftType(id: s.type, label: s.type, hours: s.hours, color: '#9E9E9E', order: 0),
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
                    onTap: () => setState(() => _partnerId = p.id),
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
                    onTap: () => setState(() => _typeId = t.id),
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

              // Сдельная сумма
              if (_partner.payType == 'piecework') ...[
                _sectionLabel(cs, 'Сумма за смену (сдельная)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _pieceworkCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Сумма', suffixText: '₽'),
                ),
                const SizedBox(height: 16),
              ],

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