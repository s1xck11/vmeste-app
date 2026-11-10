// lib/services/weather_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'storage_service.dart';
import 'debug_log_service.dart';

class WeatherService {
  final StorageService storage;
  final _log = DebugLogService();

  WeatherService(this.storage);

  static const _ttlMs = 30 * 60 * 1000; // кэш живёт 30 минут

  bool get _cacheFresh =>
      DateTime.now().millisecondsSinceEpoch - storage.cachedWeatherTs < _ttlMs;

  /// Обновляет погоду, если кэш протух. Возвращает true если данные актуальны.
  Future<bool> refresh({bool force = false}) async {
    if (!force && _cacheFresh) return true;
    try {
      double? lat;
      double? lon;
      String cityName;

      if (storage.weatherAutoGeo) {
        final pos = await _currentPosition();
        if (pos == null) return false;
        lat = pos.latitude;
        lon = pos.longitude;
        cityName = await _reverseCity(lat, lon) ?? '';
      } else if (storage.weatherCity.trim().isNotEmpty) {
        final geo = await _geocode(storage.weatherCity.trim());
        if (geo == null) return false;
        lat = geo.$1;
        lon = geo.$2;
        cityName = geo.$3;
      } else {
        return false; // город не задан
      }

      final wx = await _forecast(lat, lon);
      if (wx == null) return false;

      storage.cacheWeather(
        temp: '${wx.$1.round()}°',
        cond: wx.$2,
        city: cityName,
      );
      _log.info('Weather', 'обновлено: ${wx.$1.round()}° ${wx.$2} ($cityName)');
      return true;
    } catch (e, st) {
      _log.error('Weather', 'refresh FAILED', e, st);
      return false;
    }
  }

  Future<Position?> _currentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (e) {
      return null;
    }
  }

  Future<(double, double, String)?> _geocode(String name) async {
    final uri = Uri.parse(
      'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(name)}&count=1&language=ru&format=json',
    );
    final resp = await http.get(uri).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final results = data['results'] as List?;
    if (results == null || results.isEmpty) return null;
    final r = Map<String, dynamic>.from(results.first as Map);
    final lat = (r['latitude'] as num?)?.toDouble();
    final lon = (r['longitude'] as num?)?.toDouble();
    final city = (r['name'] as String?) ?? name;
    if (lat == null || lon == null) return null;
    return (lat, lon, city);
  }

  Future<String?> _reverseCity(double lat, double lon) async {
    // Open-Meteo не даёт reverse-геокодирование; для авто-гео город не показываем
    return null;
  }

  Future<(double, String)?> _forecast(double lat, double lon) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code&timezone=auto',
    );
    final resp = await http.get(uri).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final cur = data['current'] as Map?;
    if (cur == null) return null;
    final temp = (cur['temperature_2m'] as num?)?.toDouble();
    final code = (cur['weather_code'] as num?)?.toInt() ?? -1;
    if (temp == null) return null;
    return (temp, _conditionRu(code));
  }

  String _conditionRu(int code) {
    switch (code) {
      case 0: return 'Ясно';
      case 1: return 'Малооблачно';
      case 2: return 'Переменная облачность';
      case 3: return 'Пасмурно';
      case 45:
      case 48: return 'Туман';
      case 51:
      case 53:
      case 55: return 'Морось';
      case 56:
      case 57: return 'Ледяная морось';
      case 61:
      case 63:
      case 65: return 'Дождь';
      case 66:
      case 67: return 'Ледяной дождь';
      case 71:
      case 73:
      case 75: return 'Снег';
      case 77: return 'Снежная крупа';
      case 80:
      case 81:
      case 82: return 'Ливень';
      case 85:
      case 86: return 'Снегопад';
      case 95: return 'Гроза';
      case 96:
      case 99: return 'Гроза с градом';
      default: return '';
    }
  }
}