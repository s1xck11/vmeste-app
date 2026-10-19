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
import 'recurring_payments_screen.dart'; // НОВОЕ

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
                  if (_tab == 'banks_stats') _buildBanksStats(cs), // НОВОЕ
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddExpenseModal,
        icon: const Icon(Icons.add),
        label: const Text('Расход'),
      ),
    );
  }

  Widget _buildTotalBalanceCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [cs.primary, cs.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Общий баланс', style: TextStyle(fontSize: 14, color: cs.onPrimary.withOpacity(0.85))),
              const Spacer(),
              GestureDetector(
                onTap: _openBanksEditor,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: cs.onPrimary.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.tune, size: 14, color: cs.onPrimary),
                    const SizedBox(width: 4),
                    Text('Банки', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onPrimary)),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${_totalBanksBalance.toStringAsFixed(0)} ₽',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: cs.onPrimary)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Доходы: ${_incomes.toStringAsFixed(0)} ₽', style: TextStyle(fontSize: 13, color: cs.onPrimary.withOpacity(0.85))),
              Text('Расходы: ${_expenses.toStringAsFixed(0)} ₽', style: TextStyle(fontSize: 13, color: cs.onPrimary.withOpacity(0.85))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBanksList(ColorScheme cs) {
    if (_banks.isEmpty) return const SizedBox.shrink();
    
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _banks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final b = _banks[i];
          final balance = _bankBalance(b.id);
          return Container(
            width: 150,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(b.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(b.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                Text('${balance.toStringAsFixed(0)} ₽', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: balance >= 0 ? cs.primary : cs.error)),
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
      ('banks_stats', 'Банки'), // НОВОЕ
      ('categories', 'Категории'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: cs.surfaceVariant, borderRadius: BorderRadius.circular(14)),
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
              decoration: BoxDecoration(color: cs.surfaceVariant, borderRadius: BorderRadius.circular(12), border: Border.all(color: cs.outline)),
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
            decoration: BoxDecoration(color: cs.surfaceVariant, borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.outline)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(b.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Text(b.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
                    const Spacer(),
                    Text('${_bankBalance(b.id).toStringAsFixed(0)} ₽', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cs.primary)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statChip('Доход', income, cs.tertiary, cs),
                    _statChip('Расход', expense, cs.error, cs),
                    _statChip('Перевод +', inTransfer, cs.secondary, cs),
                    _statChip('Перевод −', outTransfer, cs.warning, cs),
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
        Text('${amount.toStringAsFixed(0)} ₽', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _buildOverview(ColorScheme cs) {
    final health = _health();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Финансовое здоровье', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cs.surfaceVariant, borderRadius: BorderRadius.circular(18), border: Border.all(color: cs.outline)),
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
        Text('Расходы по категориям', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
        const SizedBox(height: 8),
        if (_breakdown().isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: Text('Нет расходов за этот месяц', style: TextStyle(color: cs.onSurfaceVariant))),
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
              decoration: BoxDecoration(color: cs.surfaceVariant, borderRadius: BorderRadius.circular(14), border: Border.all(color: cs.outline)),
              child: Row(
                children: [
                  Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cat.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(value: percent / 100, minHeight: 4, backgroundColor: cs.surface, color: cs.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${e.value.toStringAsFixed(0)} ₽', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.onSurface)),
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
            child: LinearProgressIndicator(value: percent / 100, minHeight: 8, backgroundColor: cs.surface, color: color),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 45, child: Text('${percent.toStringAsFixed(0)}%', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
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
        final isIncome = t.type == 'income';
        final isTransfer = t.type == 'transfer';
        
        final bank = t.bankId != null ? _banks.firstWhere((b) => b.id == t.bankId, orElse: () => Bank(id: t.bankId!, name: 'Банк')) : null;
        final toBank = t.toBankId != null ? _banks.firstWhere((b) => b.id == t.toBankId, orElse: () => Bank(id: t.toBankId!, name: 'Банк')) : null;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openEditModal(t),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: cs.surfaceVariant, borderRadius: BorderRadius.circular(14), border: Border.all(color: cs.outline)),
                child: Row(
                  children: [
                    Text(isTransfer ? '🔄' : cat.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isTransfer ? 'Перевод: ${bank?.name} → ${toBank?.name}' : (t.comment.isEmpty ? cat.name : t.comment),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${t.date.day}.${t.date.month}.${t.date.year}${!isTransfer && bank != null ? " · ${bank.name}" : ""}',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isExpense ? '−' : (isIncome ? '+' : '')}${t.amount.toStringAsFixed(0)} ₽',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isExpense ? cs.error : (isIncome ? cs.tertiary : cs.onSurfaceVariant)),
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
    final incomes = _categories.where((c) => c.type == 'income' && c.id.startsWith('income_')).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Расходы', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        ...expenses.map((c) => _categoryTile(c, cs)),
        const SizedBox(height: 16),
        Text('Доходы', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        ...incomes.map((c) => _categoryTile(c, cs)),
      ],
    );
  }

  Widget _categoryTile(BudgetCategory c, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: cs.surfaceVariant, borderRadius: BorderRadius.circular(12), border: Border.all(color: cs.outline)),
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