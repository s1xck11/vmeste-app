// tv/lib/widgets/tv_gamepad_gate.dart
//
// Глобальная обработка геймпада:
// крестовина — фокус, A — открыть, B/Back — назад, Start — домой,
// Y — экранная клава. X/LB/RB отдаются экрану браузера.

import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart' show navigatorKey;
import '../services/gamepad_service.dart';
import '../services/osk_service.dart';

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

  @override
  void initState() {
    super.initState();
    _sub = GamepadService.instance.buttons.listen(_onButton);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onButton(TvPadButton b) {
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
        break;
      case TvPadButton.y:
        OskService.instance.toggle();
        break;
      case TvPadButton.x:
      case TvPadButton.lb:
      case TvPadButton.rb:
        break;
    }
  }

  void _back() {
    if (OskService.instance.visible) {
      OskService.instance.hide();
    } else {
      navigatorKey.currentState?.maybePop();
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
