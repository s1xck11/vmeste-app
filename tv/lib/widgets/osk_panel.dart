// tv/lib/widgets/osk_panel.dart
//
// Экранная клавиатура RU/EN + символы + MODE (сайт / Windows).
// Водится мышью и геймпадом (крестовина + A).

import 'package:flutter/material.dart';

import '../services/osk_service.dart';
import '../theme/tv_theme.dart';
import 'tv_focusable.dart';

const _digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
const _ru1 = ['й', 'ц', 'у', 'к', 'е', 'н', 'г', 'ш', 'щ', 'з', 'х', 'ъ'];
const _ru2 = ['ф', 'ы', 'в', 'а', 'п', 'р', 'о', 'л', 'д', 'ж', 'э', 'ё'];
const _ru3 = ['я', 'ч', 'с', 'м', 'и', 'т', 'ь', 'б', 'ю'];
const _en1 = ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'];
const _en2 = ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'];
const _en3 = ['z', 'x', 'c', 'v', 'b', 'n', 'm'];
const _sym1 = ['@', '#', '₽', '%', '&', '*', '(', ')', '-', '+'];
const _sym2 = ['=', '!', '?', ':', ';', ',', '.', '/', '_', '\\'];
const _sym3 = ['"', "'", '<', '>', '[', ']', '{', '}'];

class OskOverlay extends StatelessWidget {
  const OskOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final osk = OskService.instance;
    return AnimatedBuilder(
      animation: osk,
      builder: (_, __) {
        if (!osk.visible) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.bottomCenter,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            builder: (_, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(0, 24 * (1 - v)),
                child: child,
              ),
            ),
            child: const OskPanel(),
          ),
        );
      },
    );
  }
}

class OskPanel extends StatelessWidget {
  const OskPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final osk = OskService.instance;
    return AnimatedBuilder(
      animation: osk,
      builder: (_, __) {
        final row1 = osk.symbols ? _sym1 : (osk.ru ? _ru1 : _en1);
        final row2 = osk.symbols ? _sym2 : (osk.ru ? _ru2 : _en2);
        final row3 = osk.symbols ? _sym3 : (osk.ru ? _ru3 : _en3);
        return Container(
          margin: const EdgeInsets.fromLTRB(TvSpace.screenH, 0, TvSpace.screenH, 20),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: TvColors.outline),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.7), blurRadius: 40)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _row([for (final d in _digits) _key(d, autofocus: d == '1')]),
              _row([for (final k in row1) _key(k, label: osk.shift && !osk.symbols ? k.toUpperCase() : k)]),
              _row([for (final k in row2) _key(k, label: osk.shift && !osk.symbols ? k.toUpperCase() : k)]),
              _row([
                _key('shift', icon: Icons.keyboard_capslock_rounded, w: 84, active: osk.shift),
                for (final k in row3) _key(k, label: osk.shift && !osk.symbols ? k.toUpperCase() : k),
                _key('back', icon: Icons.backspace_rounded, w: 84),
              ]),
              _row([
                _key('lang', label: osk.ru ? 'РУС' : 'ENG', w: 88),
                _key('page', label: osk.symbols ? 'АБВ' : '?123', w: 88),
                _key('mode', label: osk.systemMode ? 'WIN' : 'САЙТ', w: 88, active: osk.systemMode),
                _key('space', label: 'пробел', w: null),
                _key('enter', icon: Icons.keyboard_return_rounded, w: 88),
                _key('hide', icon: Icons.keyboard_hide_rounded, w: 68),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _row(List<Widget> children) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }

  Widget _key(
    String id, {
    String? label,
    IconData? icon,
    double? w = 58,
    bool active = false,
    bool autofocus = false,
  }) {
    final key = Padding(
      padding: const EdgeInsets.all(3),
      child: TvFocusable(
        onTap: () => OskService.instance.press(id),
        autofocus: autofocus,
        scale: 1.08,
        radius: 10,
        child: Container(
          width: w,
          height: 52,
          decoration: BoxDecoration(
            color: active ? TvColors.accent.withOpacity(0.25) : TvColors.cardHi,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? TvColors.accent : TvColors.outline,
            ),
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, size: 24, color: active ? TvColors.accent : TvColors.text)
                : Text(
                    label ?? id,
                    style: TvText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ),
    );
    return w == null ? Expanded(child: key) : key;
  }
}
