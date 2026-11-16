// tv/lib/services/weather_service.dart
//
// Погода через Open-Meteo (без ключей): текущая + мин/макс на день.
// Город хранится в Hive, кэш переживает офлайн, обновление раз в 30 минут.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

class WeatherService extends ChangeNotifier {
  WeatherService._();
  static final WeatherService instance = WeatherService._();

  String city = 'Москва';
  double lat = 55.7558;
  double lon = 37.6173;

  double? temp;
  double? tmin;
  double? tmax;
  double wind = 0;
  int code = 0;
  DateTime? updated;
  bool loading = false;
  String? error;

  Timer? _timer;

  Future<void> init() async {
    final box = await Hive.openBox('vmeste_tv_prefs');
    city = box.get('weather_city', defaultValue: 'Москва') as String;
    lat = (box.get('weather_lat', defaultValue: 55.7558) as num).toDouble();
    lon = (box.get('weather_lon', defaultValue: 37.6173) as num).toDouble();
    final cached = box.get('weather_cache');
    if (cached is Map) {
      try {
        _parse(Map<String, dynamic>.from(cached));
      } catch (_) {}
    }
    notifyListeners();
    unawaited(fetch());
    _timer = Timer.periodic(const Duration(minutes: 30), (_) => fetch());
  }

  Future<void> fetch() async {
    loading = true;
    notifyListeners();
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,weather_code,wind_speed_10m'
        '&daily=temperature_2m_max,temperature_2m_min'
        '&timezone=auto&forecast_days=1',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) throw Exception('http ${resp.statusCode}');
      final data = Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
      _parse(data);
      final box = Hive.box('vmeste_tv_prefs');
      await box.put('weather_cache', data);
      error = null;
    } catch (_) {
      error = 'Нет данных о погоде';
    }
    loading = false;
    updated = DateTime.now();
    notifyListeners();
  }

  void _parse(Map<String, dynamic> data) {
    final cur = Map<String, dynamic>.from(data['current'] as Map? ?? {});
    temp = (cur['temperature_2m'] as num?)?.toDouble();
    code = (cur['weather_code'] as num?)?.toInt() ?? 0;
    wind = (cur['wind_speed_10m'] as num?)?.toDouble() ?? 0;
    final daily = Map<String, dynamic>.from(data['daily'] as Map? ?? {});
    final maxs = daily['temperature_2m_max'] as List?;
    final mins = daily['temperature_2m_min'] as List?;
    if (maxs != null && maxs.isNotEmpty) {
      tmax = (maxs.first as num?)?.toDouble();
    }
    if (mins != null && mins.isNotEmpty) {
      tmin = (mins.first as num?)?.toDouble();
    }
  }

  Future<List<Map<String, dynamic>>> search(String q) async {
    if (q.trim().isEmpty) return [];
    final uri = Uri.parse(
      'https://geocoding-api.open-meteo.com/v1/search'
      '?name=${Uri.encodeQueryComponent(q.trim())}&count=6&language=ru&format=json',
    );
    final resp = await http.get(uri).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return [];
    final data = Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
    final results = data['results'] as List? ?? [];
    return results
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> setCity(String name, double la, double lo) async {
    city = name;
    lat = la;
    lon = lo;
    final box = Hive.box('vmeste_tv_prefs');
    await box.put('weather_city', name);
    await box.put('weather_lat', la);
    await box.put('weather_lon', lo);
    notifyListeners();
    await fetch();
  }

  IconData get icon {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code <= 2) return Icons.wb_cloudy_rounded;
    if (code == 3) return Icons.cloud_rounded;
    if (code == 45 || code == 48) return Icons.foggy;
    if (code >= 51 && code <= 57) return Icons.grain_rounded;
    if (code >= 61 && code <= 67) return Icons.water_drop_rounded;
    if (code >= 71 && code <= 77) return Icons.ac_unit_rounded;
    if (code >= 80 && code <= 82) return Icons.water_drop_rounded;
    if (code >= 95) return Icons.thunderstorm_rounded;
    return Icons.cloud_rounded;
  }

  String get label {
    if (code == 0) return 'Ясно';
    if (code <= 2) return 'Малооблачно';
    if (code == 3) return 'Пасмурно';
    if (code == 45 || code == 48) return 'Туман';
    if (code >= 51 && code <= 57) return 'Морось';
    if (code >= 61 && code <= 67) return 'Дождь';
    if (code >= 71 && code <= 77) return 'Снег';
    if (code >= 80 && code <= 82) return 'Ливень';
    if (code >= 95) return 'Гроза';
    return 'Облачно';
  }
}
