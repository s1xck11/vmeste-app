// lib/screens/budget_screen.dart

import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/budget_category.dart';
import '../models/partner.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/theme_service.dart';
import '../widgets/modern_app_bar.dart';
import '../widgets/add_transaction_modal.dart';

class BudgetScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;
  final ThemeService themeService;
  final VoidCallback onAvatarTap;

  const BudgetScreen({
    super.key,
    required this.storage,
    required this.sync,
    required this.themeService,
    required this.onAvatarTap,
  });

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  DateTime _currentMonth = DateTime.now();
  String _tab = 'overview';

  List<Transaction> _transactions = [];
  List<BudgetCategory> _categories = [];

  @override
  void initState() {
    super.initState();
    _load();
    widget.sync.onDataChanged = _load;
  }

  @override
  void dispose() {
    widget.sync.onDataChanged = null;
    super.dispose();
  }

  void _load() {
    if (!mounted) return;
    setState(() {
      _transactions = widget.storage.transactions;
      _categories = widget.storage.budgetCategories;
    });
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

  double get _manualIncomes => _monthTransactions
      .where((t) => t.type == 'income')
      .fold(0.0, (s, t) => s + t.amount);

  double get _incomes => _manualIncomes + _monthSalaryFromShifts();

  double get _expenses => _monthTransactions
      .where((t) => t.type == 'expense')
      .fold(0.0, (s, t) => s + t.amount);

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
      if (t.nature == 'obligatory') obligatory += t.amount;
      else if (t.nature == 'impulsive') impulsive += t.amount;
      else conscious += t.amount;
    }
    final total = obligatory + conscious + impulsive;
    if (total == 0) return {'obligatory': 0, 'conscious': 0, 'impulsive': 0};
    return {
      'obligatory': obligatory / total * 100,
      'conscious': conscious / total * 100,
      'impulsive': impulsive / total * 100,
    };
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta, 1);
    });
  }

  void _openAddModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionModal(
        categories: _categories,
        onSave: (t) {
          final list = List<Transaction>.from(_transactions)..add(t);
          widget.storage.transactions = list;
          _load();
          widget.sync.schedulePush();
        },
      ),
    );
  }

  void _openEditModal(Transaction t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionModal(
        categories: _categories,
        initialTransaction: t,
        onSave: (updated) {
          final list = List<Transaction>.from(_transactions);
          final i = list.indexWhere((e) => e.id == updated.id);
          if (i >= 0) list[i] = updated;
          widget.storage.transactions = list;
          _load();
          widget.sync.schedulePush();
        },
      ),
    );
  }

  String _monthName(int m) {
    const names = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
    return names[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.background,
      body: Column(
        children: [
          ModernAppBar(
            title: 'Бюджет',
            onAvatarTap: widget.onAvatarTap,
            avatarEmoji: widget.storage.myAvatar,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _changeMonth(-1),
                  icon: Icon(Icons.chevron_left, color: cs.onSurface),
                ),
                Expanded(
                  child: Text(
                    '${_monthName(_currentMonth.month)} ${_currentMonth.year}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface),
                  ),
                ),
                IconButton(
                  onPressed: () => _changeMonth(1),
                  icon: Icon(Icons.chevron_right, color: cs.onSurface),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              children: [
                _buildBalanceCard(cs),
                const SizedBox(height: 16),
                _buildTabs(cs),
                const SizedBox(height: 16),
                if (_tab == 'overview') _buildOverview(cs),
                if (_tab == 'transactions') _buildTransactions(cs),
                if (_tab == 'categories') _buildCategories(cs),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddModal,
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
    );
  }

  Widget _buildBalanceCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Баланс за месяц', style: TextStyle(fontSize: 14, color: cs.onPrimary.withOpacity(0.85))),
          const SizedBox(height: 6),
          Text('${_balance.toStringAsFixed(0)} ₽',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: cs.onPrimary)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Доходы: ${_incomes.toStringAsFixed(0)} ₽',
                  style: TextStyle(fontSize: 13, color: cs.onPrimary.withOpacity(0.85))),
              Text('Расходы: ${_expenses.toStringAsFixed(0)} ₽',
                  style: TextStyle(fontSize: 13, color: cs.onPrimary.withOpacity(0.85))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(ColorScheme cs) {
    final tabs = [('overview', 'Обзор'), ('transactions', 'Транзакции'), ('categories', 'Категории')];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: tabs.map((t) {
          final sel = t.$1 == _tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = t.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? cs.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(t.$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? cs.onSurface : cs.onSurfaceVariant,
                      )),
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.primary),
            ),
            child: Row(
              children: [
                Icon(Icons.work_outline, color: cs.onPrimaryContainer, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Зарплата из смен за месяц',
                          style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer.withOpacity(0.8))),
                      Text('${salaryFromShifts.toStringAsFixed(0)} ₽',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onPrimaryContainer)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text('Финансовое здоровье',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceVariant,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outline),
          ),
          child: Column(
            children: [
              _healthBar('Обязательные', health['obligatory'] ?? 0, cs.error, cs),
              const SizedBox(height: 10),
              _healthBar('Осознанные', health['conscious'] ?? 0, cs.secondary, cs),
              const SizedBox(height: 10),
              _healthBar('Импульсивные', health['impulsive'] ?? 0, cs.tertiary, cs),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Расходы по категориям',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
        const SizedBox(height: 8),
        if (_breakdown().isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text('Нет расходов за этот месяц',
                  style: TextStyle(color: cs.onSurfaceVariant)),
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
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outline),
              ),
              child: Row(
                children: [
                  Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cat.name,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: percent / 100,
                            minHeight: 4,
                            backgroundColor: cs.surface,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${e.value.toStringAsFixed(0)} ₽',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.onSurface)),
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
        SizedBox(width: 110, child: Text(label, style: TextStyle(fontSize: 13, color: cs.onSurface))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 8,
              backgroundColor: cs.surface,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 45,
          child: Text('${percent.toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ),
      ],
    );
  }

  Widget _buildTransactions(ColorScheme cs) {
    final list = List<Transaction>.from(_monthTransactions)..sort((a, b) => b.date.compareTo(a.date));
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: Text('Нет транзакций за этот месяц', style: TextStyle(color: cs.onSurfaceVariant))),
      );
    }
    return Column(
      children: list.map((t) {
        final cat = _categories.firstWhere(
          (c) => c.id == t.categoryId,
          orElse: () => BudgetCategory(id: t.categoryId, name: 'Другое', emoji: '📦', type: t.type),
        );
        final isExpense = t.type == 'expense';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openEditModal(t),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.outline),
                ),
                child: Row(
                  children: [
                    Text(cat.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.comment.isEmpty ? cat.name : t.comment,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
                          const SizedBox(height: 2),
                          Text('${t.date.day}.${t.date.month}.${t.date.year} · ${cat.name}',
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Text(
                      '${isExpense ? '−' : '+'}${t.amount.toStringAsFixed(0)} ₽',
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: isExpense ? cs.error : cs.tertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
        Text('Расходы',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        ...expenses.map((c) => _categoryTile(c, cs)),
        const SizedBox(height: 16),
        Text('Доходы',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        ...incomes.map((c) => _categoryTile(c, cs)),
      ],
    );
  }

  Widget _categoryTile(BudgetCategory c, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Text(c.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(c.name, style: TextStyle(fontSize: 14, color: cs.onSurface))),
        ],
      ),
    );
  }
}