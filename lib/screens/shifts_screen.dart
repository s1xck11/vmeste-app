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
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month + delta, 1);
    });
  }

  String _key(int y, int m, int d) =>
      '$y-${m < 10 ? '0$m' : m}-${d < 10 ? '0$d' : d}';

  List<Shift> _shiftsForDay(DateTime day) {
    final key = _key(day.year, day.month, day.day);
    return _shifts.where((s) => s.date == key).toList();
  }

  double _calcSalary(Shift s) {
    if (s.importedFrom == 'courier-helper' && s.income != null) {
      return s.income!.toDouble();
    }
    final partner = _partners.firstWhere(
      (p) => p.id == s.partner,
      orElse: () =>
          Partner(id: s.partner, name: '', rate: 0, payType: 'hourly'),
    );
    if (partner.payType == 'piecework') {
      return (s.pieceworkAmount ?? 0).toDouble();
    }
    if (partner.payType == 'fixed') return partner.rate.toDouble();
    return s.hours * partner.rate;
  }

  double _monthTotal() {
    double sum = 0;
    final prefix =
        '${_currentMonth.year}-${_currentMonth.month < 10 ? '0${_currentMonth.month}' : _currentMonth.month}';
    for (final s in _shifts) {
      if (s.date.startsWith(prefix)) sum += _calcSalary(s);
    }
    return sum;
  }

  double _partnerTotal(String partnerId) {
    double sum = 0;
    final prefix =
        '${_currentMonth.year}-${_currentMonth.month < 10 ? '0${_currentMonth.month}' : _currentMonth.month}';
    for (final s in _shifts) {
      if (!s.date.startsWith(prefix)) continue;
      if (s.partner == partnerId) sum += _calcSalary(s);
    }
    return sum;
  }

  int _partnerShiftCount(String partnerId) {
    final prefix =
        '${_currentMonth.year}-${_currentMonth.month < 10 ? '0${_currentMonth.month}' : _currentMonth.month}';
    return _shifts.where((s) {
      if (!s.date.startsWith(prefix)) return false;
      return s.partner == partnerId;
    }).length;
  }

  String _monthName(int m) {
    const names = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];
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

  /// Публичный — открыть добавление смены на сегодня
  void openAddForToday() {
    _openAddForDay(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final partner1 = _partners.isNotEmpty ? _partners[0] : null;
    final partner2 = _partners.length > 1 ? _partners[1] : null;
    final total = _monthTotal();

    return Scaffold