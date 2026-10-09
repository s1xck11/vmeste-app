// lib/services/update_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
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

  static const String _repo = 's1xck11/vmeste-app';

  /// Кэш текущей версии, чтобы не запрашивать каждый раз.
  static String? _cachedVersion;
  static int? _cachedBuild;

  /// Возвращает реальную версию из pubspec (например, "1.1.0").
  static String get currentVersion => _cachedVersion ?? '...';

  /// Возвращает номер сборки (например, 100).
  static int get currentBuild => _cachedBuild ?? 0;

  /// Загружает версию из package_info_plus. Вызывается при старте приложения.
  static Future<void> loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _cachedVersion = info.version;
      _cachedBuild = int.tryParse(info.buildNumber) ?? 0;
    } catch (_) {
      _cachedVersion = '1.0.0';
      _cachedBuild = 0;
    }
  }

  Future<UpdateInfo?> checkForUpdate() async {
    try {
      _log.info('Update', 'проверка обновлений... (текущая $currentVersion+$currentBuild)');
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

      // Сравниваем по 4 частям: major.minor.build_number
      final ver = _parseVersion(tag) ?? [0, 0, 0];
      final currentVer = _parseVersion('v$currentVersion') ?? [0, 0, 0];

      // Сравниваем по major.minor (первые 2), а не по всему тегу
      final hasNewer = ver[0] > currentVer[0] ||
          (ver[0] == currentVer[0] && ver[1] > currentVer[1]) ||
          (ver[0] == currentVer[0] && ver[1] == currentVer[1] && ver[2] > currentBuild);

      if (hasNewer) {
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

      _log.info('Update', 'обновлений нет (текущая $currentVersion+$currentBuild, последняя $tag)');
      return null;
    } catch (e, st) {
      _log.error('Update', 'checkForUpdate FAILED', e, st);
      return null;
    }
  }

  /// Скачивает APK с поддержкой докачки.
  Future<File?> downloadApk(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
    void Function(String status)? onStatus,
  }) async {
    if (info.apkUrl == null) {
      _log.warn('Update', 'нет APK в релизе');
      return null;
    }

    const maxAttempts = 5;
    final dir = await getTemporaryDirectory();
    final partFile = File('${dir.path}/vmeste-${info.tag}.apk.part');
    final finalFile = File('${dir.path}/vmeste-${info.tag}.apk');

    if (await finalFile.exists()) {
      _log.info('Update', 'уже скачан: ${finalFile.path}');
      return finalFile;
    }

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        int existingLength = 0;
        if (await partFile.exists()) {
          existingLength = await partFile.length();
        }

        _log.info('Update', 'попытка $attempt/$maxAttempts, уже есть $existingLength байт');
        if (onStatus != null) {
          onStatus(attempt == 1 && existingLength == 0
              ? 'Скачивание...'
              : 'Докачка (попытка $attempt)...');
        }

        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 30);
        client.idleTimeout = const Duration(seconds: 60);
        client.badCertificateCallback = (cert, host, port) => true;

        try {
          final uri = Uri.parse(info.apkUrl!);
          final request = await client.getUrl(uri);
          request.followRedirects = true;
          request.headers.set('Accept', '*/*');
          if (existingLength > 0) {
            request.headers.set('Range', 'bytes=$existingLength-');
          }

          final response = await request.close();
          final status = response.statusCode;

          if (status != 200 && status != 206) {
            _log.warn('Update', 'HTTP $status');
            client.close(force: true);
            return null;
          }

          int startFrom = 0;
          if (status == 206 && existingLength > 0) {
            startFrom = existingLength;
            _log.info('Update', 'сервер поддержал докачку с $startFrom');
          } else if (status == 200) {
            if (existingLength > 0) {
              _log.info('Update', 'сервер НЕ поддержал докачку — начинаем с нуля');
            }
            startFrom = 0;
            if (await partFile.exists()) await partFile.delete();
          }

          final total = (response.contentLength > 0
              ? response.contentLength + startFrom
              : info.apkSize);

          final sink = partFile.openWrite(mode: FileMode.append);
          int received = startFrom;
          if (onProgress != null) onProgress(received, total);

          await for (final chunk in response) {
            sink.add(chunk);
            received += chunk.length;
            if (onProgress != null) onProgress(received, total);
          }

          await sink.flush();
          await sink.close();
          client.close();

          if (await finalFile.exists()) await finalFile.delete();
          await partFile.rename(finalFile.path);
          _log.info('Update', 'скачано: ${finalFile.path} (${received ~/ 1024} КБ)');
          return finalFile;
        } finally {
          client.close(force: true);
        }
      } catch (e, st) {
        _log.error('Update', 'попытка $attempt FAILED', e, st);
        if (onStatus != null) {
          onStatus('Обрыв, повтор через 3 сек...');
        }
        if (attempt < maxAttempts) {
          await Future.delayed(const Duration(seconds: 3));
        }
      }
    }

    _log.warn('Update', 'не удалось скачать за $maxAttempts попыток, файл .part сохранён');
    return null;
  }

  /// Открывает системный установщик через open_filex (правильно на Android).
  Future<bool> installApk(File file) async {
    try {
      _log.info('Update', 'открываю установщик: ${file.path}');
      final result = await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
      _log.info('Update', 'результат: ${result.type} — ${result.message}');
      return result.type == ResultType.done;
    } catch (e, st) {
      _log.error('Update', 'installApk FAILED', e, st);
      return false;
    }
  }

  Future<void> clearPartial(String tag) async {
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/vmeste-$tag.apk.part');
      if (await f.exists()) await f.delete();
    } catch (_) {}
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
}