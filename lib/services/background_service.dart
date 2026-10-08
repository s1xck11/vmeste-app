// lib/services/background_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'storage_service.dart';

class BackgroundService {
  static BackgroundService? _instance;
  static BackgroundService get instance {
    if (_instance == null) throw StateError('BackgroundService не инициализирован');
    return _instance!;
  }

  final StorageService storage;
  BackgroundService._(this.storage);

  factory BackgroundService.init(StorageService storage) {
    _instance = BackgroundService._(storage);
    return _instance!;
  }

  File? _bgFile;

  /// Уведомляет UI об изменении фона (путь к файлу или пустая строка).
  final ValueNotifier<String> notifier = ValueNotifier('');

  Future<File?> _getFile() async {
    if (_bgFile != null) return _bgFile;
    final dir = await getApplicationDocumentsDirectory();
    _bgFile = File('${dir.path}/bg_image.png');
    return _bgFile;
  }

  Future<Uint8List?> loadImageBytes() async {
    try {
      final f = await _getFile();
      if (f == null || !await f.exists()) return null;
      return await f.readAsBytes();
    } catch (e) {
      return null;
    }
  }

  bool get hasImage {
    final f = _bgFile;
    return f != null && f.existsSync();
  }

  Future<void> saveImage(Uint8List bytes) async {
    final f = await _getFile();
    if (f == null) return;
    await f.writeAsBytes(bytes);
    storage.bgImagePath = f.path;
    notifier.value = f.path;
  }

  Future<void> clearImage() async {
    try {
      final f = await _getFile();
      if (f != null && await f.exists()) await f.delete();
    } catch (_) {}
    storage.bgImagePath = '';
    notifier.value = '';
  }

  double get blur => storage.bgBlur;
  Future<void> setBlur(double v) async {
    storage.bgBlur = v;
    notifier.value = storage.bgImagePath;
  }
}