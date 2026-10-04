// lib/services/budget_service.dart

import '../models/transaction.dart';
import '../models/budget_category.dart';

class BudgetService {
  // --- РАСЧЁТЫ ЗА ПЕРИОД ---

  /// Возвращает сумму всех транзакций указанного типа за период
  static double getTotalAmount(
    List<Transaction> transactions, {
    required String type, // 'expense' или 'income'
    DateTime? start,
    DateTime? end,
  }) {
    return transactions.where((t) {
      if (t.type != type) return false;
      if (start != null && t.date.isBefore(start)) return false;
      if (end != null && t.date.isAfter(end)) return false;
      return true;
    }).fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Возвращает разбивку по категориям для графика (Пирог)
  static Map<String, double> getCategoryBreakdown(
    List<Transaction> transactions,
    List<BudgetCategory> categories, {
    required String type,
    DateTime? start,
    DateTime? end,
  }) {
    final Map<String, double> breakdown = {};
    
    final filtered = transactions.where((t) {
      if (t.type != type) return false;
      if (start != null && t.date.isBefore(start)) return false;
      if (end != null && t.date.isAfter(end)) return false;
      return true;
    });

    for (var t in filtered) {
      final catName = categories
          .firstWhere((c) => c.id == t.categoryId, 
              orElse: () => BudgetCategory(id: 'unknown', name: 'Другое', type: type))
          .name;
      breakdown[catName] = (breakdown[catName] ?? 0.0) + t.amount;
    }

    return breakdown;
  }

  // --- ФИНАНСОВОЕ ЗДОРОВЬЕ (в стиле Revius) ---

  /// Возвращает проценты: [обязательные, осознанные, импульсивные]
  static Map<String, double> getFinancialHealth(
    List<Transaction> transactions, {
    DateTime? start,
    DateTime? end,
  }) {
    final expenses = transactions.where((t) {
      if (t.type != 'expense') return false;
      if (start != null && t.date.isBefore(start)) return false;
      if (end != null && t.date.isAfter(end)) return false;
      return true;
    }).toList();

    if (expenses.isEmpty) {
      return {'obligatory': 0.0, 'conscious': 0.0, 'impulsive': 0.0};
    }

    double obligatory = 0;
    double conscious = 0;
    double impulsive = 0;

    for (var t in expenses) {
      switch (t.nature) {
        case 'obligatory':
          obligatory += t.amount;
          break;
        case 'impulsive':
          impulsive += t.amount;
          break;
        case 'conscious':
        default:
          conscious += t.amount;
          break;
      }
    }

    final total = obligatory + conscious + impulsive;
    if (total == 0) return {'obligatory': 0.0, 'conscious': 0.0, 'impulsive': 0.0};

    return {
      'obligatory': (obligatory / total) * 100,
      'conscious': (conscious / total) * 100,
      'impulsive': (impulsive / total) * 100,
    };
  }

  // --- ИНСАЙТЫ ---

  /// Простой инсайт: сравнение трат с прошлым месяцем
  static String? getInsight(
    List<Transaction> transactions, {
    required DateTime currentMonth,
  }) {
    final currentStart = DateTime(currentMonth.year, currentMonth.month, 1);
    final currentEnd = DateTime(currentMonth.year, currentMonth.month + 1, 0);
    
    final prevMonth = DateTime(currentMonth.year, currentMonth.month - 1, 1);
    final prevStart = DateTime(prevMonth.year, prevMonth.month, 1);
    final prevEnd = DateTime(prevMonth.year, prevMonth.month + 1, 0);

    final currentExpense = getTotalAmount(transactions, type: 'expense', start: currentStart, end: currentEnd);
    final prevExpense = getTotalAmount(transactions, type: 'expense', start: prevStart, end: prevEnd);

    if (prevExpense == 0) return null; // Не с чем сравнивать

    final diff = ((currentExpense - prevExpense) / prevExpense) * 100;

    if (diff > 10) {
      return '📈 Расходы выросли на ${diff.toStringAsFixed(0)}% по сравнению с прошлым месяцем.';
    } else if (diff < -10) {
      return '📉 Ты молодец! Расходы упали на ${diff.abs().toStringAsFixed(0)}%.';
    } else {
      return '⚖️ Расходы стабильны. Так держать!';
    }
  }
}