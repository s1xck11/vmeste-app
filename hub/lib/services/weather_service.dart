import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'debug_log_service.dart';

class WeatherNow {
  final double temperature;
  final double feelsLike;
  final int weatherCode;
  final double windSpeed;
  final int humidity;
  final DateTime updatedAt;

  WeatherNow({
    required this.temperature,
    required this.feelsLike,
    required this.weatherCode,
    required this.windSpeed,
    required this.humidity,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'feelsLike': feelsLike,
        'weatherCode': weatherCode,
        'windSpeed': windSpeed,
        'humidity': humidity,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory WeatherNow.fromJson(Map<String, dynamic> j) => WeatherNow(
        temperature: (j['temperature'] as num?)?.toDouble() ?? 0,
        feelsLike: (j['feelsLike'] as num?)?.toDouble() ?? 0,
        weatherCode: (j['weatherCode'] as num?)?.toInt() ?? 0,
        windSpeed: (j['windSpeed'] as num?)?.toDouble() ?? 0,
        humidity: (j['humidity'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.tryParse(j['updatedAt'] ?? '') ?? DateTime.now(),
      );

  String get description => describeWmo(weatherCode);
  String get emoji => emojiWmo(weatherCode);

  static String describeWmo(int code) {
    if (code == 0) return 'Ясно';
    if (code <= 3) return 'Малооблачно';
    if (code <= 48) return 'Туман';
    if (code <= 57) return 'Морось';
    if (code <= 67) return 'Дождь';
    if (code <= 77) return 'Снег';
    if (code <= 82) return 'Ливень';
    if (code <= 86) return 'Снегопад';
    if (code <= 99) return 'Гроза';
    return '—';
  }

  static String emojiWmo(int code) {
    if (code == 0) return '☀️';
    if (code <= 2) return '🌤';
    if (code <= 3) return '☁️';
    if (code <= 48) return '🌫';
    if (code <= 57) return '🌦';
    if (code <= 67) return '🌧';
    if (code <= 77) return '🌨';
    if (code <= 82) return '🌧';
    if (code <= 86) return '🌨';
    if (code <= 99) return '⛈';
    return '🌡';
  }
}

class WeatherDay {
  final DateTime date;
  final double tempMax;
  final double tempMin;
  final int weatherCode;

  WeatherDay({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.weatherCode,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'tempMax': tempMax,
        'tempMin': tempMin,
        'weatherCode': weatherCode,
      };

  factory WeatherDay.fromJson(Map<String, dynamic> j) => WeatherDay(
        date: DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
        tempMax: (j['tempMax'] as num?)?.toDouble() ?? 0,
        tempMin: (j['tempMin'] as num?)?.toDouble() ?? 0,
        weatherCode: (j['weatherCode'] as num?)?.toInt() ?? 0,
      );

  String get emoji => WeatherNow.emojiWmo(weatherCode);
  String get weekdayName {
    const names = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return names[date.weekday - 1];
  }

  String get dayLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'Сегодня';
    if (diff == 1) return 'Завтра';
    return weekdayName;
  }
}

class WeatherCache {
  final WeatherNow? now;
  final List<WeatherDay> days;
  final DateTime fetchedAt;
  final String cityName;

  WeatherCache({
    required this.now,
    required this.days,
    required this.fetchedAt,
    required this.cityName,
  });

  Map<String, dynamic> toJson() => {
        'now': now?.toJson(),
        'days': days.map((d) => d.toJson()).toList(),
        'fetchedAt': fetchedAt.toIso8601String(),
        'cityName': cityName,
      };

  factory WeatherCache.fromJson(Map<String, dynamic> j) => WeatherCache(
        now: j['now'] != null ? WeatherNow.fromJson(j['now']) : null,
        days: (j['days'] as List? ?? [])
            .map((d) => WeatherDay.fromJson(Map<String, dynamic>.from(d)))
            .toList(),
        fetchedAt: DateTime.tryParse(j['fetchedAt'] ?? '') ?? DateTime.now(),
        cityName: j['cityName'] as String? ?? '',
      );
}

class WeatherService {
  static const String _boxName = 'vmeste_hub_data';
  static const String _keyCityLat = 'weather_city_lat';
  static const String _keyCityLon = 'weather_city_lon';
  static const String _keyCityName = 'weather_city_name';
  static const String _keyCache = 'weather_cache';
  static const Duration _cacheTtl = Duration(minutes: 30);

  final _log = DebugLogService();
  late Box _box;

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox(_boxName);
    } else {
      _box = Hive.box(_boxName);
    }
  }

  String get cityName => _box.get(_keyCityName) as String? ?? '';
  double? get cityLat => (_box.get(_keyCityLat) as num?)?.toDouble();
  double? get cityLon => (_box.get(_keyCityLon) as num?)?.toDouble();

  bool get hasCity => cityLat != null && cityLon != null && cityName.isNotEmpty;

  Future<void> setCity({required String name, required double lat, required double lon}) async {
    await _box.put(_keyCityName, name);
    await _box.put(_keyCityLat, lat);
    await _box.put(_keyCityLon, lon);
    await _box.delete(_keyCache);
  }

  Future<void> clearCity() async {
    await _box.delete(_keyCityName);
    await _box.delete(_keyCityLat);
    await _box.delete(_keyCityLon);
    await _box.delete(_keyCache);
  }

  WeatherCache? get _cached {
    final raw = _box.get(_keyCache);
    if (raw == null) return null;
    try {
      return WeatherCache.fromJson(Map<String, dynamic>.from(raw as Map));
    } catch (_) {
      return null;
    }
  }

  bool get _cacheFresh {
    final c = _cached;
    if (c == null) return false;
    return DateTime.now().difference(c.fetchedAt) < _cacheTtl;
  }

  WeatherCache? get lastKnown => _cached;

  Future<WeatherCache?> fetch({bool force = false}) async {
    if (!hasCity) return null;
    if (!force && _cacheFresh) return _cached;

    try {
      final lat = cityLat!;
      final lon = cityLon!;

      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat'
        '&longitude=$lon'
        '&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,relative_humidity_2m'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min'
        '&timezone=auto'
        '&forecast_days=7',
      );

      final resp = await http.get(url).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return _cached;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>? ?? {};
      final daily = data['daily'] as Map<String, dynamic>? ?? {};

      final now = WeatherNow(
        temperature: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
        feelsLike: (current['apparent_temperature'] as num?)?.toDouble() ?? 0,
        weatherCode: (current['weather_code'] as num?)?.toInt() ?? 0,
        windSpeed: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
        humidity: (current['relative_humidity_2m'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.now(),
      );

      final dates = (daily['time'] as List?)?.cast<String>() ?? [];
      final codes = (daily['weather_code'] as List?)?.cast<num>() ?? [];
      final tmax = (daily['temperature_2m_max'] as List?)?.cast<num>() ?? [];
      final tmin = (daily['temperature_2m_min'] as List?)?.cast<num>() ?? [];

      final days = <WeatherDay>[];
      for (var i = 0; i < dates.length; i++) {
        if (i >= codes.length || i >= tmax.length || i >= tmin.length) break;
        final d = DateTime.tryParse(dates[i]);
        if (d == null) continue;
        days.add(WeatherDay(
          date: d,
          tempMax: tmax[i].toDouble(),
          tempMin: tmin[i].toDouble(),
          weatherCode: codes[i].toInt(),
        ));
      }

      final cache = WeatherCache(
        now: now,
        days: days,
        fetchedAt: DateTime.now(),
        cityName: cityName,
      );

      await _box.put(_keyCache, cache.toJson());
      return cache;
    } catch (e, st) {
      _log.error('Weather', 'fetch FAILED', e, st);
      return _cached;
    }
  }
}