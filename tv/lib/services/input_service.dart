// tv/lib/services/input_service.dart
//
// Реальный ввод Windows через user32.dll (SendInput / SetCursorPos).
// Даёт геймпаду мышь и клавиатуру СИСТЕМНО — в любом окне, не только в лаунчере.

import 'dart:ffi';
import 'dart:ui' show Offset;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

final class _MouseInput extends Struct {
  @Int32()
  external int dx;
  @Int32()
  external int dy;
  @Uint32()
  external int mouseData;
  @Uint32()
  external int dwFlags;
  @Uint32()
  external int time;
  @IntPtr()
  external int dwExtraInfo;
}

final class _KeyboardInput extends Struct {
  @Uint16()
  external int wVk;
  @Uint16()
  external int wScan;
  @Uint32()
  external int dwFlags;
  @Uint32()
  external int time;
  @IntPtr()
  external int dwExtraInfo;
}

final class _InputUnion extends Union {
  external _MouseInput mi;
  external _KeyboardInput ki;
}

final class _Input extends Struct {
  @Uint32()
  external int type;
  external _InputUnion u;
}

class InputService {
  InputService._();
  static final InputService instance = InputService._();

  static const int vkBack = 0x08;
  static const int vkTab = 0x09;
  static const int vkReturn = 0x0D;
  static const int vkEscape = 0x1B;
  static const int vkSpace = 0x20;
  static const int vkLeft = 0x25;
  static const int vkUp = 0x26;
  static const int vkRight = 0x27;
  static const int vkDown = 0x28;

  int Function(int, Pointer<_Input>, int)? _send;
  int Function(int, int)? _setPos;
  int Function(int)? _metrics;
  int Function(int)? _showCursor;
  Pointer<_Input>? _buf;

  bool _cursorHidden = false;
  int screenW = 1920;
  int screenH = 1080;

  /// Режим курсора: геймпад водит мышью системно.
  final ValueNotifier<bool> pointerMode = ValueNotifier(false);
  final ValueNotifier<Offset> cursor = ValueNotifier(const Offset(960, 540));
  final ValueNotifier<int> clickPulse = ValueNotifier(0);
  double sensitivity = 1.0;

  bool get available => _send != null;

  void init() {
    if (_send != null) return;
    try {
      final u = DynamicLibrary.open('user32.dll');
      _send = u.lookupFunction<Uint32 Function(Uint32, Pointer<_Input>, Int32),
          int Function(int, Pointer<_Input>, int)>('SendInput');
      _setPos = u.lookupFunction<Int32 Function(Int32, Int32),
          int Function(int, int)>('SetCursorPos');
      _metrics = u.lookupFunction<Int32 Function(Int32), int Function(int)>(
          'GetSystemMetrics');
      _showCursor = u.lookupFunction<Int32 Function(Int32), int Function(int)>(
          'ShowCursor');
      _buf = calloc<_Input>();
      screenW = _metrics!(0);
      screenH = _metrics!(1);
      cursor.value = Offset(screenW / 2, screenH / 2);
    } catch (_) {}
  }

  void _submit(int type, void Function(_Input) fill) {
    final p = _buf;
    final send = _send;
    if (p == null || send == null) return;
    p.ref.type = type;
    fill(p.ref);
    send(1, p, sizeOf<_Input>());
  }

  void moveAbs(int x, int y) {
    _setPos?.call(x.clamp(0, screenW - 1), y.clamp(0, screenH - 1));
  }

  void moveCursor(double dx, double dy) {
    final c = cursor.value;
    final n = Offset(
      (c.dx + dx).clamp(0, (screenW - 1).toDouble()),
      (c.dy + dy).clamp(0, (screenH - 1).toDouble()),
    );
    cursor.value = n;
    moveAbs(n.dx.round(), n.dy.round());
  }

  void click({bool right = false}) {
    clickPulse.value++;
    _submit(0, (i) {
      i.u.mi.dx = 0;
      i.u.mi.dy = 0;
      i.u.mi.mouseData = 0;
      i.u.mi.time = 0;
      i.u.mi.dwExtraInfo = 0;
      i.u.mi.dwFlags = right ? 0x0008 : 0x0002;
    });
    _submit(0, (i) {
      i.u.mi.dx = 0;
      i.u.mi.dy = 0;
      i.u.mi.mouseData = 0;
      i.u.mi.time = 0;
      i.u.mi.dwExtraInfo = 0;
      i.u.mi.dwFlags = right ? 0x0010 : 0x0004;
    });
  }

  void wheel(int delta) {
    _submit(0, (i) {
      i.u.mi.dx = 0;
      i.u.mi.dy = 0;
      i.u.mi.time = 0;
      i.u.mi.dwExtraInfo = 0;
      i.u.mi.dwFlags = 0x0800;
      i.u.mi.mouseData = delta & 0xFFFFFFFF;
    });
  }

  void key(int vk, {bool up = false}) {
    _submit(1, (i) {
      i.u.ki.wVk = vk;
      i.u.ki.wScan = 0;
      i.u.ki.time = 0;
      i.u.ki.dwExtraInfo = 0;
      i.u.ki.dwFlags = up ? 0x0002 : 0;
    });
  }

  void tapKey(int vk) {
    key(vk);
    key(vk, up: true);
  }

  /// Печатает текст в ЛЮБОЕ активное окно (unicode-ввод).
  void unicode(String s) {
    for (final c in s.codeUnits) {
      _submit(1, (i) {
        i.u.ki.wVk = 0;
        i.u.ki.wScan = c;
        i.u.ki.time = 0;
        i.u.ki.dwExtraInfo = 0;
        i.u.ki.dwFlags = 0x0004;
      });
      _submit(1, (i) {
        i.u.ki.wVk = 0;
        i.u.ki.wScan = c;
        i.u.ki.time = 0;
        i.u.ki.dwExtraInfo = 0;
        i.u.ki.dwFlags = 0x0004 | 0x0002;
      });
    }
  }

  void setPointerMode(bool v) {
    if (pointerMode.value == v) return;
    pointerMode.value = v;
    if (v) {
      cursor.value = Offset(screenW / 2, screenH / 2);
      moveAbs(screenW ~/ 2, screenH ~/ 2);
      if (!_cursorHidden) {
        _showCursor?.call(0);
        _cursorHidden = true;
      }
    } else {
      if (_cursorHidden) {
        _showCursor?.call(1);
        _cursorHidden = false;
      }
    }
  }
}
