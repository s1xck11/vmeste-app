// tv/lib/services/hints_service.dart
//
// Контекстные подсказки управления в правом нижнем углу.
// Появляются при смене контекста/активности, гаснут через 6 секунд.

import 'dart:async';

import 'package:flutter/foundation.dart';

class HintsService extends ChangeNotifier {
  HintsService._();
  static final HintsService instance = HintsService._();

  List<String> lines = [];
  List<String> homeLines = [];
  bool visible = false;
  bool enabled = true;
  Timer? _t;

  void base(List<String> l, {bool isHome = false}) {
    if (isHome) homeLines = l;
    context(l);
  }

  void context(List<String> l) {
    lines = l;
    _show();
  }

  void bump() {
    if (lines.isNotEmpty) _show();
  }

  void _show() {
    _t?.cancel();
    if (!enabled) {
      if (visible) {
        visible = false;
        notifyListeners();
      }
      return;
    }
    visible = true;
    notifyListeners();
    _t = Timer(const Duration(seconds: 6), () {
      visible = false;
      notifyListeners();
    });
  }

  void setEnabled(bool v) {
    enabled = v;
    if (!v) {
      visible = false;
      notifyListeners();
    } else {
      _show();
    }
  }
}
