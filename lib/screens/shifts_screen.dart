import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import '../models/shift.dart';
import '../models/shift_type.dart';
import '../models/partner.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../widgets/add_shift_modal.dart';

/// Экран смен.
/// 
/// Календарь на месяц + статистика за месяц + расчёт зарплаты.
class ShiftsScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;

  const ShiftsScreen({
    super.key,
    required this.storage,
    required this.sync,
  });

  @override
  State<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends State<ShiftsScreen> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
    widget.sync.onDataChanged = _refresh;
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  // ============ ФИЛЬТРАЦИЯ ============

  List<Shift> get _allShifts => widget.storage.shifts
      .where((s) => s.deletedAt == null)
      .toList();

  List<Shift> get _monthShifts {
    final prefix =
        '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}';
    return _allShifts
        .where((s) => s.date.startsWith(prefix))
        .toList();
  }

  List<Shift> _shiftsForDate(String dateKey) {
    return _allShifts.where((s) => s.date == dateKey).toList();
  }

  // ============ РАСЧЁТЫ ============

  double _shiftSalary(Shift s) {
    final partner = widget.storage.getPartner(s.partner);
    switch (partner.payType) {
      case 'fixed':
        return partner.rate;
      case 'piecework':
        return s.pieceworkAmount ?? 0;
      case 'hourly':
      default:
        return s.hours * partner.rate;
    }
  }

  double get _totalSalary =>
      _monthShifts.fold(0.0, (sum, s) => sum + _shiftSalary(s));

  double _partnerSalary(String partnerId) {
    return _monthShifts
        .where((s) => s.partner == partnerId)
        .fold(0.0, (sum, s) => sum + _shiftSalary(s));
  }

  int _partnerShiftCount(String partnerId) =>
      _monthShifts.where((s) => s.partner == partnerId).length;

  // ============ НАВИГАЦИЯ МЕСЯЦЕВ ============

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  // ============ ДОБАВЛЕНИЕ ============

  Future<void> _openAddModal(String date) async {
    final result = await showModalBottomSheet<Shift>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddShiftModal(
        date: date,
        shiftTypes: widget.storage.shiftTypes,
        partners: widget.storage.partners,
        currentPartnerId: widget.storage.myPartnerId ?? 'partner1',
        currentUserIdGetter: () => widget.storage.currentUserId,
      ),
    );

    if (result != null) {
      final list = widget.storage.shifts;
      list.add(result);
      widget.storage.shifts = list;
      widget.sync.schedulePush();
      _refresh();
    }
  }

  Future<void> _editShift(Shift s) async {
    final result = await showModalBottomSheet<Shift>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddShiftModal(
        existing: s,
        date: s.date,
        shiftTypes: widget.storage.shiftTypes,
        partners: widget.storage.partners,
        currentPartnerId: widget.storage.myPartnerId ?? 'partner1',
        currentUserIdGetter: () => widget.storage.currentUserId,
      ),
    );

    if (result != null) {
      final list = widget.storage.shifts;
      final idx = list.indexWhere((x) => x.id == result.id);
      if (idx >= 0) list[idx] = result;
      widget.storage.shifts = list;
      widget.sync.schedulePush();
      _refresh();
    }
  }

  void _deleteShift(Shift s) {
    final list = widget.storage.shifts;
    list.removeWhere((x) => x.id == s.id);
    final deleted = widget.storage.deletedShiftIds;
    deleted.add(s.id);
    widget.storage.deletedShiftIds = deleted;
    widget.storage.shifts = list;
    widget.sync.schedulePush();
    _refresh();
  }

  /// Открывает список смен на день (если их несколько).
  Future<void> _showDayShifts(String dateKey) async {
    final shifts = _shiftsForDate(dateKey);
    if (shifts.isEmpty) {
      await _openAddModal(dateKey);
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Смены на $dateKey',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...shifts.map((s) => _shiftRow(s)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _openAddModal(dateKey);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить смену'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shiftRow(Shift s) {
    final partner = widget.storage.getPartner(s.partner);
    final type = widget.storage.shiftTypes.firstWhere(
      (t) => t.id == s.type,
      orElse: () => widget.storage.shiftTypes.first,
    );
    final salary = _shiftSalary(s);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: _parseColor(type.color), width: 4),
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          _editShift(s);
        },
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${partner.name} · ${type.label}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${s.startTime}–${s.endTime} · ${s.hours}ч',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${salary.toStringAsFixed(0)} ₽',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteShift(s);
              },
              icon: const Icon(Icons.close,
                  size: 18, color: AppColors.textSecondary),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }

  // ============ UI ============

  @override
  Widget build(BuildContext context) {
    final partners = widget.storage.partners;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Смены'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Icon(
                widget.sync.status == 'online'
                    ? Icons.cloud_done
                    : Icons.cloud_off,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Статистика
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.cardLight,
            child: Column(
              children: [
                // Общая зарплата
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, AppColors.info],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Зарплата за месяц',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_totalSalary.toStringAsFixed(0)} ₽',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // По партнёрам
                Row(
                  children: partners.map((p) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: p.id == partners.last.id ? 0 : 8,
                        ),
                        child: _statCard(
                          p.name,
                          _partnerSalary(p.id),
                          _partnerShiftCount(p.id),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Календарь
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Навигация по месяцам
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _prevMonth,
                          icon: const Icon(Icons.arrow_back_ios, size: 18),
                        ),
                        Expanded(
                          child: Text(
                            _monthName(_currentMonth),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _nextMonth,
                          icon: const Icon(Icons.arrow_forward_ios, size: 18),
                        ),
                      ],
                    ),
                  ),

                  // Дни недели
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
                          .map((d) => Expanded(
                                child: Center(
                                  child: Text(
                                    d.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Сетка дней
                  _buildCalendar(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String name, double salary, int count) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${salary.toStringAsFixed(0)} ₽',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$count смен',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final year = _currentMonth.year;
    final month = _currentMonth.month;

    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final startWeekday = firstDay.weekday; // 1=Mon..7=Sun
    final daysInMonth = lastDay.day;

    // Строим сетку: 6 недель по 7
    final cells = <Widget>[];
    var dayCounter = 1;
    final totalCells = ((startWeekday - 1) + daysInMonth + 6) ~/ 7 * 7;

    for (var i = 0; i < totalCells; i++) {
      if (i < startWeekday - 1 || dayCounter > daysInMonth) {
        cells.add(const SizedBox());
      } else {
        final day = dayCounter;
        final dateKey =
            '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
        cells.add(_buildDayCell(day, dateKey));
        dayCounter++;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 7,
        childAspectRatio: 0.9,
        children: cells,
      ),
    );
  }

  Widget _buildDayCell(int day, String dateKey) {
    final shifts = _shiftsForDate(dateKey);
    final today = _todayKey();
    final isToday = dateKey == today;

    // Сумма за день
    double dayTotal = 0;
    for (final s in shifts) {
      dayTotal += _shiftSalary(s);
    }

    return GestureDetector(
      onTap: () => _showDayShifts(dateKey),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: shifts.isEmpty ? null : AppColors.accentLight,
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(color: AppColors.accent, width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (shifts.isNotEmpty) ...[
              const SizedBox(height: 2),
              // Точки цветов типов
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: shifts.take(4).map((s) {
                  final type = widget.storage.shiftTypes.firstWhere(
                    (t) => t.id == s.type,
                    orElse: () => widget.storage.shiftTypes.first,
                  );
                  return Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: _parseColor(type.color),
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              ),
              if (dayTotal > 0)
                Text(
                  '${(dayTotal / 1000).toStringAsFixed(1)}к',
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _monthName(DateTime date) {
    const names = [
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];
    return '${names[date.month - 1]} ${date.year}';
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
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