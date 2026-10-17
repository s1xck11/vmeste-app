import 'package:flutter/material.dart';
import '../models/shift.dart';
import '../models/shift_type.dart';
import '../models/partner.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../widgets/glass_container.dart';

/// Полноэкранный экран «Смены» (сверху от центра).
class HubShiftsScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;

  const HubShiftsScreen({
    super.key,
    required this.storage,
    required this.sync,
  });

  @override
  State<HubShiftsScreen> createState() => _HubShiftsScreenState();
}

class _HubShiftsScreenState extends State<HubShiftsScreen> {
  DateTime _currentMonth = DateTime.now();
  List<Shift> _shifts = [];
  List<ShiftType> _types = [];
  List<Partner> _partners = [];

  @override
  void initState() {
    super.initState();
    _load();
    widget.sync.addListener(_load);
  }

  @override
  void dispose() {
    widget.sync.removeListener(_load);
    super.dispose();
  }

  void _load() {
    if (!mounted) return;
    setState(() {
      _shifts = widget.storage.shifts;
      _types = widget.storage.shiftTypes;
      _partners = widget.storage.partners;
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta, 1);
    });
  }

  double _calcSalary(Shift s) {
    if (s.importedFrom == 'courier-helper' && s.income != null) {
      return s.income!.toDouble();
    }
    final partner = _partners.firstWhere(
      (p) => p.id == s.partner,
      orElse: () => Partner(id: s.partner, name: '', rate: 0, payType: 'hourly'),
    );
    if (partner.payType == 'piecework') {
      return (s.pieceworkAmount ?? 0).toDouble();
    }
    if (partner.payType == 'fixed') return partner.rate.toDouble();
    return s.hours * partner.rate;
  }

  double _monthTotal() {
    double sum = 0;
    final prefix = '${_currentMonth.year}-${_currentMonth.month < 10 ? '0${_currentMonth.month}' : _currentMonth.month}';
    for (final s in _shifts) {
      if (s.date.startsWith(prefix)) sum += _calcSalary(s);
    }
    return sum;
  }

  double _partnerTotal(String partnerId) {
    double sum = 0;
    final prefix = '${_currentMonth.year}-${_currentMonth.month < 10 ? '0${_currentMonth.month}' : _currentMonth.month}';
    for (final s in _shifts) {
      if (!s.date.startsWith(prefix)) continue;
      if (s.partner == partnerId) sum += _calcSalary(s);
    }
    return sum;
  }

  int _partnerCount(String partnerId) {
    final prefix = '${_currentMonth.year}-${_currentMonth.month < 10 ? '0${_currentMonth.month}' : _currentMonth.month}';
    return _shifts.where((s) => s.date.startsWith(prefix) && s.partner == partnerId).length;
  }

  String _monthName(int m) {
    const names = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
    return names[m - 1];
  }

  String _dateKey(DateTime d) {
    return '${d.year}-${d.month < 10 ? '0${d.month}' : d.month}-${d.day < 10 ? '0${d.day}' : d.day}';
  }

  List<Shift> _shiftsForDay(DateTime day) {
    final key = _dateKey(day);
    return _shifts.where((s) => s.date == key).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Шапка
          Row(
            children: [
              Icon(Icons.calendar_today, color: cs.secondary, size: 28),
              const SizedBox(width: 10),
              Text(
                'Смены',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                // Левая часть: календарь
                Expanded(
                  flex: 2,
                  child: GlassContainer(
                    radius: 28,
                    showAllBorder: true,
                    padding: const EdgeInsets.all(20),
                    child: _buildCalendar(cs),
                  ),
                ),
                const SizedBox(width: 16),
                // Правая часть: сводка
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      _buildTotalCard(cs),
                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: _partners.map((p) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildPartnerCard(p, cs),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(ColorScheme cs) {
    final year = _currentMonth.year;
    final month = _currentMonth.month;
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final startWeekday = firstDay.weekday;
    final daysInMonth = lastDay.day;
    final today = DateTime.now();
    final weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

    return Column(
      children: [
        // Навигация по месяцам
        Row(
          children: [
            IconButton(
              onPressed: () => _changeMonth(-1),
              icon: Icon(Icons.chevron_left, color: cs.onSurface, size: 28),
            ),
            Expanded(
              child: Text(
                '${_monthName(month)} $year',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ),
            IconButton(
              onPressed: () => _changeMonth(1),
              icon: Icon(Icons.chevron_right, color: cs.onSurface, size: 28),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Дни недели
        Row(
          children: weekdays.map((w) => Expanded(
            child: Center(
              child: Text(
                w,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          )).toList(),
        ),
        const SizedBox(height: 8),
        // Сетка дней
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ((startWeekday - 1) + daysInMonth + 6) ~/ 7 * 7,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (ctx, i) {
              final dayIndex = i - (startWeekday - 1) + 1;
              if (dayIndex < 1 || dayIndex > daysInMonth) {
                return const SizedBox.shrink();
              }
              final day = DateTime(year, month, dayIndex);
              final shifts = _shiftsForDay(day);
              final isToday = day.year == today.year &&
                  day.month == today.month &&
                  day.day == today.day;

              double dayTotal = 0;
              for (final s in shifts) {
                dayTotal += _calcSalary(s);
              }

              return Container(
                decoration: BoxDecoration(
                  color: isToday ? cs.primary : cs.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isToday ? cs.primary : cs.outline.withOpacity(0.5),
                  ),
                ),
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$dayIndex',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                        color: isToday ? cs.onPrimary : cs.onSurface,
                      ),
                    ),
                    const Spacer(),
                    if (shifts.isNotEmpty) ...[
                      Row(
                        children: shifts.take(3).map((s) {
                          final t = _types.firstWhere(
                            (x) => x.id == s.type,
                            orElse: () => ShiftType(id: s.type, label: '', hours: 0, color: '#9E9E9E'),
                          );
                          return Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 2),
                            decoration: BoxDecoration(
                              color: _parseColor(t.color),
                              shape: BoxShape.circle,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 2),
                      if (dayTotal > 0)
                        Text(
                          dayTotal >= 1000
                              ? '${(dayTotal / 1000).toStringAsFixed(1)}к'
                              : dayTotal.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isToday ? cs.onPrimary.withOpacity(0.9) : cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTotalCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Зарплата за ${_monthName(_currentMonth.month).toLowerCase()}',
            style: TextStyle(fontSize: 13, color: cs.onPrimary.withOpacity(0.85)),
          ),
          const SizedBox(height: 6),
          Text(
            '${_monthTotal().toStringAsFixed(0)} ₽',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: cs.onPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerCard(Partner p, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.name,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_partnerTotal(p.id).toStringAsFixed(0)} ₽',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${_partnerCount(p.id)} смен',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return const Color(0xFF9E9E9E);
    }
  }
}