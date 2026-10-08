// lib/services/update_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'debug_log_service.dart';

class UpdateInfo {
  final String tag;
  final String version;
  final String name;
  final String body;
  final String? apkUrl;
  final int apkSize;

  UpdateInfo({
    required this.tag,
    required this.version,
    required this.name,
    required this.body,
    this.apkUrl,
    this.apkSize = 0,
  });
}

class UpdateService {
  final _log = DebugLogService();

  /// Текущая версия из pubspec (хардкод — синхронизируем с pubspec.yaml)
  static const String currentVersion = '1.1.0';
  static const int currentBuild = 100;

  /// GitHub repo — владелец/имя
  static const String _repo = 's1xck11/vmeste-app';

  /// Проверяет последний релиз. Возвращает UpdateInfo или null, если обновлений нет.
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      _log.info('Update', 'проверка обновлений...');
      final uri = Uri.parse('https://api.github.com/repos/$_repo/releases/latest');
      final resp = await http.get(
        uri,
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 20));

      if (resp.statusCode != 200) {
        _log.warn('Update', 'HTTP ${resp.statusCode}');
        return null;
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final tag = (data['tag_name'] as String?) ?? '';
      final name = (data['name'] as String?) ?? tag;
      final body = (data['body'] as String?) ?? '';

      // Ищем APK в assets — предпочтение arm64-v8a
      final assets = (data['assets'] as List?) ?? [];
      String? apkUrl;
      int apkSize = 0;
      for (final a in assets) {
        final aMap = Map<String, dynamic>.from(a as Map);
        final aName = (aMap['name'] as String?) ?? '';
        if (aName.contains('arm64-v8a') && aName.endsWith('.apk')) {
          apkUrl = aMap['browser_download_url'] as String?;
          apkSize = (aMap['size'] as int?) ?? 0;
          break;
        }
      }
      if (apkUrl == null) {
        for (final a in assets) {
          final aMap = Map<String, dynamic>.from(a as Map);
          final aName = (aMap['name'] as String?) ?? '';
          if (aName.endsWith('.apk')) {
            apkUrl = aMap['browser_download_url'] as String?;
            apkSize = (aMap['size'] as int?) ?? 0;
            break;
          }
        }
      }

      // Парсим версию из тега: "v1.1.123" → [1, 1, 123]
      final ver = _parseVersion(tag);
      final currentVer = _parseVersion('v$currentVersion');

      if (ver == null) {
        _log.warn('Update', 'не удалось распарсить тег: $tag');
        return null;
      }

      final hasNewer = _isNewer(ver, currentVer);

      if (!hasNewer) {
        _log.info('Update', 'обновлений нет (текущая $currentVersion, последняя $tag)');
        return null;
      }

      _log.info('Update', 'найдено обновление: $tag');
      return UpdateInfo(
        tag: tag,
        version: tag,
        name: name,
        body: body,
        apkUrl: apkUrl,
        apkSize: apkSize,
      );
    } catch (e, st) {
      _log.error('Update', 'checkForUpdate FAILED', e, st);
      return null;
    }
  }

  /// Скачивает APK в кэш и открывает системный установщик.
  Future<bool> downloadAndInstall(UpdateInfo info) async {
    if (info.apkUrl == null) {
      _log.warn('Update', 'нет APK в релизе');
      return false;
    }
    try {
      _log.info('Update', 'скачиваю ${info.apkUrl}');
      final resp = await http.get(Uri.parse(info.apkUrl!)).timeout(const Duration(minutes: 3));
      if (resp.statusCode != 200) {
        _log.warn('Update', 'скачивание HTTP ${resp.statusCode}');
        return false;
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/vmeste-${info.tag}.apk');
      await file.writeAsBytes(resp.bodyBytes);
      _log.info('Update', 'сохранено: ${file.path}');

      // Открываем системный установщик
      final uri = Uri.file(file.path);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        _log.warn('Update', 'не удалось открыть установщик');
        return false;
      }
      return true;
    } catch (e, st) {
      _log.error('Update', 'downloadAndInstall FAILED', e, st);
      return false;
    }
  }

  List<int>? _parseVersion(String tag) {
    try {
      final clean = tag.replaceAll(RegExp(r'^[vV]'), '');
      final parts = clean.split('.').map((s) => int.tryParse(s) ?? 0).toList();
      while (parts.length < 3) parts.add(0);
      return parts.take(3).toList();
    } catch (_) {
      return null;
    }
  }

  bool _isNewer(List<int> a, List<int> b) {
    for (int i = 0; i < 3; i++) {
      if (a[i] > b[i]) return true;
      if (a[i] < b[i]) return false;
    }
    return false;
  }
}