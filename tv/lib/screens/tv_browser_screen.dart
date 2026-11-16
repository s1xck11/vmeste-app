// tv/lib/screens/tv_browser_screen.dart
//
// Edge ВНУТРИ лаунчера (WebView2).
// Геймпад: LB/RB — назад/вперёд, X — обновить, стик — скролл.
// Экранная клава печатает прямо в поле сайта через JS.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

import '../main.dart' show tiles;
import '../services/gamepad_service.dart';
import '../services/osk_service.dart';
import '../services/tiles_service.dart';
import '../theme/tv_theme.dart';
import '../widgets/tv_focusable.dart';

class TvBrowserScreen extends StatefulWidget {
  final String url;
  final String title;

  const TvBrowserScreen({super.key, required this.url, required this.title});

  @override
  State<TvBrowserScreen> createState() => _TvBrowserScreenState();
}

class _TvBrowserScreenState extends State<TvBrowserScreen> {
  WebviewController? _c;
  bool _ready = false;
  String? _error;
  late String _title = widget.title;
  late String _url = widget.url;
  bool _loading = true;
  bool _canBack = false;
  bool _canFwd = false;
  bool _webFs = false;

  final List<StreamSubscription> _subs = [];
  StreamSubscription<TvPadButton>? _padSub;
  StreamSubscription<TvStickDir>? _stickSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final version = await WebviewController.getWebViewVersion();
      if (version == null) {
        if (mounted) {
          setState(() => _error =
              'WebView2 Runtime не найден. Открой сайт в настоящем Edge.');
        }
        return;
      }
      final c = WebviewController();
      await c.initialize();
      await c.setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 Edg/124.0.0.0',
      );
      _subs.add(c.title.listen((t) {
        if (mounted) setState(() => _title = t);
      }));
      _subs.add(c.url.listen((u) {
        if (mounted) setState(() => _url = u);
      }));
      _subs.add(c.loadingState.listen((s) {
        if (mounted) setState(() => _loading = s == LoadingState.loading);
      }));
      // В 0.4.0 история приходит одним стримом historyChanged
      _subs.add(c.historyChanged.listen((h) {
        if (mounted) {
          setState(() {
            _canBack = h.canGoBack;
            _canFwd = h.canGoForward;
          });
        }
      }));
      _subs.add(c.containsFullScreenElementChanged.listen((v) {
        if (mounted) setState(() => _webFs = v);
      }));
      await c.loadUrl(widget.url);
      _padSub = GamepadService.instance.buttons.listen(_onPad);
      _stickSub = GamepadService.instance.stick.listen(_onStick);
      if (mounted) setState(() {
        _c = c;
        _ready = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Не удалось запустить встроенный браузер: $e');
      }
    }
  }

  void _onPad(TvPadButton b) {
    final c = _c;
    if (c == null) return;
    switch (b) {
      case TvPadButton.lb:
        c.goBack();
        break;
      case TvPadButton.rb:
        c.goForward();
        break;
      case TvPadButton.x:
        c.reload();
        break;
      default:
        break;
    }
  }

  void _onStick(TvStickDir d) {
    final c = _c;
    if (c == null) return;
    switch (d) {
      case TvStickDir.up:
        c.executeScript('window.scrollBy({top:-160,behavior:"smooth"})');
        break;
      case TvStickDir.down:
        c.executeScript('window.scrollBy({top:160,behavior:"smooth"})');
        break;
      case TvStickDir.left:
        c.executeScript('window.scrollBy({left:-160,behavior:"smooth"})');
        break;
      case TvStickDir.right:
        c.executeScript('window.scrollBy({left:160,behavior:"smooth"})');
        break;
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _padSub?.cancel();
    _stickSub?.cancel();
    if (OskService.instance.onChar != null) OskService.instance.hide();
    _c?.dispose();
    super.dispose();
  }

  // ---------- JS-инъекция текста в поле сайта ----------

  void _oskForWeb() {
    OskService.instance.show(
      onChar: (ch) => _c?.executeScript(_jsInsert(ch)),
      onBackspace: () => _c?.executeScript(_jsBackspace()),
      onEnter: () => _c?.executeScript(_jsEnter()),
    );
  }

  String _jsInsert(String ch) {
    final lit = jsonEncode(ch);
    return '''
(function(){
  var el = document.activeElement;
  if (!el) return;
  var ch = $lit;
  if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') {
    var proto = el.tagName === 'TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
    var setter = Object.getOwnPropertyDescriptor(proto, 'value').set;
    var s = el.selectionStart == null ? el.value.length : el.selectionStart;
    var e = el.selectionEnd == null ? el.value.length : el.selectionEnd;
    setter.call(el, el.value.slice(0, s) + ch + el.value.slice(e));
    el.selectionStart = el.selectionEnd = s + ch.length;
    el.dispatchEvent(new Event('input', { bubbles: true }));
  } else if (el.isContentEditable) {
    document.execCommand('insertText', false, ch);
  }
})();
''';
  }

  String _jsBackspace() {
    return '''
(function(){
  var el = document.activeElement;
  if (!el) return;
  if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') {
    var proto = el.tagName === 'TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
    var setter = Object.getOwnPropertyDescriptor(proto, 'value').set;
    var s = el.selectionStart == null ? el.value.length : el.selectionStart;
    var e = el.selectionEnd == null ? el.value.length : el.selectionEnd;
    if (s === e && s > 0) s -= 1;
    setter.call(el, el.value.slice(0, s) + el.value.slice(e));
    el.selectionStart = el.selectionEnd = s;
    el.dispatchEvent(new Event('input', { bubbles: true }));
  } else if (el.isContentEditable) {
    document.execCommand('delete', false);
  }
})();
''';
  }

  String _jsEnter() {
    return '''
(function(){
  var el = document.activeElement;
  if (!el) return;
  ['keydown','keypress','keyup'].forEach(function(t){
    el.dispatchEvent(new KeyboardEvent(t, {key:'Enter', code:'Enter', keyCode:13, which:13, bubbles:true}));
  });
  if (el.form && el.tagName !== 'TEXTAREA') {
    if (el.form.requestSubmit) { el.form.requestSubmit(); } else { el.form.submit(); }
  }
})();
''';
  }

  Future<void> _openExternal() async {
    final err = await tiles.launch(TvTile(
      id: 'tmp',
      title: _title,
      target: _url,
      kind: TvTileKind.webExternal,
    ));
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: TvColors.cardHi,
          content: Text(err, style: TvText.body),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (!_webFs) _topBar(),
          if (_loading && _ready)
            const LinearProgressIndicator(
              minHeight: 3,
              color: TvColors.accent,
              backgroundColor: TvColors.card,
            ),
          Expanded(
            child: _error != null
                ? _errorView()
                : _ready
                    ? Webview(_c!)
                    : const Center(
                        child: CircularProgressIndicator(color: TvColors.accent),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Container(
      color: TvColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          TvIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Назад (LB)',
            color: _canBack ? TvColors.text : TvColors.textFaint,
            onTap: () {
              if (_canBack) _c?.goBack();
            },
          ),
          const SizedBox(width: 8),
          TvIconButton(
            icon: Icons.arrow_forward_rounded,
            tooltip: 'Вперёд (RB)',
            color: _canFwd ? TvColors.text : TvColors.textFaint,
            onTap: () {
              if (_canFwd) _c?.goForward();
            },
          ),
          const SizedBox(width: 8),
          TvIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Обновить (X)',
            onTap: () => _c?.reload(),
          ),
          const SizedBox(width: 8),
          TvIconButton(
            icon: Icons.home_rounded,
            tooltip: 'Домой (B)',
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TvText.body.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  _url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TvText.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          TvIconButton(
            icon: Icons.keyboard_rounded,
            tooltip: 'Экранная клавиатура (Y)',
            onTap: _oskForWeb,
          ),
          const SizedBox(width: 8),
          TvIconButton(
            icon: Icons.open_in_new_rounded,
            tooltip: 'Открыть в настоящем Edge',
            onTap: _openExternal,
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: TvColors.danger),
            const SizedBox(height: 16),
            Text(_error!, style: TvText.bodyDim, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            TvDialogButton(
              label: 'Открыть в настоящем Edge',
              primary: true,
              onTap: _openExternal,
            ),
            const SizedBox(height: 12),
            TvDialogButton(
              label: 'Назад',
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
