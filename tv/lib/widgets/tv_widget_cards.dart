// tv/lib/widgets/tv_widget_cards.dart
//
// 4 виджета «Сегодня»: задачи, покупки, смены, бюджет.
// Превью-логика как в мобильном widget_service, бюджет — BudgetService из main.

import 'package:flutter/material.dart';

import '../main.dart' show sync;
import '../models/budget_category.dart';
import '../models/partner.dart';
import '../models/shift_type.dart';
import '../services/budget_service.dart';
import '../theme/tv_theme.dart';
import 'tv_focusable.dart';

// ---------- общие helpers (используются и в детальном экране) ----------

const List<String> tvMonths = [
  'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
  'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
];
const List<String> tvMonthsNom = [
  'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
  'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
];
const List<String> tvWeekdays = [
  'понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье',
];
const List<String> tvWeekdaysShort = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];

String todayStr() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

String shortDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  return '${d.day} ${tvMonths[d.month - 1]}';
}

String fmtMoney(double v) {
  final s = v.round().abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return '${v < 0 ? '−' : ''}$buf ₽';
}

String fmtQty(double q) =>
    q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);

int prioWeight(String p) => p == 'high' ? 0 : p == 'med' ? 1 : 2;

Color prioColor(String p) => p == 'high'
    ? TvColors.prioHigh
    : p == 'med'
        ? TvColors.prioMed
        : TvColors.prioLow;

String partnerName(List<Partner> partners, String id) {
  for (final p in partners) {
    if (p.id == id) return p.name;
  }
  return id == 'partner1' ? 'Партнёр 1' : 'Партнёр 2';
}

Color partnerColor(String id) =>
    id == 'partner1' ? TvColors.info : TvColors.accent;

ShiftType? findShiftType(List<ShiftType> types, String id) {
  for (final t in types) {
    if (t.id == id) return t;
  }
  return null;
}

Color hexColor(String hex, Color fallback) {
  try {
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  } catch (_) {
    return fallback;
  }
}

// ---------- оболочка карточки ----------

class _CardShell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String badge;
  final List<Widget> children;
  final VoidCallback onTap;
  final bool autofocus;

  const _CardShell({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.badge,
    required this.children,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onTap: onTap,
      autofocus: autofocus,
      scale: 1.02,
      radius: TvSpace.cardRadius,
      child: Container(
        width: 380,
        height: 250,
        padding: const EdgeInsets.all(20),
        decoration: TvDecor.card(radius: TvSpace.cardRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 26),
                const SizedBox(width: 10),
                Text(title, style: TvText.cardTitle),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: TvColors.cardHi,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(badge, style: TvText.caption),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _empty(String text) => Text(text, style: TvText.bodyDim);

// ---------- ЗАДАЧИ ----------

class TasksCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool autofocus;

  const TasksCard({super.key, required this.onTap, this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sync,
      builder: (_, __) {
        final active = sync.tasks.where((t) => !t.done && !t.archived).toList();
        active.sort((a, b) {
          final p = prioWeight(a.priority).compareTo(prioWeight(b.priority));
          if (p != 0) return p;
          final ad = a.deadline.isEmpty ? '9999-99-99' : a.deadline;
          final bd = b.deadline.isEmpty ? '9999-99-99' : b.deadline;
          return ad.compareTo(bd);
        });
        final today = todayStr();
        return _CardShell(
          icon: Icons.check_circle_outline_rounded,
          iconColor: TvColors.info,
          title: 'Задачи',
          badge: '${active.length}',
          onTap: onTap,
          autofocus: autofocus,
          children: active.isEmpty
              ? [_empty('Все задачи выполнены')]
              : [
                  for (final t in active.take(4))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: prioColor(t.priority),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              t.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TvText.body,
                            ),
                          ),
                          if (t.deadline.isNotEmpty)
                            Text(
                              t.deadline.compareTo(today) < 0
                                  ? 'просрочено'
                                  : shortDate(t.deadline),
                              style: TvText.caption.copyWith(
                                color: t.deadline.compareTo(today) < 0
                                    ? TvColors.danger
                                    : TvColors.textDim,
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (active.length > 4)
                    Text('ещё ${active.length - 4}…', style: TvText.caption),
                ],
        );
      },
    );
  }
}

// ---------- ПОКУПКИ ----------

class PurchasesCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool autofocus;

  const PurchasesCard({super.key, required this.onTap, this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sync,
      builder: (_, __) {
        final items = sync.purchases
            .where((p) => p.listId == 'common' && !p.done)
            .toList();
        items.sort((a, b) => a.order.compareTo(b.order));
        final sum = items.fold<double>(0, (s, p) => s + p.price * p.qty);
        return _CardShell(
          icon: Icons.shopping_cart_outlined,
          iconColor: TvColors.success,
          title: 'Покупки',
          badge: '${items.length}',
          onTap: onTap,
          autofocus: autofocus,
          children: items.isEmpty
              ? [_empty('Список покупок пуст')]
              : [
                  for (final p in items.take(4))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.circle_outlined, size: 16, color: TvColors.textDim),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              p.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TvText.body,
                            ),
                          ),
                          Text('${fmtQty(p.qty)} ${p.unit}', style: TvText.caption),
                        ],
                      ),
                    ),
                  if (sum > 0)
                    Text('≈ ${fmtMoney(sum)}',
                        style: TvText.caption.copyWith(color: TvColors.accent)),
                ],
        );
      },
    );
  }
}

// ---------- СМЕНЫ ----------

class ShiftsCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool autofocus;

  const ShiftsCard({super.key, required this.onTap, this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sync,
      builder: (_, __) {
        final today = todayStr();
        final todays = sync.shifts.where((s) => s.date == today).toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
        final upcoming = sync.shifts.where((s) => s.date.compareTo(today) > 0).toList()
          ..sort((a, b) {
            final d = a.date.compareTo(b.date);
            return d != 0 ? d : a.startTime.compareTo(b.startTime);
          });

        Widget shiftRow(s) {
          final type = findShiftType(sync.shiftTypes, s.type);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: hexColor(type?.color ?? '#9E9E9E', TvColors.textDim),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    partnerName(sync.partners, s.partner),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TvText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(type?.label ?? 'Смена', style: TvText.caption),
                const SizedBox(width: 10),
                Text('${s.startTime}–${s.endTime}', style: TvText.caption),
              ],
            ),
          );
        }

        return _CardShell(
          icon: Icons.work_outline_rounded,
          iconColor: TvColors.warning,
          title: 'Смены',
          badge: todays.isNotEmpty ? 'сегодня ${todays.length}' : 'нет смен',
          onTap: onTap,
          autofocus: autofocus,
          children: todays.isNotEmpty
              ? [for (final s in todays.take(3)) shiftRow(s)]
              : upcoming.isNotEmpty
                  ? [
                      Text('Ближайшая смена', style: TvText.caption),
                      const SizedBox(height: 8),
                      Text(shortDate(upcoming.first.date), style: TvText.body),
                      const SizedBox(height: 8),
                      shiftRow(upcoming.first),
                    ]
                  : [_empty('Смен пока нет')],
        );
      },
    );
  }
}

// ---------- БЮДЖЕТ ----------

class BudgetCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool autofocus;

  const BudgetCard({super.key, required this.onTap, this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sync,
      builder: (_, __) {
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        final expense = BudgetService.getTotalAmount(sync.transactions,
            type: 'expense', start: start, end: end);
        final income = BudgetService.getTotalAmount(sync.transactions,
            type: 'income', start: start, end: end);

        final byCat = <String, double>{};
        for (final t in sync.transactions) {
          if (t.type != 'expense') continue;
          if (t.date.isBefore(start) || t.date.isAfter(end)) continue;
          byCat[t.categoryId] = (byCat[t.categoryId] ?? 0) + t.amount;
        }
        final entries = byCat.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        BudgetCategory? cat(String id) {
          for (final c in sync.budgetCategories) {
            if (c.id == id) return c;
          }
          return null;
        }

        return _CardShell(
          icon: Icons.account_balance_wallet_outlined,
          iconColor: TvColors.accent,
          title: 'Бюджет',
          badge: tvMonthsNom[now.month - 1],
          onTap: onTap,
          autofocus: autofocus,
          children: [
            Text('Расходы', style: TvText.caption),
            Text(fmtMoney(expense),
                style: TvText.heroNumber.copyWith(fontSize: 38)),
            const SizedBox(height: 4),
            Text('＋ ${fmtMoney(income)} доходы',
                style: TvText.caption.copyWith(color: TvColors.success)),
            const SizedBox(height: 8),
            for (final e in entries.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: cat(e.key)?.color ?? TvColors.textDim,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        cat(e.key)?.name ?? 'Другое',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TvText.caption,
                      ),
                    ),
                    Text(fmtMoney(e.value), style: TvText.caption),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
