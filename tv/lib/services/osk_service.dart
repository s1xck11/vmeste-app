// tv/lib/services/osk_service.dart
//
// Экранная клавиатура: печатает в TextField лаунчера, в поле сайта (JS)
// или СИСТЕМНО в любое активное окно (WIN-режим, SendInput unicode).

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'hints_service.dart';
import 'input_service.dart';

class OskService extends ChangeNotifier {
  OskService._();
  static final OskService instance = OskService._();

  bool visible = false;
  bool ru = true;
  bool shift = false;
  bool symbols = false;
  bool systemMode = false;

  TextEditingController? controller;
  VoidCallback? onSubmit;
  void Function(String char)? onChar;
  VoidCallback? onBackspace;
  VoidCallback? onEnter;

  bool get hasTarget => controller != null || onChar != null || systemMode;

  void show({
    TextEditingController? controller,
    VoidCallback? onSubmit,
    void Function(String char)? onChar,
    VoidCallback? onBackspace,
    VoidCallback? onEnter,
    bool system = false,
  }) {
    this.controller = controller;
    this.onSubmit = onSubmit;
    this.onChar = onChar;
    this.onBackspace = onBackspace;
    this.onEnter = onEnter;
    systemMode = system;
    visible = true;
    notifyListeners();
    HintsService.instance.context([
      'A — нажать клавишу',
      'B — скрыть клаву',
      'MODE — сайт / Windows',
    ]);
  }

  void hide() {
    visible = false;
    controller = null;
    onSubmit = null;
    onChar = null;
    onBackspace = null;
    onEnter = null;
    systemMode = false;
    notifyListeners();
    HintsService.instance.context(HintsService.instance.homeLines);
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
      case 'mode':
        systemMode = !systemMode;
        if (systemMode) {
          controller = null;
          onChar = null;
          onBackspace = null;
          onEnter = null;
        }
        notifyListeners();
        return;
      case 'hide':
        hide();
        return;
      case 'back':
        _backspace();
        return;
      case 'enter':
        if (systemMode) {
          InputService.instance.tapKey(InputService.vkReturn);
        } else if (controller != null) {
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
    if (systemMode) {
      InputService.instance.unicode(ch);
      return;
    }
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
    if (systemMode) {
      InputService.instance.tapKey(InputService.vkBack);
      return;
    }
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
