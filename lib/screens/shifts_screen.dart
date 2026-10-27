// lib/screens/shifts_screen.dart

import 'package:flutter/material.dart';
import '../models/shift.dart';
import '../models/shift_type.dart';
import '../models/partner.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/theme_service.dart';
import '../widgets/modern_app_bar.dart';
import '../widgets/add_shift_modal.dart';

class ShiftsScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;
  final ThemeService themeService;
  final VoidCallback onAvatarTap;

  const ShiftsScreen({
    super.key,
    required this.storage,
    required this.sync,
    required this.themeService,
    required this.onAvatarTap,
  });

  @override
  State<ShiftsScreen> createState() => ShiftsScreenState();
}

class ShiftsScreenState extends State<ShiftsScreen> {
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

  Future<void> _refresh() async {
    await widget.sync.forcePullNow();
    _load();
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta, 1);
    });
  }

  String _key(int y, int m, int d) =>
      '$y-${m < 10 ? '0$m' : m}-${d < 10 ? '0$d' : d}';

  List<Shift> _shiftsForDay(DateTime day) {
    final key = _key(day.year, day.month, day.day);
    return _shifts.where((s) => s.date == key).toList();
  }

  // ИСПРАВЛЕНО: Безопасный парсинг без использования '!'
  double _calcSalary(Shift s) {
    if (s.importedFrom == 'courier-helper') {
      return (s.income is num) ? (s.income as num).toDouble() : 0.0;
    }
    final partner = _partners.firstWhere(
      (p) => p.id == s.partner,
      orElse: () => Partner(id: s.partner, name: '', rate: 0, payType: 'hourly'),
    );
    if (partner.payType == 'piecework') {
      return (s.pieceworkAmount is num) ? (s.pieceworkAmount as num).toDouble() : 0.0;
    }
    if (partner.payType == 'fixed') return partner.rate.toDouble();
    
    final hours = (s.hours is num) ? (s.hours as num).toDouble() : 0.0;
    return hours * partner.rate;
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

  int _partnerShiftCount(String partnerId) {
    final prefix = '${_currentMonth.year}-${_currentMonth.month < 10 ? '0${_currentMonth.month}' : _currentMonth.month}';
    return _shifts.where((s) => s.date.startsWith(prefix) && s.partner == partnerId).length;
  }

  double _partnerHours(String partnerId) {
    final prefix = '${_currentMonth.year}-${_currentMonth.month < 10 ? '0${_currentMonth.month}' : _currentMonth.month}';
    double hours = 0;
    for (final s in _shifts) {
      if (s.date.startsWith(prefix) && s.partner == partnerId) {
        hours += (s.hours is num) ? (s.hours as num).toDouble() : 0.0;
      }
    }
    return hours;
  }

  String _monthName(int m) {
    const names = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
    return names[m - 1];
  }

  void _openAddForDay(DateTime day) {
    final key = _key(day.year, day.month, day.day);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddShiftModal(
        dateKey: key,
        date: day,
        types: _types,
        partners: _partners,
        existingShifts: _shiftsForDay(day),
        onSave: (s) {
          final list = List<Shift>.from(_shifts)..add(s);
          widget.storage.shifts = list;
          _load();
          widget.sync.schedulePush();
        },
        onDelete: (id) {
          final list = List<Shift>.from(_shifts)
            ..removeWhere((e) => e.id == id);
          widget.storage.shifts = list;
          _load();
          widget.sync.schedulePush();
        },
      ),
    );
  }

  void openAddForToday() {
    _openAddForDay(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final partner1 = _partners.isNotEmpty ? _partners[0] : null;
    final partner2 = _partners.length > 1 ? _partners[1] : null;
    final total = _monthTotal();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          ModernAppBar(
            title: 'Смены',
            onAvatarTap: widget.onAvatarTap,
            avatarEmoji: widget.storage.myAvatar,
          ),
          Expanded(
            child: RefreshIndicator(
              color: cs.primary,
              backgroundColor: cs.surface,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 180),
                children: [
                  _buildSalaryCard(total, cs),
                  const SizedBox(height: 12),
                  if (partner1 != null || partner2 != null)
                    Row(
                      children: [
                        if (partner1 != null)
                          Expanded(
                            child: _buildPartnerCard(
                              partner1,
                              _partnerTotal(partner1.id),
                              _partnerShiftCount(partner1.id),
                              _partnerHours(partner1.id),
                              cs,
                            ),
                          ),
                        if (partner1 != null && partner2 != null)
                          const SizedBox(width: 12),
                        if (partner2 != null)
                          Expanded(
                            child: _buildPartnerCard(
                              partner2,
                              _partnerTotal(partner2.id),
                              _partnerShiftCount(partner2.id),
                              _partnerHours(partner2.id),
                              cs,
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  _buildCalendar(cs),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddForDay(DateTime.now()),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 4,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Добавить', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildSalaryCard(double total, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Зарплата за ${_monthName(_currentMonth.month).toLowerCase()}',
            style: TextStyle(
              fontSize: 14, 
              color: cs.onPrimary.withOpacity(0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${total.toStringAsFixed(0)} ₽',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: cs.onPrimary,
              letterSpacing: -1.0,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerCard(Partner p, double sum, int count, double hours, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  p.name,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${sum.toStringAsFixed(0)} ₽',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count смен · ${hours.toStringAsFixed(0)} ч.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outline.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _changeMonth(-1),
                icon: Icon(Icons.chevron_left, color: cs.onSurface),
              ),
              Expanded(
                child: Text(
                  '${_monthName(month)} $year',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _changeMonth(1),
                icon: Icon(Icons.chevron_right, color: cs.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: weekdays
                .map((w) => Expanded(
                      child: Center(
                        child: Text(
                          w,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurfaceVariant,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ((startWeekday - 1) + daysInMonth + 6) ~/ 7 * 7,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 0.95,
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

              return GestureDetector(
                onTap: () => _openAddForDay(day),
                child: Container(
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: isToday 
                        ? cs.primary 
                        : (shifts.isNotEmpty ? cs.primaryContainer.withOpacity(0.3) : Colors.transparent),
                    borderRadius: BorderRadius.circular(12),
                    border: isToday ? null : Border.all(color: cs.outline.withOpacity(0.2)),
                    boxShadow: isToday ? [
                      BoxShadow(
                        color: cs.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ] : null,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayIndex',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                          color: isToday ? cs.onPrimary : cs.onSurface,
                        ),
                      ),
                      if (shifts.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: shifts.take(3).map((s) {
                            final t = _types.firstWhere(
                              (x) => x.id == s.type,
                              orElse: () => ShiftType(
                                  id: s.type,
                                  label: '',
                                  hours: 0,
                                  color: '#9E9E9E'),
                            );
                            return Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: _parseColor(t.color),
                                shape: BoxShape.circle,
                              ),
                            );
                          }).toList(),
                        ),
                        if (dayTotal > 0)
                          Text(
                            dayTotal >= 1000
                                ? '${(dayTotal / 1000).toStringAsFixed(1)}к'
                                : dayTotal.toStringAsFixed(0),
                            style: TextStyle(
                              fontSize: 9,
                              color: isToday
                                  ? cs.onPrimary.withOpacity(0.9)
                                  : cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              );
            },
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