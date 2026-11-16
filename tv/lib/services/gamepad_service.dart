// tv/lib/services/gamepad_service.dart
//
// Геймпад через XInput (протокол Xbox) напрямую из dart:ffi.
// Крестовина/кнопки → buttons, левый стик → stick (дискретно),
// оба стика → аналоговые notifiers для курсора и скролла.

import 'dart:async';
import 'dart:ffi';
import 'dart:ui' show Offset;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

final class _XInputGamepad extends Struct {
  @Uint16()
  external int wButtons;
  @Uint8()
  external int bLeftTrigger;
  @Uint8()
  external int bRightTrigger;
  @Int16()
  external int sThumbLX;
  @Int16()
  external int sThumbLY;
  @Int16()
  external int sThumbRX;
  @Int16()
  external int sThumbRY;
}

final class _XInputState extends Struct {
  @Uint32()
  external int dwPacketNumber;
  external _XInputGamepad gamepad;
}

enum TvPadButton { up, down, left, right, a, b, x, y, start, back, lb, rb, l3, r3 }

enum TvStickDir { up, down, left, right }

class GamepadService {
  GamepadService._();
  static final GamepadService instance = GamepadService._();

  static const int _deadzone = 10000;
  static const double _stickDz = 0.18;

  static const Map<int, TvPadButton> _masks = {
    0x0001: TvPadButton.up,
    0x0002: TvPadButton.down,
    0x0004: TvPadButton.left,
    0x0008: TvPadButton.right,
    0x0010: TvPadButton.start,
    0x0020: TvPadButton.back,
    0x0100: TvPadButton.lb,
    0x0200: TvPadButton.rb,
    0x0040: TvPadButton.l3,
    0x0080: TvPadButton.r3,
    0x1000: TvPadButton.a,
    0x2000: TvPadButton.b,
    0x4000: TvPadButton.x,
    0x8000: TvPadButton.y,
  };

  final _buttons = StreamController<TvPadButton>.broadcast();
  final _stick = StreamController<TvStickDir>.broadcast();
  final ValueNotifier<bool> connected = ValueNotifier(false);
  final ValueNotifier<Offset> leftStick = ValueNotifier(Offset.zero);
  final ValueNotifier<Offset> rightStick = ValueNotifier(Offset.zero);

  Stream<TvPadButton> get buttons => _buttons.stream;
  Stream<TvStickDir> get stick => _stick.stream;

  int Function(int, Pointer<_XInputState>)? _getState;
  Pointer<_XInputState>? _state;
  Timer? _timer;

  final List<int> _prev = [0, 0, 0, 0];
  final List<TvPadButton?> _dpadDir = [null, null, null, null];
  final List<int> _dpadNext = [0, 0, 0, 0];
  final List<TvStickDir?> _stickDir = [null, null, null, null];
  final List<int> _stickNext = [0, 0, 0, 0];

  void init() {
    if (_getState != null || _timer != null) return;
    for (final name in ['xinput1_4.dll', 'xinput9_1_0.dll']) {
      try {
        final lib = DynamicLibrary.open(name);
        _getState = lib.lookupFunction<
            Uint32 Function(Uint32, Pointer<_XInputState>),
            int Function(int, Pointer<_XInputState>)>('XInputGetState');
        break;
      } catch (_) {}
    }
    if (_getState == null) return;
    _state = calloc<_XInputState>();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _poll());
  }

  double _norm(int v) {
    final n = v / 32767.0;
    if (n.abs() < _stickDz) return 0;
    return n.clamp(-1.0, 1.0);
  }

  void _poll() {
    final getState = _getState;
    final state = _state;
    if (getState == null || state == null) return;
    bool any = false;
    final now = DateTime.now().millisecondsSinceEpoch;
    var lAcc = Offset.zero;
    var rAcc = Offset.zero;

    for (int i = 0; i < 4; i++) {
      if (getState(i, state) != 0) {
        _prev[i] = 0;
        _dpadDir[i] = null;
        _stickDir[i] = null;
        continue;
      }
      any = true;
      final g = state.ref.gamepad;
      final cur = g.wButtons;
      final pressed = cur & ~_prev[i];
      _prev[i] = cur;

      _masks.forEach((mask, btn) {
        if ((pressed & mask) != 0) _buttons.add(btn);
      });

      TvPadButton? hold;
      if ((cur & 0x0001) != 0) {
        hold = TvPadButton.up;
      } else if ((cur & 0x0002) != 0) {
        hold = TvPadButton.down;
      } else if ((cur & 0x0004) != 0) {
        hold = TvPadButton.left;
      } else if ((cur & 0x0008) != 0) {
        hold = TvPadButton.right;
      }
      if (hold != _dpadDir[i]) {
        _dpadDir[i] = hold;
        _dpadNext[i] = now + 350;
      } else if (hold != null && now >= _dpadNext[i]) {
        _buttons.add(hold);
        _dpadNext[i] = now + 140;
      }

      final lx = g.sThumbLX;
      final ly = g.sThumbLY;
      lAcc = Offset(lAcc.dx + _norm(lx), lAcc.dy + _norm(ly));
      rAcc = Offset(rAcc.dx + _norm(g.sThumbRX), rAcc.dy + _norm(g.sThumbRY));

      TvStickDir? dir;
      if (ly.abs() >= lx.abs()) {
        if (ly > _deadzone) {
          dir = TvStickDir.up;
        } else if (ly < -_deadzone) {
          dir = TvStickDir.down;
        }
      } else {
        if (lx > _deadzone) {
          dir = TvStickDir.right;
        } else if (lx < -_deadzone) {
          dir = TvStickDir.left;
        }
      }
      if (dir != _stickDir[i]) {
        _stickDir[i] = dir;
        if (dir != null) {
          _stick.add(dir);
          _stickNext[i] = now + 350;
        }
      } else if (dir != null && now >= _stickNext[i]) {
        _stick.add(dir);
        _stickNext[i] = now + 140;
      }
    }

    leftStick.value = lAcc;
    rightStick.value = rAcc;
    if (connected.value != any) connected.value = any;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    if (_state != null) {
      calloc.free(_state!);
      _state = null;
    }
    _buttons.close();
    _stick.close();
  }
}
