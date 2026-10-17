import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'debug_log_service.dart';

class TuyaDevice {
  final String id;
  final String name;
  final bool online;
  final bool isOn;
  final int? brightness; // 10-1000
  final String? colorMode; // 'white' | 'colour'

  TuyaDevice({
    required this.id,
    required this.name,
    required this.online,
    required this.isOn,
    this.brightness,
    this.colorMode,
  });

  TuyaDevice copyWith({
    String? name,
    bool? online,
    bool? isOn,
    int? brightness,
    String? colorMode,
  }) {
    return TuyaDevice(
      id: id,
      name: name ?? this.name,
      online: online ?? this.online,
      isOn: isOn ?? this.isOn,
      brightness: brightness ?? this.brightness,
      colorMode: colorMode ?? this.colorMode,
    );
  }
}

/// Сервис для управления устройствами Tuya / Camelion.
/// 
/// Использует Cloud API с подписью HMAC-SHA256.
/// Документация: https://developer.tuya.com/en/docs/cloud
class TuyaService {
  static const String _boxName = 'vmeste_hub_data';
  static const String _keyAccessId = 'tuya_access_id';
  static const String _keyAccessSecret = 'tuya_access_secret';
  static const String _keyRegion = 'tuya_region';

  final _log = DebugLogService();
  late Box _box;

  String _token = '';
  DateTime _tokenExpire = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox(_boxName);
    } else {
      _box = Hive.box(_boxName);
    }
  }

  // ============ НАСТРОЙКИ ============

  String get accessId => _box.get(_keyAccessId) as String? ?? '';
  String get accessSecret => _box.get(_keyAccessSecret) as String? ?? '';
  String get region => _box.get(_keyRegion) as String? ?? 'eu';

  bool get isConfigured => accessId.isNotEmpty && accessSecret.isNotEmpty;

  Future<void> setCredentials({
    required String accessId,
    required String accessSecret,
    required String region,
  }) async {
    await _box.put(_keyAccessId, accessId);
    await _box.put(_keyAccessSecret, accessSecret);
    await _box.put(_keyRegion, region);
    _token = '';
    _tokenExpire = DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> clearCredentials() async {
    await _box.delete(_keyAccessId);
    await _box.delete(_keyAccessSecret);
    await _box.delete(_keyRegion);
    _token = '';
    _tokenExpire = DateTime.fromMillisecondsSinceEpoch(0);
  }

  String get _baseUrl {
    switch (region) {
      case 'us':
        return 'https://openapi.tuyaus.com';
      case 'cn':
        return 'https://openapi.tuyacn.com';
      case 'in':
        return 'https://openapi.tuyain.com';
      case 'eu':
      default:
        return 'https://openapi.tuyaeu.com';
    }
  }

  // ============ ТОКЕН ============

  Future<String?> _getToken() async {
    if (_token.isNotEmpty && DateTime.now().isBefore(_tokenExpire)) {
      return _token;
    }
    if (!isConfigured) return null;

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final path = '/v1.0/token?grant_type=1';
      final contentHash = _sha256('');
      final stringToSign = 'GET\n$contentHash\n\n$path';
      final signStr = '$accessId$timestamp$stringToSign';
      final sign = _hmacSha256(signStr, accessSecret).toUpperCase();

      final resp = await http.get(
        Uri.parse('$_baseUrl$path'),
        headers: {
          't': timestamp,
          'sign_method': 'HMAC-SHA256',
          'client_id': accessId,
          'sign': sign,
        },
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        _token = data['result']['access_token'] as String;
        final expireSec = (data['result']['expire_time'] as num).toInt();
        _tokenExpire = DateTime.now().add(Duration(seconds: expireSec - 60));
        _log.info('Tuya', 'токен получен, истекает через $expireSec сек');
        return _token;
      } else {
        _log.warn('Tuya', 'ошибка токена: ${data['msg']} (${data['code']})');
        return null;
      }
    } catch (e, st) {
      _log.error('Tuya', 'getToken FAILED', e, st);
      return null;
    }
  }

  // ============ УСТРОЙСТВА ============

  Future<List<TuyaDevice>> getDevices() async {
    final token = await _getToken();
    if (token == null) return [];

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      const path = '/v1.0/users/me/devices';
      final contentHash = _sha256('');
      final stringToSign = 'GET\n$contentHash\n\n$path';
      final signStr = '$accessId$token$timestamp$stringToSign';
      final sign = _hmacSha256(signStr, accessSecret).toUpperCase();

      final resp = await http.get(
        Uri.parse('$_baseUrl$path'),
        headers: {
          't': timestamp,
          'sign_method': 'HMAC-SHA256',
          'client_id': accessId,
          'access_token': token,
          'sign': sign,
        },
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        final raw = (data['result'] as List?) ?? [];
        return raw.map((d) {
          final m = Map<String, dynamic>.from(d as Map);
          return TuyaDevice(
            id: m['id'] as String,
            name: m['name'] as String? ?? 'Устройство',
            online: m['online'] as bool? ?? false,
            isOn: false,
          );
        }).toList();
      }
      return [];
    } catch (e, st) {
      _log.error('Tuya', 'getDevices FAILED', e, st);
      return [];
    }
  }

  Future<bool> sendCommand(String deviceId, List<Map<String, dynamic>> commands) async {
    final token = await _getToken();
    if (token == null) return false;

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final path = '/v1.0/devices/$deviceId/commands';
      final body = jsonEncode({'commands': commands});
      final contentHash = _sha256(body);
      final stringToSign = 'POST\n$contentHash\n\n$path';
      final signStr = '$accessId$token$timestamp$stringToSign';
      final sign = _hmacSha256(signStr, accessSecret).toUpperCase();

      final resp = await http.post(
        Uri.parse('$_baseUrl$path'),
        headers: {
          't': timestamp,
          'sign_method': 'HMAC-SHA256',
          'client_id': accessId,
          'access_token': token,
          'sign': sign,
          'Content-Type': 'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['success'] == true;
    } catch (e, st) {
      _log.error('Tuya', 'sendCommand FAILED', e, st);
      return false;
    }
  }

  // ============ ХЕЛПЕРЫ ============

  String _sha256(String s) => sha256.convert(utf8.encode(s)).toString();
  String _hmacSha256(String s, String key) {
    final hmac = Hmac(sha256, utf8.encode(key));
    return hmac.convert(utf8.encode(s)).toString();
  }
}