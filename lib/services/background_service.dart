// lib/services/background_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'storage_service.dart';

class BackgroundService {
  final StorageService storage;
  BackgroundService(this.storage);

  File? _bgFile;

  Future<File?> _getFile() async {
    if (_bgFile != null) return _bgFile;
    final dir = await getApplicationDocumentsDirectory();
    _bgFile = File('${dir.path}/bg_image.png');
    return _bgFile;
  }

  /// Асинхронно читает байты фона (если файл есть).
  Future<Uint8List?> loadImageBytes() async {
    try {
      final f = await _getFile();
      if (f == null || !await f.exists()) return null;
      return await f.readAsBytes();
    } catch (e) {
      return null;
    }
  }

  /// Синхронный флаг — есть ли фон (для UI без ожидания).
  bool get hasImage {
    final f = _bgFile;
    return f != null && f.existsSync();
  }

  Future<void> saveImage(Uint8List bytes) async {
    final f = await _getFile();
    if (f == null) return;
    await f.writeAsBytes(bytes);
    storage.bgImagePath = f.path;
  }

  Future<void> clearImage() async {
    try {
      final f = await _getFile();
      if (f != null && await f.exists()) await f.delete();
    } catch (_) {}
    storage.bgImagePath = '';
  }

  double get blur => storage.bgBlur;
  Future<void> setBlur(double v) async {
    storage.bgBlur = v;
  }
}