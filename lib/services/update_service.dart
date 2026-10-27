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
  static const Duration _checkInterval = Duration(hours: 1);

  static String _currentVersion = '1.0.0';
  static int _currentBuild = 0;
  static bool _loaded = false;
  static DateTime? _lastCheckTime;

  static String get currentVersion => _currentVersion;
  static int get currentBuild => _currentBuild;
  static String get currentFull => '$_currentVersion+$_currentBuild';

  static Future<void> loadVersion() async {
    if (_loaded) return;
    try {
      final info = await PackageInfo.fromPlatform();
      _currentVersion = info.version;
      _currentBuild = int.tryParse(info.buildNumber) ?? 0;
      _loaded = true;
    } catch (_) {
      _currentVersion = '1.0.0';
      _currentBuild = 0;
      _loaded = true;
    }
  }

  bool _shouldCheck() {
    if (_lastCheckTime == null) return true;
    return DateTime.now().difference(_lastCheckTime!) > _checkInterval;
  }

  Future<UpdateInfo?> checkForUpdate({bool force = false}) async {
    if (!force && !_shouldCheck()) {
      _log.info('Update', 'слишком часто, пропускаю');
      return null;
    }

    try {
      _log.info('Update', 'проверка обновлений... (текущая ${currentFull})');
      
      // Берем список всех релизов (а не latest), чтобы отфильтровать хабы
      final uri = Uri.parse('https://api.github.com/repos/$_repo/releases');
      final resp = await http.get(
        uri,
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 20));

      _lastCheckTime = DateTime.now();

      if (resp.statusCode != 200) {
        _log.warn('Update', 'HTTP ${resp.statusCode}');
        return null;
      }

      final List<dynamic> releases = jsonDecode(resp.body) as List<dynamic>;
      
      Map<String, dynamic>? mobileRelease;
      for (final r in releases) {
        final rMap = Map<String, dynamic>.from(r as Map);
        final tag = (rMap['tag_name'] as String?) ?? '';
        // Нас интересуют только мобильные релизы: начинаются на "v" но НЕ на "hub-v"
        if (tag.startsWith('v') && !tag.startsWith('hub-v')) {
          mobileRelease = rMap;
          break;
        }
      }

      if (mobileRelease == null) {
        _log.info('Update', 'нет мобильных релизов');
        return null;
      }

      final tag = (mobileRelease['tag_name'] as String?) ?? '';
      final name = (mobileRelease['name'] as String?) ?? tag;
      final body = (mobileRelease['body'] as String?) ?? '';

      // Убираем "v" из тега: "v1.1.221" -> "1.1.221"
      final remoteVersion = tag.replaceAll(RegExp(r'^[vV]'), '');
      _log.info('Update', 'последний мобильный релиз: $tag (версия $remoteVersion)');

      if (remoteVersion == currentVersion) {
        _log.info('Update', 'обновлений нет');
        return null;
      }

      final ver = _parseVersion(remoteVersion);
      final curVer = _parseVersion(currentVersion);
      if (ver != null && curVer != null && !_isNewer(ver, curVer)) {
        _log.info('Update', 'версия на сервере не новее');
        return null;
      }

      final assets = (mobileRelease['assets'] as List?) ?? [];
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

      _log.info('Update', 'найдено обновление: $tag');
      return UpdateInfo(
        tag: tag,
        version: remoteVersion,
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

  Future<File?> downloadApk(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
    void Function(String status)? onStatus,
  }) async {
    if (info.apkUrl == null) return null;

    const maxAttempts = 5;
    final dir = await getTemporaryDirectory();
    final partFile = File('${dir.path}/vmeste-${info.tag}.apk.part');
    final finalFile = File('${dir.path}/vmeste-${info.tag}.apk');

    if (await finalFile.exists()) return finalFile;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        int existingLength = 0;
        if (await partFile.exists()) existingLength = await partFile.length();

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
          if (existingLength > 0) {
            request.headers.set('Range', 'bytes=$existingLength-');
          }

          final response = await request.close();
          final status = response.statusCode;

          if (status != 200 && status != 206) return null;

          int startFrom = 0;
          if (status == 206 && existingLength > 0) {
            startFrom = existingLength;
          } else if (status == 200) {
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
          return finalFile;
        } finally {
          client.close(force: true);
        }
      } catch (e, st) {
        if (onStatus != null) onStatus('Обрыв, повтор через 3 сек...');
        if (attempt < maxAttempts) await Future.delayed(const Duration(seconds: 3));
      }
    }
    return null;
  }

  Future<bool> installApk(File file) async {
    try {
      final result = await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
      return result.type == ResultType.done;
    } catch (e) {
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

  List<int>? _parseVersion(String v) {
    try {
      final parts = v.split('.').map((s) => int.tryParse(s) ?? 0).toList();
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