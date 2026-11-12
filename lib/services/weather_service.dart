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

  static const _ttlMs = 30 * 60 * 1000;
  static const _timeout = Duration(seconds: 25);
  static const _ua = 'VmesteApp/1.0 (github.com/s1xck11/vmeste-app)';

  /// Текст последней ошибки — для диагностики.
  String lastError = '';
  String lastStage = '';

  bool get _cacheFresh =>
      DateTime.now().millisecondsSinceEpoch - storage.cachedWeatherTs < _ttlMs &&
      storage.cachedWeatherTemp != '--°';

  Future<bool> refresh({bool force = false}) async {
    lastError = '';
    lastStage = '';

    if (!force && _cacheFresh) {
      _log.info('Weather', 'кэш свежий: ${storage.cachedWeatherTemp} ${storage.cachedWeatherCond}');
      return true;
    }

    double? lat;
    double? lon;
    String cityName = '';

    // ---------- 1. КООРДИНАТЫ ----------
    if (storage.weatherAutoGeo) {
      lastStage = 'geo';
      final pos = await _currentPosition();
      if (pos == null) {
        _fail('geo', lastError.isEmpty ? 'Не удалось получить координаты' : lastError);
        return false;
      }
      lat = pos.latitude;
      lon = pos.longitude;
      cityName = storage.weatherCity.trim();
      _log.info('Weather', 'гео ok: $lat, $lon');
    } else {
      final city = storage.weatherCity.trim();
      if (city.isEmpty) {
        _fail('city', 'Город не задан. Введи город или включи автоопределение.');
        return false;
      }
      lastStage = 'geocode';
      final geo = await _geocode(city);
      if (geo == null) {
        _fail('geocode', 'Не удалось найти город "$city". ${lastError}');
        return false;
      }
      lat = geo.$1;
      lon = geo.$2;
      cityName = geo.$3;
      _log.info('Weather', 'геокод ok: $cityName ($lat, $lon)');
    }

    // ---------- 2. ПОГОДА ----------
    lastStage = 'forecast';
    final wx = await _forecast(lat, lon);
    if (wx == null) {
      _fail('forecast', 'Не удалось получить погоду. ${lastError}');
      return false;
    }

    storage.cacheWeather(
      temp: '${wx.$1.round()}°',
      cond: wx.$2,
      city: cityName,
    );
    _log.info('Weather', 'готово: ${wx.$1.round()}° ${wx.$2} ($cityName)');
    lastError = '';
    lastStage = '';
    return true;
  }

  void _fail(String stage, String message) {
    lastStage = stage;
    lastError = message;
    _log.error('Weather', '[$stage] $message');
  }

  // ================= HTTP С ПОВТОРОМ =================

  Future<http.Response?> _get(Uri uri, {String tag = ''}) async {
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        _log.info('Weather', 'GET $tag (попытка $attempt): ${uri.toString()}');
        final resp = await http.get(uri, headers: {
          'User-Agent': _ua,
          'Accept': 'application/json',
        }).timeout(_timeout);
        _log.info('Weather', '$tag → HTTP ${resp.statusCode}, ${resp.bodyBytes.length} байт');
        if (resp.statusCode == 200) return resp;
        final body = resp.body.length > 200 ? resp.body.substring(0, 200) : resp.body;
        lastError = '$tag HTTP ${resp.statusCode}: $body';
        _log.warn('Weather', lastError);
      } catch (e) {
        lastError = '$tag сеть: $e';
        _log.warn('Weather', lastError);
      }
      if (attempt == 1) await Future.delayed(const Duration(seconds: 2));
    }
    return null;
  }

  // ================= ГЕОЛОКАЦИЯ =================

  Future<Position?> _currentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        lastError = 'Геолокация (GPS) выключена в настройках телефона.';
        _log.warn('Weather', lastError);
        return null;
      }

      var perm = await Geolocator.checkPermission();
      _log.info('Weather', 'разрешение геолокации: $perm');
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        _log.info('Weather', 'после запроса: $perm');
      }
      if (perm == LocationPermission.deniedForever) {
        lastError = 'Разрешение геолокации запрещено навсегда. Открой Настройки → Приложения → Вместе → Разрешения → Местоположение.';
        _log.warn('Weather', lastError);
        return null;
      }
      if (perm == LocationPermission.denied) {
        lastError = 'Разрешение на геолокацию не выдано.';
        _log.warn('Weather', lastError);
        return null;
      }

      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 20),
        );
      } catch (e) {
        _log.warn('Weather', 'getCurrentPosition не сработал ($e), пробую последнюю известную');
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return last;
        lastError = 'GPS не отдал координаты: $e';
        return null;
      }
    } catch (e) {
      lastError = 'Ошибка геолокации: $e';
      _log.error('Weather', lastError);
      return null;
    }
  }

  // ================= ГЕОКОДИРОВАНИЕ =================

  Future<(double, double, String)?> _geocode(String name) async {
    // 1) Open-Meteo
    try {
      final uri = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(name)}&count=1&language=ru&format=json',
      );
      final resp = await _get(uri, tag: 'geocode/open-meteo');
      if (resp != null) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final r = Map<String, dynamic>.from(results.first as Map);
          final lat = (r['latitude'] as num?)?.toDouble();
          final lon = (r['longitude'] as num?)?.toDouble();
          final city = (r['name'] as String?) ?? name;
          if (lat != null && lon != null) return (lat, lon, city);
        }
        lastError = 'Open-Meteo не нашёл "$name"';
        _log.warn('Weather', lastError);
      }
    } catch (e) {
      _log.warn('Weather', 'geocode/open-meteo parse: $e');
    }

    // 2) Nominatim (OpenStreetMap)
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(name)}&format=jsonv2&limit=1&accept-language=ru',
      );
      final resp = await _get(uri, tag: 'geocode/nominatim');
      if (resp != null) {
        final list = jsonDecode(resp.body) as List;
        if (list.isNotEmpty) {
          final r = Map<String, dynamic>.from(list.first as Map);
          final lat = double.tryParse('${r['lat']}');
          final lon = double.tryParse('${r['lon']}');
          final display = (r['name'] as String?) ??
              ((r['display_name'] as String?)?.split(',').first) ??
              name;
          if (lat != null && lon != null) return (lat, lon, display);
        }
        lastError = 'Nominatim не нашёл "$name"';
        _log.warn('Weather', lastError);
      }
    } catch (e) {
      _log.warn('Weather', 'geocode/nominatim parse: $e');
    }

    return null;
  }

  // ================= ПОГОДА =================

  Future<(double, String)?> _forecast(double lat, double lon) async {
    final la = lat.toStringAsFixed(4);
    final lo = lon.toStringAsFixed(4);

    // 1) Open-Meteo
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$la&longitude=$lo&current=temperature_2m,weather_code&timezone=auto',
      );
      final resp = await _get(uri, tag: 'forecast/open-meteo');
      if (resp != null) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final cur = data['current'] as Map?;
        if (cur != null) {
          final temp = (cur['temperature_2m'] as num?)?.toDouble();
          final code = (cur['weather_code'] as num?)?.toInt() ?? -1;
          if (temp != null) return (temp, _conditionRu(code));
        }
        lastError = 'Open-Meteo вернул ответ без current';
        _log.warn('Weather', lastError);
      }
    } catch (e) {
      _log.warn('Weather', 'forecast/open-meteo parse: $e');
    }

    // 2) MET Norway
    try {
      final uri = Uri.parse(
        'https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=$la&lon=$lo',
      );
      final resp = await _get(uri, tag: 'forecast/met-no');
      if (resp != null) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final props = data['properties'] as Map?;
        final series = props?['timeseries'] as List?;
        if (series != null && series.isNotEmpty) {
          final first = Map<String, dynamic>.from(series.first as Map);
          final d = Map<String, dynamic>.from(first['data'] as Map);
          final instant = Map<String, dynamic>.from(d['instant'] as Map);
          final details = Map<String, dynamic>.from(instant['details'] as Map);
          final temp = (details['air_temperature'] as num?)?.toDouble();

          String symbol = '';
          for (final key in ['next_1_hours', 'next_6_hours', 'next_12_hours']) {
            final block = d[key] as Map?;
            final summary = block?['summary'] as Map?;
            final s = summary?['symbol_code'] as String?;
            if (s != null && s.isNotEmpty) {
              symbol = s;
              break;
            }
          }
          if (temp != null) return (temp, _symbolRu(symbol));
        }
        lastError = 'MET Norway вернул ответ без timeseries';
        _log.warn('Weather', lastError);
      }
    } catch (e) {
      _log.warn('Weather', 'forecast/met-no parse: $e');
    }

    return null;
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

  String _symbolRu(String symbol) {
    final s = symbol.toLowerCase();
    if (s.contains('thunder')) return 'Гроза';
    if (s.contains('heavysnow')) return 'Снегопад';
    if (s.contains('snow')) return 'Снег';
    if (s.contains('sleet')) return 'Мокрый снег';
    if (s.contains('heavyrain')) return 'Ливень';
    if (s.contains('rain')) return 'Дождь';
    if (s.contains('fog')) return 'Туман';
    if (s.contains('cloudy')) return 'Пасмурно';
    if (s.contains('partlycloudy')) return 'Переменная облачность';
    if (s.contains('fair')) return 'Малооблачно';
    if (s.contains('clearsky')) return 'Ясно';
    return '';
  }
}