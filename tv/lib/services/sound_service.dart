// tv/lib/services/sound_service.dart
//
// Мягкие UI-звуки в духе PS5: синтезируются в WAV на лету (без ассетов),
// играют через audioplayers. Включены по умолчанию, mute — в топбаре.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

class SoundService extends ChangeNotifier {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const int _sr = 22050;

  bool enabled = true;
  double volume = 0.6;
  String? _dir;
  final List<AudioPlayer> _pool = [];
  int _i = 0;
  int _lastMove = 0;

  Future<void> init() async {
    final box = await Hive.openBox('vmeste_tv_prefs');
    enabled = box.get('sound_on', defaultValue: true) as bool;
    volume = (box.get('sound_vol', defaultValue: 0.6) as num).toDouble();
    try {
      final support = await getApplicationSupportDirectory();
      _dir = '${support.path}${Platform.pathSeparator}sounds';
      Directory(_dir!).createSync(recursive: true);
      _write('move', _tone(f0: 1568, dur: 0.045, amp: 0.16));
      _write('select', _chord([784, 1175], dur: 0.12, amp: 0.22));
      _write('open', _tone(f0: 523, f1: 1046, dur: 0.16, amp: 0.22));
      _write('back', _tone(f0: 659, f1: 392, dur: 0.12, amp: 0.2));
      _write('click', _tone(f0: 2000, dur: 0.03, amp: 0.14));
      _write('error', _tone(f0: 196, dur: 0.2, amp: 0.24, harm: 0.3));
      for (var k = 0; k < 4; k++) {
        _pool.add(AudioPlayer());
      }
    } catch (_) {}
    notifyListeners();
  }

  Float64List _tone({
    required double f0,
    double? f1,
    required double dur,
    double amp = 0.25,
    double harm = 0.18,
  }) {
    final n = (dur * _sr).toInt();
    final out = Float64List(n);
    var ph = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / _sr;
      final k = i / n;
      final f = f1 == null ? f0 : f0 + (f1 - f0) * k;
      ph += 2 * math.pi * f / _sr;
      final attack = math.min(1.0, t / 0.004);
      final env = attack * math.exp(-5.5 * k);
      out[i] = amp * env * (math.sin(ph) + harm * math.sin(2 * ph));
    }
    return out;
  }

  Float64List _chord(List<double> fs, {required double dur, double amp = 0.2}) {
    final n = (dur * _sr).toInt();
    final out = Float64List(n);
    final phs = List<double>.filled(fs.length, 0);
    for (var i = 0; i < n; i++) {
      final t = i / _sr;
      final k = i / n;
      final attack = math.min(1.0, t / 0.005);
      final env = attack * math.exp(-5.0 * k);
      var s = 0.0;
      for (var j = 0; j < fs.length; j++) {
        phs[j] += 2 * math.pi * fs[j] / _sr;
        s += math.sin(phs[j]) + 0.15 * math.sin(2 * phs[j]);
      }
      out[i] = amp * env * s / fs.length;
    }
    return out;
  }

  void _write(String name, Float64List s) {
    final data = Uint8List(44 + s.length * 2);
    final bd = ByteData.sublistView(data);
    void str(int o, String v) {
      for (var i = 0; i < v.length; i++) {
        data[o + i] = v.codeUnitAt(i);
      }
    }

    str(0, 'RIFF');
    bd.setUint32(4, 36 + s.length * 2, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little);
    bd.setUint16(22, 1, Endian.little);
    bd.setUint32(24, _sr, Endian.little);
    bd.setUint32(28, _sr * 2, Endian.little);
    bd.setUint16(32, 2, Endian.little);
    bd.setUint16(34, 16, Endian.little);
    str(36, 'data');
    bd.setUint32(40, s.length * 2, Endian.little);
    for (var i = 0; i < s.length; i++) {
      final v = (s[i].clamp(-1.0, 1.0) * 32767).round();
      bd.setInt16(44 + i * 2, v, Endian.little);
    }
    File('$_dir${Platform.pathSeparator}$name.wav').writeAsBytesSync(data);
  }

  void play(String name) {
    if (!enabled || _dir == null || _pool.isEmpty) return;
    if (name == 'move') {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastMove < 70) return;
      _lastMove = now;
    }
    final p = _pool[_i++ % _pool.length];
    try {
      p.play(DeviceFileSource('$_dir${Platform.pathSeparator}$name.wav'),
          volume: volume);
    } catch (_) {}
  }

  void move() => play('move');
  void select() => play('select');
  void open() => play('open');
  void back() => play('back');
  void click() => play('click');
  void error() => play('error');

  Future<void> setEnabled(bool v) async {
    enabled = v;
    final box = Hive.box('vmeste_tv_prefs');
    await box.put('sound_on', v);
    notifyListeners();
    if (v) select();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    final box = Hive.box('vmeste_tv_prefs');
    await box.put('sound_vol', volume);
    notifyListeners();
    play('move');
  }
}
