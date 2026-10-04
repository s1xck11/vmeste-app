// lib/services/background_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'storage_service.dart';

class BackgroundService {
  final StorageService storage;
  BackgroundService(this.storage);

  Uint8List? getImageBytes() {
    final raw = storage.bgImageBase64;
    if (raw.isEmpty) return null;
    try { return base64Decode(raw); } catch (_) { return null; }
  }

  Future<void> saveImage(Uint8List bytes) async {
    storage.bgImageBase64 = base64Encode(bytes);
  }

  Future<void> clearImage() async {
    storage.bgImageBase64 = '';
  }

  double get blur => storage.bgBlur;
  Future<void> setBlur(double v) async {
    storage.bgBlur = v;
  }
}