// tv/lib/services/osk_service.dart
//
// Экранная клавиатура: печатает либо в TextField лаунчера,
// либо прямо в поле открытого сайта (через JS-инъекцию).

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class OskService extends ChangeNotifier {
  OskService._();
  static final OskService instance = OskService._();

  bool visible = false;
  bool ru = true;
  bool shift = false;
  bool symbols = false;

  TextEditingController? controller;
  VoidCallback? onSubmit;
  void Function(String char)? onChar;
  VoidCallback? onBackspace;
  VoidCallback? onEnter;

  bool get hasTarget => controller != null || onChar != null;

  void show({
    TextEditingController? controller,
    VoidCallback? onSubmit,
    void Function(String char)? onChar,
    VoidCallback? onBackspace,
    VoidCallback? onEnter,
  }) {
    this.controller = controller;
    this.onSubmit = onSubmit;
    this.onChar = onChar;
    this.onBackspace = onBackspace;
    this.onEnter = onEnter;
    visible = true;
    notifyListeners();
  }

  void hide() {
    visible = false;
    controller = null;
    onSubmit = null;
    onChar = null;
    onBackspace = null;
    onEnter = null;
    notifyListeners();
  }

  void toggle() {
    if (visible) {
      hide();
    } else if (hasTarget) {
      visible = true;
      notifyListeners();
    }
  }

  void press(String key) {
    switch (key) {
      case 'shift':
        shift = !shift;
        notifyListeners();
        return;
      case 'lang':
        ru = !ru;
        symbols = false;
        notifyListeners();
        return;
      case 'page':
        symbols = !symbols;
        notifyListeners();
        return;
      case 'hide':
        hide();
        return;
      case 'back':
        _backspace();
        return;
      case 'enter':
        if (controller != null) {
          onSubmit?.call();
        } else {
          onEnter?.call();
        }
        return;
      case 'space':
        _insert(' ');
        return;
      default:
        var ch = key;
        if (shift && !symbols) {
          ch = ch.toUpperCase();
          shift = false;
        }
        _insert(ch);
        notifyListeners();
    }
  }

  void _insert(String ch) {
    final c = controller;
    if (c != null) {
      final text = c.text;
      final sel = c.selection;
      final start = sel.isValid ? sel.start : text.length;
      final end = sel.isValid ? sel.end : text.length;
      final newText = text.replaceRange(start, end, ch);
      c.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + ch.length),
      );
    } else {
      onChar?.call(ch);
    }
  }

  void _backspace() {
    final c = controller;
    if (c != null) {
      final text = c.text;
      final sel = c.selection;
      var start = sel.isValid ? sel.start : text.length;
      final end = sel.isValid ? sel.end : text.length;
      if (start == end && start > 0) start -= 1;
      if (start == end) return;
      final newText = text.replaceRange(start, end, '');
      c.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start),
      );
    } else {
      onBackspace?.call();
    }
  }
}
