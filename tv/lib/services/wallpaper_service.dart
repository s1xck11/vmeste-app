// tv/lib/services/wallpaper_service.dart
//
// Обои лаунчера: 6 градиентных пресетов + своя картинка,
// затемнение и blur для читаемости контента. Всё в Hive.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

class WallpaperPreset {
  final String name;
  final List<Color> colors;
  const WallpaperPreset(this.name, this.colors);
}

class WallpaperService extends ChangeNotifier {
  WallpaperService._();
  static final WallpaperService instance = WallpaperService._();

  static const List<WallpaperPreset> presets = [
    WallpaperPreset('Аврора', [Color(0xFF0B1026), Color(0xFF1B2A5E), Color(0xFF3E2A6E)]),
    WallpaperPreset('Закат', [Color(0xFF1A0B14), Color(0xFF5E1B3A), Color(0xFF8A3A2A)]),
    WallpaperPreset('Океан', [Color(0xFF04121A), Color(0xFF0A3A4A), Color(0xFF0E5E5A)]),
    WallpaperPreset('Роза Вместе', [Color(0xFF160B10), Color(0xFF4A1B2E), Color(0xFF7A2E4A)]),
    WallpaperPreset('Космос', [Color(0xFF05060E), Color(0xFF101430), Color(0xFF2A1050)]),
    WallpaperPreset('Графит', [Color(0xFF0F0F0F), Color(0xFF1A1A1A), Color(0xFF242424)]),
  ];

  String mode = 'preset'; // preset | image
  int index = 0;
  String? imagePath;
  double dim = 0.45;
  bool blur = false;

  Future<void> init() async {
    final box = await Hive.openBox('vmeste_tv_prefs');
    mode = box.get('wp_mode', defaultValue: 'preset') as String;
    index = (box.get('wp_index', defaultValue: 0) as num).toInt();
    imagePath = box.get('wp_path') as String?;
    dim = (box.get('wp_dim', defaultValue: 0.45) as num).toDouble();
    blur = box.get('wp_blur', defaultValue: false) as bool;
    if (mode == 'image' && (imagePath == null || !File(imagePath!).existsSync())) {
      mode = 'preset';
    }
    notifyListeners();
  }

  Future<void> setPreset(int i) async {
    mode = 'preset';
    index = i.clamp(0, presets.length - 1);
    final box = Hive.box('vmeste_tv_prefs');
    await box.put('wp_mode', mode);
    await box.put('wp_index', index);
    notifyListeners();
  }

  Future<String?> pickImage() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        dialogTitle: 'Выбери обои для лаунчера',
      );
      final path = res?.files.single.path;
      if (path == null) return null;
      final support = await getApplicationSupportDirectory();
      final ext = path.contains('.') ? path.substring(path.lastIndexOf('.')) : '.jpg';
      final dst = '${support.path}${Platform.pathSeparator}wallpaper$ext';
      await File(path).copy(dst);
      mode = 'image';
      imagePath = dst;
      final box = Hive.box('vmeste_tv_prefs');
      await box.put('wp_mode', mode);
      await box.put('wp_path', dst);
      notifyListeners();
      return null;
    } catch (e) {
      return 'Не удалось открыть картинку: $e';
    }
  }

  Future<void> setDim(double v) async {
    dim = v.clamp(0.0, 0.85);
    await Hive.box('vmeste_tv_prefs').put('wp_dim', dim);
    notifyListeners();
  }

  Future<void> setBlur(bool v) async {
    blur = v;
    await Hive.box('vmeste_tv_prefs').put('wp_blur', v);
    notifyListeners();
  }

  Widget background({required Widget child}) {
    return AnimatedBuilder(
      animation: this,
      builder: (_, __) => Stack(
        fit: StackFit.expand,
        children: [
          if (mode == 'image' && imagePath != null)
            Image.file(
              File(imagePath!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _presetBg(),
            )
          else
            _presetBg(),
          if (blur)
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: const SizedBox.shrink(),
                ),
              ),
            ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(dim * 0.8),
                    Colors.black.withOpacity(dim),
                    Colors.black.withOpacity((dim + 0.15).clamp(0.0, 0.95)),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _presetBg() {
    final p = presets[index.clamp(0, presets.length - 1)];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: p.colors,
        ),
      ),
      child: Align(
        alignment: const Alignment(0.8, -0.7),
        child: Container(
          width: 700,
          height: 700,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                p.colors.last.withOpacity(0.55),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
