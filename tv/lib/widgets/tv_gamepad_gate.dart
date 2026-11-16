// tv/lib/widgets/tv_gamepad_gate.dart
//
// Глобальная обработка геймпада + режим курсора (R3) + амбиент + embed.
// Любая кнопка будит амбиент. В embed B открепляет окно.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart' show navigatorKey;
import '../services/ambient_service.dart';
import '../services/embed_service.dart';
import '../services/gamepad_service.dart';
import '../services/hints_service.dart';
import '../services/input_service.dart';
import '../services/osk_service.dart';
import '../services/sound_service.dart';

class _BackIntent extends Intent {
  const _BackIntent();
}

class TvGamepadGate extends StatefulWidget {
  final Widget child;

  const TvGamepadGate({super.key, required this.child});

  @override
  State<TvGamepadGate> createState() => _TvGamepadGateState();
}

class _TvGamepadGateState extends State<TvGamepadGate> {
  StreamSubscription<TvPadButton>? _sub;
  StreamSubscription<TvStickDir>? _stickSub;
  VoidCallback? _rStickListener;
  VoidCallback? _lStickListener;
  double _wheelAcc = 0;

  @override
  void initState() {
    super.initState();
    _sub = GamepadService.instance.buttons.listen(_onButton);
    _stickSub = GamepadService.instance.stick.listen(_onStickDir);
    _rStickListener = () {
      final v = GamepadService.instance.rightStick.value;
      if (v != Offset.zero) AmbientService.instance.bump();
      if (!InputService.instance.pointerMode.value) return;
      if (v == Offset.zero) return;
      final s = 14 * InputService.instance.sensitivity;
      InputService.instance.moveCursor(v.dx * s, -v.dy * s);
      HintsService.instance.bump();
    };
    _lStickListener = () {
      final v = GamepadService.instance.leftStick.value;
      if (v != Offset.zero) AmbientService.instance.bump();
      if (!InputService.instance.pointerMode.value) return;
      if (v.dy == 0) {
        _wheelAcc = 0;
        return;
      }
      _wheelAcc += -v.dy * 7;
      if (_wheelAcc.abs() >= 1) {
        InputService.instance.wheel(_wheelAcc.truncate());
        _wheelAcc = 0;
        HintsService.instance.bump();
      }
    };
    GamepadService.instance.rightStick.addListener(_rStickListener!);
    GamepadService.instance.leftStick.addListener(_lStickListener!);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _stickSub?.cancel();
    if (_rStickListener != null) {
      GamepadService.instance.rightStick.removeListener(_rStickListener!);
    }
    if (_lStickListener != null) {
      GamepadService.instance.leftStick.removeListener(_lStickListener!);
    }
    super.dispose();
  }

  void _togglePointer() {
    final on = !InputService.instance.pointerMode.value;
    InputService.instance.setPointerMode(on);
    SoundService.instance.open();
    if (on) {
      HintsService.instance.context([
        'Правый стик — курсор',
        'Левый стик — скролл',
        'A — клик, X — правый клик',
        'Крестовина — стрелки',
        'R3 — выйти из курсора',
      ]);
    } else {
      HintsService.instance.context(HintsService.instance.homeLines);
    }
  }

  void _onButton(TvPadButton b) {
    if (AmbientService.instance.active.value) {
      AmbientService.instance.exit();
      return;
    }
    AmbientService.instance.bump();
    HintsService.instance.bump();

    if (EmbedService.instance.active.value &&
        (b == TvPadButton.b || b == TvPadButton.back)) {
      EmbedService.instance.backCallback?.call();
      return;
    }

    final pointer = InputService.instance.pointerMode.value;

    if (b == TvPadButton.r3) {
      _togglePointer();
      return;
    }

    if (pointer) {
      switch (b) {
        case TvPadButton.a:
          InputService.instance.click();
          SoundService.instance.click();
          return;
        case TvPadButton.x:
          InputService.instance.click(right: true);
          SoundService.instance.click();
          return;
        case TvPadButton.up:
          InputService.instance.tapKey(InputService.vkUp);
          return;
        case TvPadButton.down:
          InputService.instance.tapKey(InputService.vkDown);
          return;
        case TvPadButton.left:
          InputService.instance.tapKey(InputService.vkLeft);
          return;
        case TvPadButton.right:
          InputService.instance.tapKey(InputService.vkRight);
          return;
        case TvPadButton.b:
        case TvPadButton.back:
          _togglePointer();
          return;
        case TvPadButton.y:
          OskService.instance.show(system: true);
          return;
        case TvPadButton.start:
          InputService.instance.setPointerMode(false);
          navigatorKey.currentState?.popUntil((r) => r.isFirst);
          HintsService.instance.context(HintsService.instance.homeLines);
          return;
        default:
          return;
      }
    }

    switch (b) {
      case TvPadButton.up:
        _move(TraversalDirection.up);
        break;
      case TvPadButton.down:
        _move(TraversalDirection.down);
        break;
      case TvPadButton.left:
        _move(TraversalDirection.left);
        break;
      case TvPadButton.right:
        _move(TraversalDirection.right);
        break;
      case TvPadButton.a:
        final ctx = primaryFocus?.context;
        if (ctx != null) Actions.invoke(ctx, const ActivateIntent());
        break;
      case TvPadButton.b:
      case TvPadButton.back:
        _back();
        break;
      case TvPadButton.start:
        if (OskService.instance.visible) OskService.instance.hide();
        navigatorKey.currentState?.popUntil((r) => r.isFirst);
        HintsService.instance.context(HintsService.instance.homeLines);
        break;
      case TvPadButton.y:
        if (OskService.instance.visible) {
          OskService.instance.hide();
        } else {
          OskService.instance.show(system: true);
        }
        break;
      case TvPadButton.x:
      case TvPadButton.lb:
      case TvPadButton.rb:
      case TvPadButton.l3:
        break;
    }
  }

  void _onStickDir(TvStickDir d) {
    if (AmbientService.instance.active.value) return;
    if (InputService.instance.pointerMode.value) return;
    if (OskService.instance.visible) return;
    switch (d) {
      case TvStickDir.up:
        _move(TraversalDirection.up);
        break;
      case TvStickDir.down:
        _move(TraversalDirection.down);
        break;
      case TvStickDir.left:
        _move(TraversalDirection.left);
        break;
      case TvStickDir.right:
        _move(TraversalDirection.right);
        break;
    }
  }

  void _back() {
    SoundService.instance.back();
    if (OskService.instance.visible) {
      OskService.instance.hide();
      return;
    }
    navigatorKey.currentState?.maybePop();
    final nav = navigatorKey.currentState;
    if (nav != null && !nav.canPop()) {
      HintsService.instance.context(HintsService.instance.homeLines);
    }
  }

  void _move(TraversalDirection dir) {
    final focus = primaryFocus;
    if (focus?.context != null) {
      Actions.invoke(focus!.context!, DirectionalFocusIntent(dir));
    } else {
      final ctx = navigatorKey.currentContext;
      if (ctx != null) FocusScope.of(ctx).focusInDirection(dir);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): _BackIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonB): _BackIntent(),
        SingleActivator(LogicalKeyboardKey.browserBack): _BackIntent(),
      },
      child: Actions(
        actions: {
          _BackIntent: CallbackAction<_BackIntent>(onInvoke: (_) {
            _back();
            return null;
          }),
        },
        child: widget.child,
      ),
    );
  }
}
