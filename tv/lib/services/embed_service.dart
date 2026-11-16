// tv/lib/services/embed_service.dart
//
// Встраивание окна любой программы внутрь лаунчера (SetParent).
// Наша панель сверху, окно программы — ниже. Откат: обычный запуск.

import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

final class _Win {
  static DynamicLibrary? u;
  static int Function(Pointer<Utf16>, Pointer<Utf16>)? findWindow;
  static int Function(Pointer<NativeFunction<Int32 Function(IntPtr, IntPtr)>>, int)? enumWindows;
  static int Function(int, Pointer<Uint32>)? threadPid;
  static int Function(int)? isVisible;
  static int Function(int, int)? setParent;
  static int Function(int, int, int, int, int, int)? moveWindow;
  static int Function(int, int)? getLong;
  static int Function(int, int, int)? setLong;
  static int Function(int, int, int, int, int, int, int)? setPos;
  static int Function(int, int)? showWindow;
  static int Function(int, int, int, int)? postMessage;
  static int Function(int)? foreground;
  static int Function(int, int)? getWindow;

  static void init() {
    if (u != null) return;
    try {
      u = DynamicLibrary.open('user32.dll');
      findWindow = u!.lookupFunction<
          IntPtr Function(Pointer<Utf16>, Pointer<Utf16>),
          int Function(Pointer<Utf16>, Pointer<Utf16>)>('FindWindowW');
      enumWindows = u!.lookupFunction<
          Int32 Function(Pointer<NativeFunction<Int32 Function(IntPtr, IntPtr)>>, IntPtr),
          int Function(Pointer<NativeFunction<Int32 Function(IntPtr, IntPtr)>>, int)>('EnumWindows');
      threadPid = u!.lookupFunction<Uint32 Function(IntPtr, Pointer<Uint32>),
          int Function(int, Pointer<Uint32>)>('GetWindowThreadProcessId');
      isVisible = u!.lookupFunction<Int32 Function(IntPtr), int Function(int)>('IsWindowVisible');
      setParent = u!.lookupFunction<IntPtr Function(IntPtr, IntPtr), int Function(int, int)>('SetParent');
      moveWindow = u!.lookupFunction<
          Int32 Function(IntPtr, Int32, Int32, Int32, Int32, Int32),
          int Function(int, int, int, int, int, int)>('MoveWindow');
      getLong = u!.lookupFunction<IntPtr Function(IntPtr, Int32), int Function(int, int)>('GetWindowLongPtrW');
      setLong = u!.lookupFunction<IntPtr Function(IntPtr, Int32, IntPtr), int Function(int, int, int)>('SetWindowLongPtrW');
      setPos = u!.lookupFunction<
          Int32 Function(IntPtr, IntPtr, Int32, Int32, Int32, Int32, Uint32),
          int Function(int, int, int, int, int, int, int)>('SetWindowPos');
      showWindow = u!.lookupFunction<Int32 Function(IntPtr, Int32), int Function(int, int)>('ShowWindow');
      postMessage = u!.lookupFunction<
          Int32 Function(IntPtr, Uint32, IntPtr, IntPtr),
          int Function(int, int, int, int)>('PostMessageW');
      foreground = u!.lookupFunction<IntPtr Function(IntPtr), int Function(int)>('SetForegroundWindow');
      getWindow = u!.lookupFunction<IntPtr Function(IntPtr, Uint32), int Function(int, int)>('GetWindow');
    } catch (_) {}
  }
}

int _enumPid = 0;
final List<int> _enumHits = [];

int _enumProc(int hwnd, int lp) {
  final pidPtr = calloc<Uint32>();
  _Win.threadPid?.call(hwnd, pidPtr);
  final pid = pidPtr.value;
  calloc.free(pidPtr);
  if (pid == _enumPid &&
      (_Win.isVisible?.call(hwnd) ?? 0) != 0 &&
      (_Win.getWindow?.call(hwnd, 4) ?? 0) == 0) {
    _enumHits.add(hwnd);
  }
  return 1;
}

class EmbedService {
  EmbedService._();
  static final EmbedService instance = EmbedService._();

  final ValueNotifier<bool> active = ValueNotifier(false);
  VoidCallback? backCallback;

  int _child = 0;
  int _parent = 0;
  int _oldStyle = 0;
  int _pid = 0;
  bool _full = false;

  static const int _gwlStyle = -16;
  static const int _wsCaption = 0x00C00000;
  static const int _wsThick = 0x00040000;
  static const int _wsChild = 0x40000000;
  static const int _swpNoZ = 0x0004;
  static const int _swpFrame = 0x0020;
  static const int _swpShow = 0x0040;
  static const int _swpNoMove = 0x0002;
  static const int _swpNoSize = 0x0001;
  static const int _swRestore = 9;
  static const int _wmClose = 0x0010;

  bool get available => _Win.setParent != null;

  /// Запускает exe и встраивает его окно. null — успех, иначе текст ошибки
  /// (окно уже запущено обычным способом как откат).
  Future<String?> embed(String path, String title) async {
    _Win.init();
    if (!available) return 'Встраивание недоступно';
    final file = File(path);
    if (!file.existsSync()) return 'Файл не найден: $path';
    try {
      final proc = await Process.start(
        path,
        [],
        workingDirectory: file.parent.path,
        mode: ProcessStartMode.detached,
      );
      _pid = proc.pid;
    } catch (e) {
      return 'Не удалось запустить: $e';
    }

    final titlePtr = 'Вместе ТВ'.toNativeUtf16();
    _parent = _Win.findWindow!(nullptr, titlePtr);
    calloc.free(titlePtr);
    if (_parent == 0) {
      return 'Окно лаунчера не найдено';
    }

    _child = 0;
    for (var i = 0; i < 26 && _child == 0; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      _enumPid = _pid;
      _enumHits.clear();
      final cb = NativeCallable<Int32 Function(IntPtr, IntPtr)>.isolateLocal(_enumProc);
      _Win.enumWindows!(cb.nativeFunction, 0);
      cb.close();
      if (_enumHits.isNotEmpty) _child = _enumHits.first;
    }
    if (_child == 0) {
      return 'Окно программы не появилось — запущено обычным способом';
    }

    _oldStyle = _Win.getLong!(_child, _gwlStyle);
    _Win.setParent!(_child, _parent);
    _Win.setLong!(
      _child,
      _gwlStyle,
      (_oldStyle & ~_wsCaption & ~_wsThick) | _wsChild,
    );
    _full = false;
    active.value = true;
    return null;
  }

  void setRect(int x, int y, int w, int h) {
    if (_child == 0) return;
    _Win.moveWindow!(_child, x, y, w, h, 1);
    _Win.setPos!(_child, 0, x, y, w, h, _swpFrame | _swpShow);
    _Win.foreground!(_child);
  }

  void setFull(bool v, int x, int y, int w, int h) {
    _full = v;
    setRect(v ? 0 : x, v ? 0 : y, w, v ? h : h - y);
  }

  bool get isFull => _full;

  /// Открепить: окно становится обычным, программа продолжает жить.
  void detach() {
    if (_child == 0) return;
    _Win.setParent!(_child, 0);
    _Win.setLong!(_child, _gwlStyle, _oldStyle);
    _Win.setPos!(_child, 0, 0, 0, 0, 0, _swpNoMove | _swpNoSize | _swpFrame | _swpShow);
    _Win.showWindow!(_child, _swRestore);
    _child = 0;
    active.value = false;
  }

  /// Закрыть программу вежливо (WM_CLOSE) и открепить.
  void closeApp() {
    if (_child == 0) return;
    _Win.postMessage!(_child, _wmClose, 0, 0);
    final c = _child;
    _child = 0;
    active.value = false;
    Future.delayed(const Duration(milliseconds: 400), () {
      _Win.setParent?.call(c, 0);
      _Win.setLong?.call(c, _gwlStyle, _oldStyle);
    });
  }
}
