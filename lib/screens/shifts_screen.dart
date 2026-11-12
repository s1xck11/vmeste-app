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

  static const List<Color> _partnerPalette = [
    Color(0xFF5B8DEF),
    Color(0xFFEC407A),
    Color(0xFF26A69A),
    Color(0xFFFFA726),
    Color(0xFF7E57C2),
    Color(0xFF66BB6A),
  ];

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

  Color _parseColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return const Color(0xFF9E9E9E);
    }
  }

  Color _typeColor(String typeId) {
    final t = _types.firstWhere(
      (x) => x.id == typeId,
      orElse: () => ShiftType(id: typeId, label: '', hours: 0, color: '#9E9E9E'),
    );
    return _parseColor(t.color);
  }

  Color _partnerColor(int index, ColorScheme cs) {
    if (index < 0) return cs.onSurfaceVariant;
    return _partnerPalette[index % _partnerPalette.length];
  }

  int _partnerIndex(String id) => _partners.indexWhere((p) => p.id == id);

  double _calcSalary(Shift s) {
    if (s.importedFrom == 'courier-helper') {
      return (s.income is num) ? (s.income as num).toDouble() : 0.0;
    }
    if (s.components.isNotEmpty) {
      double sum = 0;
      for (final c in s.components) {
        if (c.mode == 'piecework') {
          sum += c.amount;
        } else {
          sum += c.hours * c.rate;
        }
      }
      return sum;
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
          final now = DateTime.now().millisecondsSinceEpoch;
          widget.storage.addTombstone('shifts', id.toString(), now, widget.storage.myPartnerId ?? 'unknown');
          final list = List<Shift>.from(_shifts)..removeWhere((e) => e.id == id);
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
                children: [
                  _buildSalaryCard(total, cs),
                  const SizedBox(height: 16),
                  if (partner1 != null || partner2 != null)
                    _buildPartnersSection(partner1, partner2, cs),
                  const SizedBox(height: 24),
                  _buildCalendar(cs),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnersSection(Partner? p1, Partner? p2, ColorScheme cs) {
    return Row(
      children: [
        if (p1 != null)
          Expanded(
            child: _buildPartnerCard(
              p1,
              _partnerTotal(p1.id),
              _partnerShiftCount(p1.id),
              _partnerHours(p1.id),
              _partnerColor(0, cs),
              cs,
            ),
          ),
        if (p1 != null && p2 != null) const SizedBox(width: 12),
        if (p2 != null)
          Expanded(
            child: _buildPartnerCard(
              p2,
              _partnerTotal(p2.id),
              _partnerShiftCount(p2.id),
              _partnerHours(p2.id),
              _partnerColor(1, cs),
              cs,
            ),
          ),
      ],
    );
  }

  Widget _buildSalaryCard(double total, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.onPrimary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.work_outline, color: cs.onPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Зарплата за ${_monthName(_currentMonth.month).toLowerCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onPrimary.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${total.toStringAsFixed(0)} ₽',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: cs.onPrimary,
              letterSpacing: -1.5,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerCard(Partner p, double sum, int count, double hours, Color accent, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.surfaceVariant, cs.surfaceVariant.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.45), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person_outline, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  p.name,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.onSurface, height: 1.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${sum.toStringAsFixed(0)} ₽',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: cs.onSurface, letterSpacing: -0.5, height: 1.1),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _partnerStat('$count смен', Icons.event, cs),
              const SizedBox(width: 12),
              _partnerStat('${hours.toStringAsFixed(0)} ч.', Icons.schedule, cs),
            ],
          ),
        ],
      ),
    );
  }

  Widget _partnerStat(String text, IconData icon, ColorScheme cs) {
    return Row(
      children: [
        Icon(icon, size: 12, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500, height: 1.2)),
      ],
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cs.outline.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(color: cs.surfaceVariant, borderRadius: BorderRadius.circular(10)),
                child: IconButton(onPressed: () => _changeMonth(-1), icon: Icon(Icons.chevron_left, color: cs.onSurface)),
              ),
              Expanded(
                child: Text(
                  '${_monthName(month)} $year',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: cs.onSurface, height: 1.2),
                ),
              ),
              Container(
                decoration: BoxDecoration(color: cs.surfaceVariant, borderRadius: BorderRadius.circular(10)),
                child: IconButton(onPressed: () => _changeMonth(1), icon: Icon(Icons.chevron_right, color: cs.onSurface)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: weekdays
                .map((w) => Expanded(
                      child: Center(
                        child: Text(w, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ((startWeekday - 1) + daysInMonth + 6) ~/ 7 * 7,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.8,
            ),
            itemBuilder: (ctx, i) {
              final dayIndex = i - (startWeekday - 1) + 1;
              if (dayIndex < 1 || dayIndex > daysInMonth) return const SizedBox.shrink();
              final day = DateTime(year, month, dayIndex);
              final shifts = _shiftsForDay(day);
              final isToday = day.year == today.year && day.month == today.month && day.day == today.day;

              double dayTotal = 0;
              for (final s in shifts) {
                dayTotal += _calcSalary(s);
              }

              final typeColor = shifts.isNotEmpty ? _typeColor(shifts.first.type) : null;

              return GestureDetector(
                onTap: () => _openAddForDay(day),
                child: Container(
                  decoration: BoxDecoration(
                    color: isToday
                        ? cs.primary
                        : (typeColor != null ? typeColor.withOpacity(0.18) : cs.surfaceVariant),
                    borderRadius: BorderRadius.circular(14),
                    border: isToday
                        ? Border.all(color: cs.primary, width: 2)
                        : Border.all(color: typeColor != null ? typeColor.withOpacity(0.5) : cs.outline.withOpacity(0.3)),
                    boxShadow: isToday
                        ? [BoxShadow(color: cs.primary.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 4))]
                        : null,
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$dayIndex',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                                color: isToday ? cs.onPrimary : cs.onSurface,
                                height: 1.1,
                              ),
                            ),
                            if (shifts.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: shifts.take(3).map((s) {
                                  return Container(
                                    width: 12,
                                    height: 4,
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    decoration: BoxDecoration(color: _typeColor(s.type), borderRadius: BorderRadius.circular(2)),
                                  );
                                }).toList(),
                              ),
                              if (dayTotal > 0)
                                Text(
                                  dayTotal >= 1000 ? '${(dayTotal / 1000).toStringAsFixed(1)}к' : dayTotal.toStringAsFixed(0),
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: isToday ? cs.onPrimary.withOpacity(0.9) : cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                    height: 1.0,
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                      if (shifts.isNotEmpty)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: shifts.take(2).map((s) {
                              final pi = _partnerIndex(s.partner);
                              return Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(left: 2),
                                decoration: BoxDecoration(
                                  color: _partnerColor(pi, cs),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 0.6),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Легенда: кто есть кто
          if (_partners.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Кто работает', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant, letterSpacing: 0.4)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: List.generate(_partners.length, (i) {
                final p = _partners[i];
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(color: _partnerColor(i, cs), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(p.name, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                  ],
                );
              }),
            ),
            const SizedBox(height: 12),
          ],
          // Легенда: типы смен
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Тип смены', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant, letterSpacing: 0.4)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: _types.map((t) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: _parseColor(t.color), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(t.label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}