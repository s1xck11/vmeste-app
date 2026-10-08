// lib/services/update_service.dart

import 'dart:async';
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

  static const String currentVersion = '1.1.0';
  static const int currentBuild = 100;
  static const String _repo = 's1xck11/vmeste-app';

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

      final ver = _parseVersion(tag) ?? [0, 0, 0];
      final currentVer = _parseVersion('v$currentVersion') ?? [0, 0, 0];

      if (_isNewer(ver, currentVer)) {
        _log.info('Update', 'найдено обновление: $tag');
        return UpdateInfo(
          tag: tag,
          version: tag,
          name: name,
          body: body,
          apkUrl: apkUrl,
          apkSize: apkSize,
        );
      }

      _log.info('Update', 'обновлений нет (текущая $currentVersion, последняя $tag)');
      return null;
    } catch (e, st) {
      _log.error('Update', 'checkForUpdate FAILED', e, st);
      return null;
    }
  }

  /// Скачивает APK с прогрессом. [onProgress] вызывается с (получено, всего).
  /// Возвращает File или null.
  Future<File?> downloadApk(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (info.apkUrl == null) {
      _log.warn('Update', 'нет APK в релизе');
      return null;
    }
    HttpClient? client;
    try {
      _log.info('Update', 'скачиваю ${info.apkUrl}');

      // Свой HttpClient с followRedirects — надёжнее на Huawei
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 30);
      client.idleTimeout = const Duration(seconds: 60);
      client.badCertificateCallback = (cert, host, port) => true;

      final request = await client.getUrl(Uri.parse(info.apkUrl!));
      request.followRedirects = true;
      request.headers.set('Accept', '*/*');
      final response = await request.close();

      if (response.statusCode != 200) {
        _log.warn('Update', 'HTTP ${response.statusCode}');
        return null;
      }

      final total = response.contentLength > 0 ? response.contentLength : info.apkSize;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/vmeste-${info.tag}.apk');
      if (await file.exists()) await file.delete();

      final sink = file.openWrite();
      int received = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (onProgress != null) onProgress(received, total);
      }

      await sink.flush();
      await sink.close();

      _log.info('Update', 'сохранено: ${file.path} (${received ~/ 1024} КБ)');
      return file;
    } catch (e, st) {
      _log.error('Update', 'downloadApk FAILED', e, st);
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  /// Открывает системный установщик для скачанного файла.
  Future<bool> installApk(File file) async {
    try {
      final uri = Uri.file(file.path);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        _log.warn('Update', 'не удалось открыть установщик');
        return false;
      }
      return true;
    } catch (e, st) {
      _log.error('Update', 'installApk FAILED', e, st);
      return false;
    }
  }

  List<int>? _parseVersion(String tag) {
    try {
      final clean = tag.replaceAll(RegExp(r'^[vV]'), '');
      final parts = clean.split('.').map((s) => int.tryParse(s) ?? 0).toList();
      while (parts.length < 3) {
        parts.add(0);
      }
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