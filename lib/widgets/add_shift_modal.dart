import 'package:flutter/material.dart';
import '../models/shift.dart';
import '../models/shift_type.dart';
import '../models/partner.dart';
import '../main.dart' show AppColors;

/// Модалка добавления/редактирования смены.
class AddShiftModal extends StatefulWidget {
  final Shift? existing;
  final String date; // 'YYYY-MM-DD'
  final List<ShiftType> shiftTypes;
  final List<Partner> partners;
  final String currentPartnerId;
  final String? Function() currentUserIdGetter;

  const AddShiftModal({
    super.key,
    this.existing,
    required this.date,
    required this.shiftTypes,
    required this.partners,
    required this.currentPartnerId,
    required this.currentUserIdGetter,
  });

  @override
  State<AddShiftModal> createState() => _AddShiftModalState();
}

class _AddShiftModalState extends State<AddShiftModal> {
  late TextEditingController _notesController;
  late TextEditingController _pieceworkController;

  String _partner = 'partner1';
  String _shiftType = 'day';
  String _startTime = '10:00';
  String _endTime = '22:00';

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _partner = s?.partner ?? widget.currentPartnerId;
    _shiftType = s?.type ?? widget.shiftTypes.first.id;
    _startTime = s?.startTime ?? '10:00';
    _endTime = s?.endTime ?? '22:00';
    _notesController = TextEditingController(text: s?.notes ?? '');
    _pieceworkController = TextEditingController(
      text: s?.pieceworkAmount?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    _pieceworkController.dispose();
    super.dispose();
  }

  double _calculateHours() {
    try {
      final sp = _startTime.split(':');
      final ep = _endTime.split(':');
      final sh = int.parse(sp[0]);
      final sm = int.parse(sp[1]);
      final eh = int.parse(ep[0]);
      final em = int.parse(ep[1]);
      var minutes = (eh * 60 + em) - (sh * 60 + sm);
      if (minutes < 0) minutes += 24 * 60;
      return (minutes / 60 * 100).round() / 100;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final current = isStart ? _startTime : _endTime;
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 10,
      minute: int.tryParse(parts[1]) ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      final str =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isStart) {
          _startTime = str;
        } else {
          _endTime = str;
        }
      });
    }
  }

  void _save() {
    final hours = _calculateHours();
    final notes = _notesController.text.trim();
    final now = DateTime.now().millisecondsSinceEpoch;

    double? piecework;
    final selectedPartner =
        widget.partners.firstWhere((p) => p.id == _partner, orElse: () => widget.partners.first);
    if (selectedPartner.payType == 'piecework') {
      final txt = _pieceworkController.text.trim();
      if (txt.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Введи сумму за смену')),
        );
        return;
      }
      piecework = double.tryParse(txt.replaceAll(',', '.'));
      if (piecework == null || piecework <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Некорректная сумма')),
        );
        return;
      }
    }

    final result = widget.existing != null
        ? widget.existing!.copyWith(
            partner: _partner,
            type: _shiftType,
            hours: hours,
            startTime: _startTime,
            endTime: _endTime,
            notes: notes,
            pieceworkAmount: piecework,
            updatedAt: now,
            updatedBy: widget.currentUserIdGetter(),
          )
        : Shift(
            id: now,
            date: widget.date,
            partner: _partner,
            type: _shiftType,
            hours: hours,
            startTime: _startTime,
            endTime: _endTime,
            notes: notes,
            pieceworkAmount: piecework,
            createdAt: now,
            updatedAt: now,
            updatedBy: widget.currentUserIdGetter(),
          );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final selectedPartner = widget.partners.firstWhere(
      (p) => p.id == _partner,
      orElse: () => widget.partners.first,
    );
    final showPiecework = selectedPartner.payType == 'piecework';
    final hours = _calculateHours();

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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.existing == null ? 'Новая смена' : 'Редактировать смену',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.date,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Кто работает
                _label('Кто работает'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: widget.partners.map((p) {
                    final selected = _partner == p.id;
                    return GestureDetector(
                      onTap: () => setState(() => _partner = p.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
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
                        child: Text(
                          p.name,
                          style: TextStyle(
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Тип смены
                _label('Тип смены'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.shiftTypes.map((t) {
                    final selected = _shiftType == t.id;
                    return GestureDetector(
                      onTap: () => setState(() => _shiftType = t.id),
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
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _parseColor(t.color),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              t.label,
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Время
                _label('Время'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickTime(true),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Начало',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              _startTime,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickTime(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Конец',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              _endTime,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Часы
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.access_time,
                          size: 18, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Text(
                        'Часов: $hours',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Сдельная оплата
                if (showPiecework) ...[
                  _label('💰 Сумма за смену (сдельная оплата)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pieceworkController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      hintText: '0 ₽',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Заметки
                _label('📝 Заметки'),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Заметки о смене...',
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

  Widget _label(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      final cleaned = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (e) {
      return AppColors.accent;
    }
  }
}