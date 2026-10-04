// lib/services/courier_import_service.dart

import 'dart:convert';
import '../models/shift.dart';
import 'debug_log_service.dart';

class CourierShiftPreview {
  final String date;
  final String startTime;
  final String endTime;
  final double hours;
  final String type;
  final double income;
  final String location;
  bool selected;

  CourierShiftPreview({
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.hours,
    required this.type,
    required this.income,
    required this.location,
    this.selected = true,
  });
}

class CourierImportService {
  final _log = DebugLogService();

  /// Парсит JSON от courier-helper.
  /// Формат: { "from": "courier-helper", "shifts": [ {d, s, e, i, sv}, ... ] }
  List<CourierShiftPreview>? parseJson(String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['from'] != 'courier-helper') {
        _log.warn('Courier', 'неверный формат: нет поля from=courier-helper');
        return null;
      }
      final shifts = data['shifts'];
      if (shifts is! List) {
        _log.warn('Courier', 'нет массива shifts');
        return null;
      }
      final result = <CourierShiftPreview>[];
      for (final s in shifts) {
        if (s is! Map) continue;
        final d = s['d']?.toString();
        final st = s['s']?.toString();
        final et = s['e']?.toString();
        if (d == null || st == null || et == null) continue;
        final hours = _calcHours(st, et);
        if (hours <= 0) continue;
        final income = double.tryParse(s['i']?.toString() ?? '0') ?? 0;
        final location = s['sv']?.toString() ?? '';
        final type = _guessType(st);
        result.add(CourierShiftPreview(
          date: d,
          startTime: st,
          endTime: et,
          hours: hours,
          type: type,
          income: income,
          location: location,
        ));
      }
      _log.info('Courier', 'распарсено смен: ${result.length}');
      return result;
    } catch (e, st) {
      _log.error('Courier', 'parseJson FAILED', e, st);
      return null;
    }
  }

  double _calcHours(String start, String end) {
    try {
      final s = start.split(':').map(int.parse).toList();
      final e = end.split(':').map(int.parse).toList();
      int diff = (e[0] * 60 + e[1]) - (s[0] * 60 + s[1]);
      if (diff < 0) diff += 1440;
      return (diff / 60 * 100).round() / 100;
    } catch (_) {
      return 0;
    }
  }

  String _guessType(String start) {
    try {
      final h = int.parse(start.split(':')[0]);
      if (h >= 5 && h < 11) return 'morning';
      if (h >= 11 && h < 17) return 'day';
      return 'night';
    } catch (_) {
      return 'day';
    }
  }

  /// Преобразует preview в Shift.
  Shift toShift(CourierShiftPreview p, String partnerId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return Shift(
      id: now + p.hashCode,
      date: p.date,
      partner: partnerId,
      type: p.type,
      hours: p.hours,
      startTime: p.startTime,
      endTime: p.endTime,
      notes: '',
      income: p.income,
      location: p.location,
      importedFrom: 'courier-helper',
      pieceworkAmount: null,
      notification: 60,
      createdAt: now,
      updatedAt: now,
    );
  }
}