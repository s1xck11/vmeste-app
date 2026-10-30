// lib/screens/budget_screen.dart

import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/budget_category.dart';
import '../models/bank.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/theme_service.dart';
import '../widgets/modern_app_bar.dart';
import '../widgets/add_transaction_modal.dart';
import '../widgets/add_income_modal.dart';
import '../widgets/add_transfer_modal.dart';
import 'banks_editor_screen.dart';
import 'recurring_payments_screen.dart';

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
  State<BudgetScreen> createState() => BudgetScreenState();
}

class BudgetScreenState extends State<BudgetScreen> {
  DateTime _currentMonth = DateTime.now();
  String _tab = 'overview';
  List<Transaction> _transactions = [];
  List<BudgetCategory> _categories = [];
  List<Bank> _banks = [];

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
      _banks = widget.storage.banks;
    });
  }

  Future<void> _refresh() async {
    await widget.sync.forcePullNow();
    _load();
  }

  List<Transaction> get _monthTransactions {
    final start = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final end = DateTime(_currentMonth.year, _currentMonth.month + 1, 0, 23, 59);
    return _transactions.where((t) =>
        t.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
        t.date.isBefore(end.add(const Duration(seconds: 1)))).toList();
  }

  double get _incomes => _monthTransactions
      .where((t) => t.type == 'income')
      .fold(0.0, (s, t) => s + t.amount);

  double get _expenses => _monthTransactions
      .where((t) => t.type == 'expense')
      .fold(0.0, (s, t) => s + t.amount);

  double get _totalBanksBalance {
    double total = 0;
    for (final b in _banks) {
      total += _bankBalance(b.id);
    }
    return total;
  }

  double _bankBalance(String bankId) {
    final b = _banks.firstWhere((x) => x.id == bankId, orElse: () => Bank(id: bankId, name: '?'));
    double balance = b.initialBalance;
    for (final t in _transactions) {
      if (t.type == 'income' && t.bankId == bankId) balance += t.amount;
      if (t.type == 'expense' && t.bankId == bankId) balance -= t.amount;
      if (t.type == 'transfer') {
        if (t.bankId == bankId) balance -= t.amount;
        if (t.toBankId == bankId) balance += t.amount;
      }
    }
    return balance;
  }

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

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta, 1);
    });
  }

  // ============ ПУБЛИЧНЫЕ МЕТОДЫ ДЛЯ FAB ============
  void openAddModal() => _openAddExpenseModal();
  void openAddIncomeModal() => _openAddIncomeModal();
  void openAddTransferModal() => _openAddTransferModal();

  void _openAddExpenseModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionModal(
        categories: _categories.where((c) => c.type == 'expense').toList(),
        banks: _banks,
        onSave: (t) {
          final list = List<Transaction>.from(_transactions)..add(t);
          widget.storage.transactions = list;
          _load();
          widget.sync.schedulePush();
        },
      ),
    );
  }

  void _openAddIncomeModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddIncomeModal(
        categories: _categories.where((c) => c.type == 'income').toList(),
        banks: _banks,
        onSave: (t) {
          final list = List<Transaction>.from(_transactions)..add(t);
          widget.storage.transactions = list;
          _load();
          widget.sync.schedulePush();
        },
      ),
    );
  }

  void _openAddTransferModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransferModal(
        banks: _banks,
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
      builder: (_) {
        if (t.type == 'income') {
          return AddIncomeModal(
            categories: _categories.where((c) => c.type == 'income').toList(),
            banks: _banks,
            initialTransaction: t,
            onSave: (updated) {
              final list = List<Transaction>.from(_transactions);
              final i = list.indexWhere((e) => e.id == updated.id);
              if (i >= 0) list[i] = updated;
              widget.storage.transactions = list;
              _load();
              widget.sync.schedulePush();
            },
          );
        } else if (t.type == 'transfer') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Редактирование перевода пока не поддерживается')));
          return const SizedBox.shrink();
        } else {
          return AddTransactionModal(
            categories: _categories.where((c) => c.type == 'expense').toList(),
            banks: _banks,
            initialTransaction: t,
            onSave: (updated) {
              final list = List<Transaction>.from(_transactions);
              final i = list.indexWhere((e) => e.id == updated.id);
              if (i >= 0) list[i] = updated;
              widget.storage.transactions = list;
              _load();
              widget.sync.schedulePush();
            },
          );
        }
      },
    );
  }

  void _openBanksEditor() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BanksEditorScreen(storage: widget.storage, sync: widget.sync),
    )).then((_) => _load());
  }

  void _openRecurring() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RecurringPaymentsScreen(storage: widget.storage, sync: widget.sync),
    )).then((_) => _load());
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
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          ModernAppBar(
            title: 'Кошелёк',
            onAvatarTap: widget.onAvatarTap,
            avatarEmoji: widget.storage.myAvatar,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                IconButton(onPressed: () => _changeMonth(-1), icon: Icon(Icons.chevron_left, color: cs.onSurface)),
                Expanded(
                  child: Text('${_monthName(_currentMonth.month)} ${_currentMonth.year}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface)),
                ),
                IconButton(onPressed: () => _changeMonth(1), icon: Icon(Icons.chevron_right, color: cs.onSurface)),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: cs.primary,
              backgroundColor: cs.surface,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                children: [
                  _buildTotalBalanceCard(cs),
                  const SizedBox(height: 16),
                  _buildBanksList(cs),
                  const SizedBox(height: 24),
                  _buildTabs(cs),
                  const SizedBox(height: 16),
                  if (_tab == 'overview') _buildOverview(cs),
                  if (_tab == 'transactions') _buildTransactions(cs),
                  if (_tab == 'categories') _buildCategories(cs),
                  if (_tab == 'banks_stats') _buildBanksStats(cs),
                ],
              ),
            ),
          ),
        ],
      ),
      // УБРАНА floatingActionButton - дублирует FAB в навбаре
    );
  }

  Widget _buildTotalBalanceCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Общий баланс', style: TextStyle(fontSize: 14, color: cs.onPrimary.withOpacity(0.9), fontWeight: FontWeight.w500)),
              const Spacer(),
              GestureDetector(
                onTap: _openBanksEditor,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.onPrimary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.onPrimary.withOpacity(0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 14, color: cs.onPrimary),
                    const SizedBox(width: 6),
                    Text('Банки', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onPrimary)),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('${_totalBanksBalance.toStringAsFixed(0)} ₽',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: cs.onPrimary,
                letterSpacing: -1,
              )),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniStat('Доходы', _incomes, cs.onPrimary),
              _miniStat('Расходы', _expenses, cs.onPrimary.withOpacity(0.85)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.85))),
        const SizedBox(height: 4),
        Text('${amount.toStringAsFixed(0)} ₽',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _buildBanksList(ColorScheme cs) {
    if (_banks.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _banks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final b = _banks[i];
          final balance = _bankBalance(b.id);
          return Container(
            width: 160,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.surfaceVariant,
                  cs.surfaceVariant.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outline.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(b.emoji, style: const TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(b.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Баланс', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text('${balance.toStringAsFixed(0)} ₽',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: balance >= 0 ? cs.primary : cs.error,
                        )),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabs(ColorScheme cs) {
    final tabs = [
      ('overview', 'Обзор'),
      ('transactions', 'Транзакции'),
      ('banks_stats', 'Банки'),
      ('categories', 'Категории'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withOpacity(0.5)),
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
                  boxShadow: sel ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                child: Center(
                  child: Text(t.$2, style: TextStyle(
                    fontSize: 12,
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

  Widget _buildBanksStats(ColorScheme cs) {
    if (_banks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: Text('Нет банков', style: TextStyle(color: cs.onSurfaceVariant))),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: GestureDetector(
            onTap: _openRecurring,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.repeat, size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Text('Регулярные платежи', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
                ],
              ),
            ),
          ),
        ),
        ..._banks.map((b) {
          final bankTx = _monthTransactions.where((t) => t.bankId == b.id || t.toBankId == b.id).toList();
          final income = bankTx.where((t) => t.type == 'income' && t.bankId == b.id).fold(0.0, (s, t) => s + t.amount);
          final expense = bankTx.where((t) => t.type == 'expense' && t.bankId == b.id).fold(0.0, (s, t) => s + t.amount);
          final inTransfer = bankTx.where((t) => t.type == 'transfer' && t.toBankId == b.id).fold(0.0, (s, t) => s + t.amount);
          final outTransfer = bankTx.where((t) => t.type == 'transfer' && t.bankId == b.id).fold(0.0, (s, t) => s + t.amount);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outline.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(b.emoji, style: const TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 12),
                    Text(b.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
                    const Spacer(),
                    Text('${_bankBalance(b.id).toStringAsFixed(0)} ₽',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cs.primary)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statChip('Доход', income, cs.tertiary, cs),
                    _statChip('Расход', expense, cs.error, cs),
                    _statChip('Перевод +', inTransfer, cs.secondary, cs),
                    _statChip('Перевод −', outTransfer, cs.tertiary, cs),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _statChip(String label, double amount, Color color, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text('${amount.toStringAsFixed(0)} ₽',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _buildOverview(ColorScheme cs) {
    final health = _health();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Финансовое здоровье',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cs.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outline.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _healthBar('Обязательные', health['obligatory'] ?? 0, cs.error, cs),
              const SizedBox(height: 14),
              _healthBar('Осознанные', health['conscious'] ?? 0, cs.secondary, cs),
              const SizedBox(height: 14),
              _healthBar('Импульсивные', health['impulsive'] ?? 0, cs.tertiary, cs),
            ],
          ),
        ),
        // === НОВОЕ: СЕКЦИЯ ЛИМИТОВ ===
        const SizedBox(height: 24),
        _buildLimitsSection(cs),
        // === КОНЕЦ НОВОГО БЛОКА ===
        const SizedBox(height: 24),
        Text('Расходы по категориям',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
        const SizedBox(height: 8),
        if (_breakdown().isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: cs.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outline.withOpacity(0.5)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.pie_chart_outline, size: 48, color: cs.onSurfaceVariant.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  Text('Нет расходов за этот месяц',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
                ],
              ),
            ),
          )
        else
          ...(_breakdown().entries.map((e) {
            final cat = _categories.firstWhere(
              (c) => c.id == e.key,
              orElse: () =>
                  BudgetCategory(id: e.key, name: 'Другое', emoji: '📦', type: 'expense'),
            );
            final percent = _expenses > 0 ? e.value / _expenses * 100 : 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outline.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(cat.name,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface)),
                            Text('${e.value.toStringAsFixed(0)} ₽',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent / 100,
                            minHeight: 6,
                            backgroundColor: cs.surface,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('${percent.toStringAsFixed(0)}% от расходов',
                            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
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
          width: 120,
          child: Text(label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 10,
              backgroundColor: cs.surface,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 50,
          child: Text('${percent.toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ),
      ],
    );
  }

  Widget _buildTransactions(ColorScheme cs) {
    final list = List<Transaction>.from(_monthTransactions)..sort((a, b) => b.date.compareTo(a.date));
    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: cs.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline.withOpacity(0.5)),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined, size: 48, color: cs.onSurfaceVariant.withOpacity(0.5)),
              const SizedBox(height: 12),
              Text('Нет транзакций за этот месяц',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
            ],
          ),
        ),
      );
    }
    return Column(
      children: list.map((t) {
        final cat = _categories.firstWhere(
          (c) => c.id == t.categoryId,
          orElse: () =>
              BudgetCategory(id: t.categoryId, name: 'Другое', emoji: '📦', type: t.type),
        );
        final isExpense = t.type == 'expense';
        final isIncome = t.type == 'income';
        final isTransfer = t.type == 'transfer';

        final bank = t.bankId != null
            ? _banks.firstWhere((b) => b.id == t.bankId,
                orElse: () => Bank(id: t.bankId!, name: 'Банк'))
            : null;
        final toBank = t.toBankId != null
            ? _banks.firstWhere((b) => b.id == t.toBankId,
                orElse: () => Bank(id: t.toBankId!, name: 'Банк'))
            : null;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openEditModal(t),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outline.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isTransfer
                            ? cs.secondary.withOpacity(0.1)
                            : (isIncome ? cs.tertiary.withOpacity(0.1) : cs.primary.withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(isTransfer ? '🔄' : cat.emoji,
                          style: const TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isTransfer
                                ? 'Перевод: ${bank?.name} → ${toBank?.name}'
                                : (t.comment.isEmpty ? cat.name : t.comment),
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${t.date.day}.${t.date.month}.${t.date.year}${!isTransfer && bank != null ? " · ${bank.name}" : ""}',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isExpense ? '−' : (isIncome ? '+' : '')}${t.amount.toStringAsFixed(0)} ₽',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isExpense
                            ? cs.error
                            : (isIncome ? cs.tertiary : cs.onSurfaceVariant),
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

  // ============ ЛИМИТЫ ============

  Map<String, double> get _spentByCategory => _breakdown();

  List<BudgetCategory> get _categoriesWithLimits =>
      _categories.where((c) => c.type == 'expense' && c.monthlyLimit > 0).toList();

  Widget _buildLimitsSection(ColorScheme cs) {
    final limits = _categoriesWithLimits;
    final spent = _spentByCategory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Лимиты',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
            const Spacer(),
            GestureDetector(
              onTap: _addLimitModal,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: cs.primary),
                    const SizedBox(width: 4),
                    Text('Добавить',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (limits.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outline.withOpacity(0.5)),
            ),
            child: Column(
              children: [
                Icon(Icons.flag_outlined, size: 36, color: cs.onSurfaceVariant.withOpacity(0.5)),
                const SizedBox(height: 8),
                Text('Лимитов пока нет',
                    style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text('Установите лимиты на категории,\nчтобы контролировать расходы',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withOpacity(0.7))),
              ],
            ),
          )
        else
          ...limits.map((cat) {
            final spentAmount = spent[cat.id] ?? 0;
            final percent = spentAmount / cat.monthlyLimit;
            final isOver = percent > 1.0;
            final isWarning = percent >= 0.7 && percent <= 1.0;

            Color barColor;
            if (isOver) {
              barColor = cs.error;
            } else if (isWarning) {
              barColor = const Color(0xFFFFA726); // оранжевый
            } else {
              barColor = const Color(0xFF4CAF50); // зелёный
            }

            return GestureDetector(
              onTap: () => _editLimitModal(cat),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isOver ? cs.error.withOpacity(0.5) : cs.outline.withOpacity(0.5),
                    width: isOver ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(cat.emoji, style: const TextStyle(fontSize: 18)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(cat.name,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.onSurface)),
                        ),
                        if (isOver)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: cs.error.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning_amber_rounded, size: 12, color: cs.error),
                                const SizedBox(width: 4),
                                Text('Превышен',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.error)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: cs.surface,
                        color: barColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${spentAmount.toStringAsFixed(0)} ₽',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: barColor)),
                        Text('${cat.monthlyLimit.toStringAsFixed(0)} ₽',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  void _editLimitModal(BudgetCategory cat) {
    final controller = TextEditingController(text: cat.monthlyLimit.toStringAsFixed(0));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: cs.outline.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(cat.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Text('Лимит: ${cat.name}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: 'Сумма в месяц',
                    hintText: 'Например, 15000',
                    suffixText: '₽',
                    suffixStyle: TextStyle(fontSize: 16, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: cs.surfaceVariant,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          final updated = cat.copyWith(monthlyLimit: 0, updatedAt: DateTime.now().millisecondsSinceEpoch);
                          _saveCategory(updated);
                          Navigator.pop(ctx);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: cs.error,
                        ),
                        child: const Text('Убрать лимит'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          final val = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
                          if (val <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Введите сумму больше 0')),
                            );
                            return;
                          }
                          final updated = cat.copyWith(monthlyLimit: val, updatedAt: DateTime.now().millisecondsSinceEpoch);
                          _saveCategory(updated);
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Сохранить'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _addLimitModal() {
    final categoriesWithoutLimit = _categories
        .where((c) => c.type == 'expense' && c.monthlyLimit == 0)
        .toList();

    if (categoriesWithoutLimit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('У всех категорий уже есть лимиты')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: cs.outline.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Выберите категорию для лимита',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface)),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: categoriesWithoutLimit.map((cat) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(cat.emoji, style: const TextStyle(fontSize: 18)),
                      ),
                      title: Text(cat.name,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _editLimitModal(cat);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _saveCategory(BudgetCategory updated) {
    final list = List<BudgetCategory>.from(_categories);
    final i = list.indexWhere((e) => e.id == updated.id);
    if (i >= 0) list[i] = updated;
    widget.storage.budgetCategories = list;
    _load();
    widget.sync.schedulePush();
  }

  Widget _buildCategories(ColorScheme cs) {
    final expenses = _categories.where((c) => c.type == 'expense').toList();
    final incomes =
        _categories.where((c) => c.type == 'income' && c.id.startsWith('income_')).toList();

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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.type == 'income' ? cs.tertiary.withOpacity(0.1) : cs.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(c.emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(c.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface))),
        ],
      ),
    );
  }
}
