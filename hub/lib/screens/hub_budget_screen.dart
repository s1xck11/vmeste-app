import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/transaction.dart';
import '../models/budget_category.dart';
import '../models/partner.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../widgets/glass_container.dart';

class HubBudgetScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;

  const HubBudgetScreen({
    super.key,
    required this.storage,
    required this.sync,
  });

  @override
  State<HubBudgetScreen> createState() => _HubBudgetScreenState();
}

class _HubBudgetScreenState extends State<HubBudgetScreen> {
  DateTime _currentMonth = DateTime.now();
  String _tab = 'overview';
  List<Transaction> _transactions = [];
  List<BudgetCategory> _categories = [];

  @override
  void initState() {
    super.initState();
    _load();
    widget.sync.addListener(_load);
  }

  @override
  void dispose() {
    widget.sync.removeListener(_load);
    super.dispose();
  }

  void _load() {
    if (!mounted) return;
    setState(() {
      _transactions = widget.storage.transactions;
      _categories = widget.storage.budgetCategories;
    });
  }

  void _changeMonth(int delta) {
    HapticFeedback.lightImpact();
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta, 1);
    });
  }

  void _changeTab(String tab) {
    HapticFeedback.lightImpact();
    setState(() => _tab = tab);
  }

  String _monthName(int m) {
    const names = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
    return names[m - 1];
  }

  List<Transaction> get _monthTransactions {
    final start = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final end = DateTime(_currentMonth.year, _currentMonth.month + 1, 0, 23, 59);
    return _transactions.where((t) =>
        t.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
        t.date.isBefore(end.add(const Duration(seconds: 1)))).toList();
  }

  double _monthSalaryFromShifts() {
    final partners = widget.storage.partners;
    final prefix = '${_currentMonth.year}-${_currentMonth.month < 10 ? '0${_currentMonth.month}' : _currentMonth.month}';
    double total = 0;
    for (final s in widget.storage.shifts) {
      if (!s.date.startsWith(prefix)) continue;
      if (s.importedFrom == 'courier-helper' && s.income != null) {
        total += s.income!.toDouble();
        continue;
      }
      final p = partners.firstWhere(
        (x) => x.id == s.partner,
        orElse: () => Partner(id: s.partner, name: '', rate: 0, payType: 'hourly'),
      );
      if (p.payType == 'piecework') {
        total += (s.pieceworkAmount ?? 0).toDouble();
      } else if (p.payType == 'fixed') {
        total += p.rate.toDouble();
      } else {
        total += s.hours * p.rate;
      }
    }
    return total;
  }

  double get _manualIncomes => _monthTransactions.where((t) => t.type == 'income').fold(0.0, (s, t) => s + t.amount);
  double get _incomes => _manualIncomes + _monthSalaryFromShifts();
  double get _expenses => _monthTransactions.where((t) => t.type == 'expense').fold(0.0, (s, t) => s + t.amount);
  double get _balance => _incomes - _expenses;

  Map<String, double> _breakdown() {
    final map = <String, double>{};
    for (final t in _monthTransactions.where((t) => t.type == 'expense')) {
      map[t.categoryId] = (map[t.categoryId] ?? 0) + t.amount;
    }
    return map;
  }

  Map<String, double> _health() {
    double obligatory = 0, conscious = 0, impulsive = 0;
    for (final t in _monthTransactions.where((t) => t.type == 'expense')) {
      if (t.nature == 'obligatory') {
        obligatory += t.amount;
      } else if (t.nature == 'impulsive') {
        impulsive += t.amount;
      } else {
        conscious += t.amount;
      }
    }
    final total = obligatory + conscious + impulsive;
    if (total == 0) return {'obligatory': 0, 'conscious': 0, 'impulsive': 0};
    return {
      'obligatory': obligatory / total * 100,
      'conscious': conscious / total * 100,
      'impulsive': impulsive / total * 100,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart, color: cs.primary, size: 32),
              const SizedBox(width: 14),
              Text(
                'Бюджет',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                  letterSpacing: -1,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _changeMonth(-1),
                icon: Icon(Icons.chevron_left, color: cs.onSurface, size: 32),
              ),
              Text(
                '${_monthName(_currentMonth.month)} ${_currentMonth.year}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              IconButton(
                onPressed: () => _changeMonth(1),
                icon: Icon(Icons.chevron_right, color: cs.onSurface, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildBalanceCard(cs),
                      const SizedBox(height: 20),
                      _buildTabs(cs),
                      const SizedBox(height: 20),
                      Expanded(
                        child: SingleChildScrollView(
                          child: _tab == 'overview'
                              ? _buildOverview(cs)
                              : _tab == 'transactions'
                                  ? _buildTransactions(cs)
                                  : _buildCategories(cs),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 1,
                  child: _buildSummarySide(cs),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Баланс за месяц',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onPrimary.withOpacity(0.85)),
          ),
          const SizedBox(height: 8),
          Text(
            '${_balance.toStringAsFixed(0)} ₽',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: cs.onPrimary,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Доходы: ${_incomes.toStringAsFixed(0)} ₽',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onPrimary.withOpacity(0.85)),
              ),
              Text(
                'Расходы: ${_expenses.toStringAsFixed(0)} ₽',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onPrimary.withOpacity(0.85)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(ColorScheme cs) {
    final tabs = [
      ('overview', 'Обзор'),
      ('transactions', 'Транзакции'),
      ('categories', 'Категории'),
    ];
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(0.5)),
      ),
      child: Row(
        children: tabs.map((t) {
          final sel = t.$1 == _tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => _changeTab(t.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: sel ? cs.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: sel ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ] : null,
                ),
                child: Center(
                  child: Text(
                    t.$2,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                      color: sel ? cs.onSurface : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOverview(ColorScheme cs) {
    final health = _health();
    final salaryFromShifts = _monthSalaryFromShifts();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (salaryFromShifts > 0) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cs.primary.withOpacity(0.5), width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.work_outline, color: cs.onPrimaryContainer, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Зарплата из смен за месяц',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer.withOpacity(0.8)),
                      ),
                      Text(
                        '${salaryFromShifts.toStringAsFixed(0)} ₽',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        Text(
          'Финансовое здоровье',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cs.onSurface, letterSpacing: -0.5),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cs.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cs.outline),
          ),
          child: Column(
            children: [
              _healthBar('Обязательные', health['obligatory'] ?? 0, cs.error, cs),
              const SizedBox(height: 16),
              _healthBar('Осознанные', health['conscious'] ?? 0, cs.secondary, cs),
              const SizedBox(height: 16),
              _healthBar('Импульсивные', health['impulsive'] ?? 0, cs.tertiary, cs),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Расходы по категориям',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cs.onSurface, letterSpacing: -0.5),
        ),
        const SizedBox(height: 16),
        if (_breakdown().isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text('Нет расходов за этот месяц', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            ),
          )
        else
          ...(_breakdown().entries.map((e) {
            final cat = _categories.firstWhere(
              (c) => c.id == e.key,
              orElse: () => BudgetCategory(id: e.key, name: 'Другое', emoji: '📦', type: 'expense'),
            );
            final percent = _expenses > 0 ? e.value / _expenses * 100 : 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surface.withOpacity(0.6),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: cs.outline),
              ),
              child: Row(
                children: [
                  Text(cat.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(cat.name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: cs.onSurface)),
                            const Spacer(),
                            Text(
                              '${e.value.toStringAsFixed(0)} ₽',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: cs.onSurface),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent / 100,
                            minHeight: 8,
                            backgroundColor: cs.surfaceVariant,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          })),
      ],
    );
  }

  Widget _healthBar(String label, double percent, Color color, ColorScheme cs) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 12,
              backgroundColor: cs.surfaceVariant,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 55,
          child: Text(
            '${percent.toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactions(ColorScheme cs) {
    final list = List<Transaction>.from(_monthTransactions)..sort((a, b) => b.date.compareTo(a.date));
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text('Нет транзакций за этот месяц', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
        ),
      );
    }
    return Column(
      children: list.map((t) {
        final cat = _categories.firstWhere(
          (c) => c.id == t.categoryId,
          orElse: () => BudgetCategory(id: t.categoryId, name: 'Другое', emoji: '📦', type: t.type),
        );
        final isExpense = t.type == 'expense';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cs.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cs.outline),
          ),
          child: Row(
            children: [
              Text(cat.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.comment.isEmpty ? cat.name : t.comment,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: cs.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${t.date.day}.${t.date.month}.${t.date.year} · ${cat.name}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Text(
                '${isExpense ? '−' : '+'}${t.amount.toStringAsFixed(0)} ₽',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isExpense ? cs.error : cs.tertiary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategories(ColorScheme cs) {
    final expenses = _categories.where((c) => c.type == 'expense').toList();
    final incomes = _categories.where((c) => c.type == 'income').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Расходы', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        ...expenses.map((c) => _categoryTile(c, cs)),
        const SizedBox(height: 24),
        Text('Доходы', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        ...incomes.map((c) => _categoryTile(c, cs)),
      ],
    );
  }

  Widget _categoryTile(BudgetCategory c, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Text(c.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(c.name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: cs.onSurface)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySide(ColorScheme cs) {
    return GlassContainer(
      radius: 32,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Сводка',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          _summaryRow('Доходы', _incomes, cs.tertiary, cs),
          const SizedBox(height: 16),
          _summaryRow('Расходы', _expenses, cs.error, cs),
          const SizedBox(height: 16),
          Divider(color: cs.outline, thickness: 1.5),
          const SizedBox(height: 16),
          _summaryRow('Баланс', _balance, _balance >= 0 ? cs.tertiary : cs.error, cs),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, Color color, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        Text(
          '${value >= 0 ? '' : '−'}${value.abs().toStringAsFixed(0)} ₽',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}