// lib/screens/budget_screen.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:uuid/uuid.dart';

import '../models/transaction.dart';
import '../models/budget_category.dart';
import '../services/budget_service.dart';
import '../widgets/add_transaction_modal.dart';

class BudgetScreen extends StatefulWidget {
  // Временные данные. Позже мы подключим их к StorageService и SyncService.
  final List<Transaction> transactions;
  final List<BudgetCategory> categories;
  final Function(Transaction) onAddTransaction;
  final Function(Transaction) onUpdateTransaction;
  final Function(String) onDeleteTransaction;
  final Function(BudgetCategory) onAddCategory;

  const BudgetScreen({
    super.key,
    required this.transactions,
    required this.categories,
    required this.onAddTransaction,
    required this.onUpdateTransaction,
    required this.onDeleteTransaction,
    required this.onAddCategory,
  });

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _currentMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- ЛОГИКА ОТОБРАЖЕНИЯ ---

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + offset, 1);
    });
  }

  void _openAddTransactionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddTransactionModal(
        categories: widget.categories,
        onSave: (t) {
          if (t.id.isEmpty || !widget.transactions.any((e) => e.id == t.id)) {
            widget.onAddTransaction(t);
          } else {
            widget.onUpdateTransaction(t);
          }
        },
      ),
    );
  }

  // --- ВКЛАДКА 1: ОБЗОР ---

  Widget _buildOverviewTab() {
    final startOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final endOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

    final expenses = BudgetService.getTotalAmount(
      widget.transactions,
      type: 'expense',
      start: startOfMonth,
      end: endOfMonth,
    );
    final incomes = BudgetService.getTotalAmount(
      widget.transactions,
      type: 'income',
      start: startOfMonth,
      end: endOfMonth,
    );

    final health = BudgetService.getFinancialHealth(
      widget.transactions,
      start: startOfMonth,
      end: endOfMonth,
    );

    final insight = BudgetService.getInsight(
      widget.transactions,
      currentMonth: _currentMonth,
    );

    final breakdown = BudgetService.getCategoryBreakdown(
      widget.transactions,
      widget.categories,
      type: 'expense',
      start: startOfMonth,
      end: endOfMonth,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Карточка баланса
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8FAB), Color(0xFF5856D6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Баланс за месяц', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                '${(incomes - expenses).toStringAsFixed(0)} ₽',
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Доходы: ${incomes.toStringAsFixed(0)} ₽', style: const TextStyle(color: Colors.white70)),
                  Text('Расходы: ${expenses.toStringAsFixed(0)} ₽', style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Финансовое здоровье
        const Text('Финансовое здоровье', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Column(
            children: [
              _buildHealthBar('Обязательные', health['obligatory'] ?? 0, Colors.red),
              const SizedBox(height: 8),
              _buildHealthBar('Осознанные', health['conscious'] ?? 0, Colors.orange),
              const SizedBox(height: 8),
              _buildHealthBar('Импульсивные', health['impulsive'] ?? 0, Colors.green),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Инсайт
        if (insight != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE5EC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb, color: Color(0xFFFF8FAB)),
                const SizedBox(width: 12),
                Expanded(child: Text(insight, style: const TextStyle(fontSize: 14))),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // График (Пирог)
        const Text('Расходы по категориям', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (breakdown.isEmpty)
          const Center(child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Text('Нет расходов за этот месяц', style: TextStyle(color: Colors.grey)),
          ))
        else
          Container(
            height: 250,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: breakdown.entries.map((e) {
                  final cat = widget.categories.firstWhere(
                    (c) => c.name == e.key,
                    orElse: () => BudgetCategory(id: 'other', name: e.key, type: 'expense', colorValue: 0xFF9E9E9E),
                  );
                  return PieChartSectionData(
                    color: cat.color,
                    value: e.value,
                    title: '${((e.value / breakdown.values.fold(0.0, (a, b) => a + b)) * 100).toStringAsFixed(0)}%',
                    radius: 60,
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  );
                }).toList(),
              ),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildHealthBar(String label, double percent, Color color) {
    return Row(
      children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              backgroundColor: Colors.grey[200],
              color: color,
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 40, child: Text('${percent.toStringAsFixed(0)}%', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
      ],
    );
  }

  // --- ВКЛАДКА 2: ТРАНЗАКЦИИ ---

  Widget _buildTransactionsTab() {
    final startOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final endOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    
    final monthTransactions = widget.transactions.where((t) {
      return t.date.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) && 
             t.date.isBefore(endOfMonth.add(const Duration(seconds: 1)));
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (monthTransactions.isEmpty) {
      return const Center(child: Text('Нет транзакций за этот месяц', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: monthTransactions.length,
      itemBuilder: (ctx, i) {
        final t = monthTransactions[i];
        final cat = widget.categories.firstWhere(
          (c) => c.id == t.categoryId, 
          orElse: () => BudgetCategory(id: 'other', name: 'Другое', type: t.type)
        );
        final isExpense = t.type == 'expense';
        
        return Dismissible(
          key: Key(t.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => widget.onDeleteTransaction(t.id),
          child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: cat.color.withOpacity(0.2),
                child: Text(cat.emoji, style: const TextStyle(fontSize: 18)),
              ),
              title: Text(t.comment.isEmpty ? cat.name : t.comment),
              subtitle: Text('${t.date.day}.${t.date.month}.${t.date.year} • ${cat.name}'),
              trailing: Text(
                '${isExpense ? '-' : '+'}${t.amount.toStringAsFixed(0)} ₽',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isExpense ? Colors.red : Colors.green,
                ),
              ),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => AddTransactionModal(
                    categories: widget.categories,
                    initialTransaction: t,
                    onSave: (updated) => widget.onUpdateTransaction(updated),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // --- ВКЛАДКА 3: КАТЕГОРИИ ---

  Widget _buildCategoriesTab() {
    final expenseCats = widget.categories.where((c) => c.type == 'expense').toList();
    final incomeCats = widget.categories.where((c) => c.type == 'income').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Категории', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Color(0xFFFF8FAB)),
              onPressed: () => _showAddCategoryDialog(),
            ),
          ],
        ),
        const Divider(),
        const Text('Расходы', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
        const SizedBox(height: 8),
        ...expenseCats.map((c) => ListTile(
          leading: CircleAvatar(backgroundColor: c.color.withOpacity(0.2), child: Text(c.emoji)),
          title: Text(c.name),
          trailing: const Icon(Icons.edit, size: 18, color: Colors.grey),
          onTap: () => _showAddCategoryDialog(category: c),
        )),
        const SizedBox(height: 16),
        const Text('Доходы', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
        const SizedBox(height: 8),
        ...incomeCats.map((c) => ListTile(
          leading: CircleAvatar(backgroundColor: c.color.withOpacity(0.2), child: Text(c.emoji)),
          title: Text(c.name),
          trailing: const Icon(Icons.edit, size: 18, color: Colors.grey),
          onTap: () => _showAddCategoryDialog(category: c),
        )),
      ],
    );
  }

  void _showAddCategoryDialog({BudgetCategory? category}) {
    final nameCtrl = TextEditingController(text: category?.name ?? '');
    final emojiCtrl = TextEditingController(text: category?.emoji ?? '📦');
    String type = category?.type ?? 'expense';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(category == null ? 'Новая категория' : 'Редактировать'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Название')),
              const SizedBox(height: 8),
              TextField(controller: emojiCtrl, decoration: const InputDecoration(labelText: 'Эмодзи')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(value: 'expense', child: Text('Расход')),
                  DropdownMenuItem(value: 'income', child: Text('Доход')),
                ],
                onChanged: (v) => setDialogState(() => type = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                final newCat = BudgetCategory(
                  id: category?.id ?? const Uuid().v4(),
                  name: nameCtrl.text.trim(),
                  emoji: emojiCtrl.text.trim(),
                  type: type,
                  colorValue: category?.colorValue ?? _randomColor(),
                  createdAt: category?.createdAt ?? DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                widget.onAddCategory(newCat);
                Navigator.pop(ctx);
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  int _randomColor() {
    final colors = [0xFFFF8FAB, 0xFF5856D6, 0xFF34C759, 0xFFFF9500, 0xFFFF3B30, 0xFF00C7BE];
    return colors[DateTime.now().millisecond % colors.length];
  }

  // --- СБОРКА ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Бюджет'),
        backgroundColor: const Color(0xFFFF8FAB),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeMonth(-1),
          ),
          Center(
            child: Text(
              '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeMonth(1),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Обзор', icon: Icon(Icons.pie_chart, size: 18)),
            Tab(text: 'Транзакции', icon: Icon(Icons.list, size: 18)),
            Tab(text: 'Категории', icon: Icon(Icons.category, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildTransactionsTab(),
          _buildCategoriesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTransactionModal,
        backgroundColor: const Color(0xFFFF8FAB),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
    return months[month - 1];
  }
}