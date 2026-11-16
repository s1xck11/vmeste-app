// tv/lib/services/update_service.dart
//
// Автообновление лаунчера: только релизы с тегами tv-v* (мобильный
// апдейтер их игнорирует). Скачиваем zip, распаковываем, bat меняет
// файлы после выхода процесса и запускает новую версию.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'ambient_service.dart';

class UpdateService extends ChangeNotifier {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const String _repo = 's1xck11/vmeste-app';

  String currentVersion = '0.0.0';
  String latestTag = '';
  String? zipUrl;
  bool ready = false;
  bool checking = false;
  bool downloading = false;
  bool autoApply = true;
  String? error;
  final ValueNotifier<double> progress = ValueNotifier(0);
  Timer? _timer;

  Future<void> init() async {
    final box = Hive.box('vmeste_tv_prefs');
    autoApply = box.get('upd_auto', defaultValue: true) as bool;
    try {
      final info = await PackageInfo.fromPlatform();
      currentVersion = info.version;
    } catch (_) {}
    notifyListeners();
    Future.delayed(const Duration(seconds: 20), () => check());
    _timer = Timer.periodic(const Duration(hours: 6), (_) => check());
  }

  List<int> _parse(String v) {
    final parts = v.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts;
  }

  bool _newer(List<int> a, List<int> b) {
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }

  Future<void> check() async {
    if (checking || downloading) return;
    checking = true;
    error = null;
    notifyListeners();
    try {
      final resp = await http
          .get(
            Uri.parse('https://api.github.com/repos/$_repo/releases'),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) throw Exception('http ${resp.statusCode}');
      final releases = jsonDecode(resp.body) as List;
      Map<String, dynamic>? found;
      for (final r in releases) {
        final m = Map<String, dynamic>.from(r as Map);
        final tag = (m['tag_name'] as String?) ?? '';
        if (tag.startsWith('tv-v')) {
          found = m;
          break;
        }
      }
      if (found == null) {
        ready = false;
      } else {
        final tag = found['tag_name'] as String;
        final remote = _parse(tag.replaceFirst('tv-v', ''));
        final assets = (found['assets'] as List?) ?? [];
        String? url;
        for (final a in assets) {
          final am = Map<String, dynamic>.from(a as Map);
          final name = (am['name'] as String?) ?? '';
          if (name.endsWith('.zip')) {
            url = am['browser_download_url'] as String?;
            break;
          }
        }
        latestTag = tag;
        zipUrl = url;
        ready = url != null && _newer(remote, _parse(currentVersion));
      }
    } catch (e) {
      error = 'Не удалось проверить обновления';
    }
    checking = false;
    notifyListeners();
    if (ready && autoApply && AmbientService.instance.active.value) {
      await apply();
    }
  }

  Future<void> setAutoApply(bool v) async {
    autoApply = v;
    await Hive.box('vmeste_tv_prefs').put('upd_auto', v);
    notifyListeners();
  }

  Future<void> apply() async {
    if (downloading || zipUrl == null) return;
    downloading = true;
    error = null;
    progress.value = 0;
    notifyListeners();
    try {
      final tmp = await getTemporaryDirectory();
      final zipPath = '${tmp.path}${Platform.pathSeparator}vmeste_tv_update.zip';
      final newDir = '${tmp.path}${Platform.pathSeparator}vmeste_tv_new';
      final dir = Directory(newDir);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      dir.createSync(recursive: true);

      final client = http.Client();
      try {
        final req = http.Request('GET', Uri.parse(zipUrl!));
        final resp = await client.send(req).timeout(const Duration(minutes: 5));
        if (resp.statusCode != 200) throw Exception('http ${resp.statusCode}');
        final total = resp.contentLength ?? 0;
        var got = 0;
        final sink = File(zipPath).openWrite();
        await for (final chunk in resp.stream) {
          sink.add(chunk);
          got += chunk.length;
          if (total > 0) progress.value = got / total;
        }
        await sink.close();
      } finally {
        client.close();
      }
      progress.value = 1;
      notifyListeners();

      final exp = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        'Expand-Archive -LiteralPath "$zipPath" -DestinationPath "$newDir" -Force',
      ]);
      if (exp.exitCode != 0) throw Exception('expand ${exp.exitCode}');

      final appDir = File(Platform.resolvedExecutable).parent.path;
      final exeName = Platform.resolvedExecutable.split(Platform.pathSeparator).last;
      final batPath = '${tmp.path}${Platform.pathSeparator}vmeste_tv_apply.bat';
      final bat = '''
@echo off
set PID=%1
set NEW=%2
set APP=%3
set EXE=%4
:wait
tasklist /FI "PID eq %PID%" 2>nul | find "%PID%" >nul
if not errorlevel 1 (
  timeout /t 1 /nobreak >nul
  goto wait
)
xcopy /e /y /i "%NEW%\\*" "%APP%\\" >nul
start "" "%APP%\\%EXE%"
del "%~f0"
''';
      await File(batPath).writeAsString(bat);
      await Process.start(
        'cmd.exe',
        ['/c', batPath, '$pid', newDir, appDir, exeName],
        mode: ProcessStartMode.detached,
      );
      exit(0);
    } catch (e) {
      error = 'Обновление не удалось: $e';
      downloading = false;
      notifyListeners();
    }
  }
}
