import 'dart:convert';
import 'package:http/http.dart' as http;
import 'debug_log_service.dart';

class GeoResult {
  final String name;
  final String country;
  final String? admin1;
  final double lat;
  final double lon;

  GeoResult({
    required this.name,
    required this.country,
    this.admin1,
    required this.lat,
    required this.lon,
  });

  String get displayName {
    final parts = <String>[name];
    if (admin1 != null && admin1!.isNotEmpty) parts.add(admin1!);
    parts.add(country);
    return parts.join(', ');
  }
}

/// Поиск города через Open-Meteo Geocoding API (бесплатный, без ключа).
class GeocodingService {
  final _log = DebugLogService();

  Future<List<GeoResult>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];

    try {
      final url = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search'
        '?name=${Uri.encodeComponent(q)}'
        '&count=10'
        '&language=ru'
        '&format=json',
      );

      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return [];

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final results = (data['results'] as List?) ?? [];
      return results.map((r) {
        final m = Map<String, dynamic>.from(r as Map);
        return GeoResult(
          name: m['name'] as String? ?? '',
          country: m['country'] as String? ?? '',
          admin1: m['admin1'] as String?,
          lat: (m['latitude'] as num?)?.toDouble() ?? 0,
          lon: (m['longitude'] as num?)?.toDouble() ?? 0,
        );
      }).toList();
    } catch (e, st) {
      _log.error('Geocoding', 'search FAILED', e, st);
      return [];
    }
  }
}