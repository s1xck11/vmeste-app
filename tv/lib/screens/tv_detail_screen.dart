// tv/lib/screens/tv_detail_screen.dart
//
// Полные списки по клику на виджет: задачи, покупки, смены, бюджет.
// Только просмотр.

import 'package:flutter/material.dart';

import '../main.dart' show sync;
import '../models/budget_category.dart';
import '../models/shift.dart';
import '../models/transaction.dart';
import '../services/budget_service.dart';
import '../theme/tv_theme.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/tv_widget_cards.dart';
import '../models/purchase_list.dart';

enum TvDetailType { tasks, purchases, shifts, budget }

class TvDetailScreen extends StatelessWidget {
  final TvDetailType type;

  const TvDetailScreen({super.key, required this.type});

  String get _title => switch (type) {
        TvDetailType.tasks => 'Задачи',
        TvDetailType.purchases => 'Покупки',
        TvDetailType.shifts => 'Смены',
        TvDetailType.budget => 'Бюджет',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(TvSpace.screenH, 20, TvSpace.screenH, 0),
        child: Column(
          children: [
            Row(
              children: [
                TvIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Назад (B)',
                  autofocus: true,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 16),
                Text(_title, style: TvText.rowTitle),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: AnimatedBuilder(
                animation: sync,
                builder: (_, __) => ListView(
                  children: switch (type) {
                    TvDetailType.tasks => _tasks(),
                    TvDetailType.purchases => _purchases(),
                    TvDetailType.shifts => _shifts(),
                    TvDetailType.budget => _budget(),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowBox(List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: TvDecor.card(radius: 14),
        child: Row(children: children),
      );

  // ---------- ЗАДАЧИ ----------

  List<Widget> _tasks() {
    final active = sync.tasks.where((t) => !t.done && !t.archived).toList()
      ..sort((a, b) {
        final p = prioWeight(a.priority).compareTo(prioWeight(b.priority));
        if (p != 0) return p;
        final ad = a.deadline.isEmpty ? '9999-99-99' : a.deadline;
        final bd = b.deadline.isEmpty ? '9999-99-99' : b.deadline;
        return ad.compareTo(bd);
      });
    final done = sync.tasks.where((t) => t.done && !t.archived).toList()
      ..sort((a, b) => (b.doneAt ?? 0).compareTo(a.doneAt ?? 0));
    final today = todayStr();

    Widget taskRow(t, {bool isDone = false}) {
      final overdue = !isDone && t.deadline.isNotEmpty && t.deadline.compareTo(today) < 0;
      return _rowBox([
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isDone ? TvColors.success : prioColor(t.priority),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.text,
                style: TvText.body.copyWith(
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  color: isDone ? TvColors.textDim : TvColors.text,
                ),
              ),
              if (t.comment.isNotEmpty)
                Text(t.comment, style: TvText.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(
                [
                  if (t.assignee == 'any') 'Для двоих' else partnerName(sync.partners, t.assignee),
                  if (t.deadline.isNotEmpty)
                    overdue ? 'просрочено: ${shortDate(t.deadline)}' : 'до ${shortDate(t.deadline)}',
                ].join(' • '),
                style: TvText.caption.copyWith(
                  color: overdue ? TvColors.danger : TvColors.textDim,
                ),
              ),
            ],
          ),
        ),
        if (isDone) const Icon(Icons.check_circle_rounded, color: TvColors.success, size: 26),
      ]);
    }

    return [
      if (active.isEmpty)
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Все задачи выполнены', style: TvText.bodyDim),
        ),
      for (final t in active) taskRow(t),
      if (done.isNotEmpty) ...[
        const SizedBox(height: 16),
        TvSectionTitle('Выполнено (${done.length})'),
        for (final t in done.take(30)) taskRow(t, isDone: true),
      ],
      const SizedBox(height: 32),
    ];
  }

  // ---------- ПОКУПКИ ----------

  List<Widget> _purchases() {
    final lists = [...sync.purchaseLists];
    lists.sort((a, b) => a.id == 'common' ? -1 : (b.id == 'common' ? 1 : a.name.compareTo(b.name)));
    if (lists.isEmpty) {
      lists.add(PurchaseList(id: 'common', name: 'Общий'));
    }
    final out = <Widget>[];
    for (final list in lists) {
      final items = sync.purchases.where((p) => p.listId == list.id).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      final active = items.where((p) => !p.done).toList();
      final done = items.where((p) => p.done).toList();
      if (items.isEmpty) continue;
      out.add(TvSectionTitle('${list.emoji} ${list.name} (${active.length})'));
      for (final p in active) {
        out.add(_rowBox([
          const Icon(Icons.circle_outlined, size: 22, color: TvColors.textDim),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.text, style: TvText.body),
                if (p.comment.isNotEmpty)
                  Text(p.comment, style: TvText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text('${fmtQty(p.qty)} ${p.unit}', style: TvText.caption),
          if (p.price > 0) ...[
            const SizedBox(width: 14),
            Text(fmtMoney(p.price * p.qty), style: TvText.caption.copyWith(color: TvColors.accent)),
          ],
        ]));
      }
      for (final p in done.take(20)) {
        out.add(_rowBox([
          const Icon(Icons.check_circle_rounded, size: 22, color: TvColors.success),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              p.text,
              style: TvText.body.copyWith(
                decoration: TextDecoration.lineThrough,
                color: TvColors.textDim,
              ),
            ),
          ),
          Text('${fmtQty(p.qty)} ${p.unit}', style: TvText.caption),
        ]));
      }
      out.add(const SizedBox(height: 16));
    }
    if (out.isEmpty) {
      out.add(Padding(
        padding: const EdgeInsets.all(20),
        child: Text('Списки покупок пусты', style: TvText.bodyDim),
      ));
    }
    out.add(const SizedBox(height: 32));
    return out;
  }

  // ---------- СМЕНЫ ----------

  double _shiftIncome(Shift s) {
    if (s.components.isNotEmpty) {
      return s.components.fold<double>(
          0, (sum, c) => sum + (c.mode == 'hourly' ? c.hours * c.rate : c.amount));
    }
    if (s.income != null) return s.income!;
    if (s.pieceworkAmount != null) return s.pieceworkAmount!;
    double rate = findShiftType(sync.shiftTypes, s.type)?.rate ?? 0;
    if (rate <= 0) {
      for (final p in sync.partners) {
        if (p.id == s.partner) rate = p.rate;
      }
    }
    return s.hours * rate;
  }

  List<Widget> _shifts() {
    final today = todayStr();
    final now = DateTime.now();
    final monthPrefix = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final monthShifts = sync.shifts.where((s) => s.date.startsWith(monthPrefix)).toList();

    double hoursOf(String partner) => monthShifts
        .where((s) => s.partner == partner)
        .fold<double>(0, (sum, s) => sum + s.hours);
    double incomeOf(String partner) => monthShifts
        .where((s) => s.partner == partner)
        .fold<double>(0, (sum, s) => sum + _shiftIncome(s));

    final upcoming = sync.shifts.where((s) => s.date.compareTo(today) >= 0).toList()
      ..sort((a, b) {
        final d = a.date.compareTo(b.date);
        return d != 0 ? d : a.startTime.compareTo(b.startTime);
      });

    final out = <Widget>[
      Row(
        children: [
          for (final pid in ['partner1', 'partner2'])
            Expanded(
              child: Container(
                margin: EdgeInsets.only(right: pid == 'partner1' ? 12 : 0),
                padding: const EdgeInsets.all(18),
                decoration: TvDecor.card(radius: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(partnerName(sync.partners, pid), style: TvText.cardTitle),
                    const SizedBox(height: 6),
                    Text('${fmtQty(hoursOf(pid))} ч за месяц', style: TvText.bodyDim),
                    Text('≈ ${fmtMoney(incomeOf(pid))}',
                        style: TvText.caption.copyWith(color: TvColors.success)),
                  ],
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 24),
    ];

    String? lastDate;
    for (final s in upcoming.take(60)) {
      if (s.date != lastDate) {
        lastDate = s.date;
        final d = DateTime.tryParse(s.date);
        final label = s.date == today
            ? 'Сегодня'
            : (d != null && d.difference(now).inDays == 1
                ? 'Завтра'
                : d != null
                    ? '${tvWeekdaysShort[d.weekday - 1]}, ${shortDate(s.date)}'
                    : s.date);
        out.add(TvSectionTitle(label));
      }
      final type = findShiftType(sync.shiftTypes, s.type);
      out.add(_rowBox([
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: partnerColor(s.partner).withOpacity(0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            partnerName(sync.partners, s.partner),
            style: TvText.caption.copyWith(color: partnerColor(s.partner)),
          ),
        ),
        const SizedBox(width: 14),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: hexColor(type?.color ?? '#9E9E9E', TvColors.textDim),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(type?.label ?? 'Смена', style: TvText.body),
              if (s.location != null && s.location!.isNotEmpty)
                Text(s.location!, style: TvText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        Text('${s.startTime}–${s.endTime}', style: TvText.body),
        const SizedBox(width: 14),
        Text('${fmtQty(s.hours)} ч', style: TvText.caption),
      ]));
    }
    if (upcoming.isEmpty) {
      out.add(Padding(
        padding: const EdgeInsets.all(20),
        child: Text('Предстоящих смен нет', style: TvText.bodyDim),
      ));
    }
    out.add(const SizedBox(height: 32));
    return out;
  }

  // ---------- БЮДЖЕТ ----------

  List<Widget> _budget() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final tx = sync.transactions
        .where((t) => !t.date.isBefore(start) && !t.date.isAfter(end))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final expense = BudgetService.getTotalAmount(sync.transactions, type: 'expense', start: start, end: end);
    final income = BudgetService.getTotalAmount(sync.transactions, type: 'income', start: start, end: end);

    BudgetCategory? cat(String id) {
      for (final c in sync.budgetCategories) {
        if (c.id == id) return c;
      }
      return null;
    }

    final byCat = <String, double>{};
    for (final t in tx) {
      if (t.type != 'expense') continue;
      byCat[t.categoryId] = (byCat[t.categoryId] ?? 0) + t.amount;
    }
    final entries = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxCat = entries.isEmpty ? 1.0 : entries.first.value;

    final out = <Widget>[
      Row(
        children: [
          _summaryCard('Доходы', fmtMoney(income), TvColors.success),
          const SizedBox(width: 12),
          _summaryCard('Расходы', fmtMoney(expense), TvColors.text),
          const SizedBox(width: 12),
          _summaryCard('Остаток', fmtMoney(income - expense),
              income - expense >= 0 ? TvColors.accent : TvColors.danger),
        ],
      ),
      const SizedBox(height: 24),
      if (entries.isNotEmpty) ...[
        const TvSectionTitle('Категории'),
        for (final e in entries.take(8))
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: TvDecor.card(radius: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(cat(e.key)?.emoji ?? '📦', style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(cat(e.key)?.name ?? 'Другое', style: TvText.body)),
                    Text(fmtMoney(e.value), style: TvText.body.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (e.value / maxCat).clamp(0.0, 1.0),
                    minHeight: 8,
                    color: cat(e.key)?.color ?? TvColors.textDim,
                    backgroundColor: TvColors.cardHi,
                  ),
                ),
                if ((cat(e.key)?.monthlyLimit ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      e.value > cat(e.key)!.monthlyLimit
                          ? 'Лимит ${fmtMoney(cat(e.key)!.monthlyLimit)} превышен'
                          : 'Лимит ${fmtMoney(cat(e.key)!.monthlyLimit)}',
                      style: TvText.caption.copyWith(
                        color: e.value > cat(e.key)!.monthlyLimit
                            ? TvColors.danger
                            : TvColors.textDim,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 16),
      ],
      const TvSectionTitle('Операции'),
      for (final t in tx.take(100)) _txRow(t, cat),
      if (tx.isEmpty)
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text('В этом месяце операций нет', style: TvText.bodyDim),
        ),
      const SizedBox(height: 32),
    ];
    return out;
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: TvDecor.card(radius: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TvText.caption),
            const SizedBox(height: 6),
            Text(value,
                style: TvText.heroNumber.copyWith(fontSize: 30, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _txRow(Transaction t, BudgetCategory? Function(String) cat) {
    final isIncome = t.type == 'income';
    final isTransfer = t.type == 'transfer';
    final c = cat(t.categoryId);
    return _rowBox([
      Text(isTransfer ? '🔄' : (c?.emoji ?? '📦'), style: const TextStyle(fontSize: 24)),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isTransfer ? 'Перевод' : (c?.name ?? 'Другое'), style: TvText.body),
            if (t.comment.isNotEmpty)
              Text(t.comment, style: TvText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      Text('${t.date.day} ${tvMonths[t.date.month - 1]}', style: TvText.caption),
      const SizedBox(width: 16),
      Text(
        '${isIncome ? '＋' : isTransfer ? '' : '−'}${fmtMoney(t.amount)}',
        style: TvText.body.copyWith(
          fontWeight: FontWeight.w600,
          color: isIncome
              ? TvColors.success
              : isTransfer
                  ? TvColors.textDim
                  : TvColors.text,
        ),
      ),
    ]);
  }
}
