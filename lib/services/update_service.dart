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

  /// Скачивает APK с поддержкой докачки.
  /// Файл сохраняется как .part. После успеха — переименовывается в .apk.
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

    // Если уже есть готовый APK — используем его
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

          // 200 = начинаем с нуля, 206 = Partial Content (докачка)
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
            // Сервер не поддержал Range — начинаем с нуля
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

          // Успех — переименовываем
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

  /// Открывает системный установщик.
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

  /// Удаляет временный файл .part — на случай, если нужно начать заново.
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

  bool _isNewer(List<int> a, List<int> b) {
    for (int i = 0; i < 3; i++) {
      if (a[i] > b[i]) return true;
      if (a[i] < b[i]) return false;
    }
    return false;
  }
}