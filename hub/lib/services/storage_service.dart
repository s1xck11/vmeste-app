// lib/services/storage_service.dart

import 'package:hive_flutter/hive_flutter.dart';
import '../models/purchase.dart';
import '../models/purchase_list.dart';
import '../models/purchase_category.dart';
import '../models/task.dart';
import '../models/task_category.dart';
import '../models/shift.dart';
import '../models/shift_type.dart';
import '../models/partner.dart';
import '../models/transaction.dart';
import '../models/budget_category.dart';

class StorageService {
  static const String _boxName = 'vmeste_hub_data';
  late Box _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  // ============ ГРУППА ============
  String? get coupleCode => _box.get('coupleCode') as String?;
  set coupleCode(String? v) => _box.put('coupleCode', v);

  String? get currentUserId => _box.get('currentUserId') as String?;
  set currentUserId(String? v) => _box.put('currentUserId', v);

  String? get myKey => _box.get('myKey') as String?;
  set myKey(String? v) => _box.put('myKey', v);

  String? get myPartnerId => _box.get('myPartnerId') as String?;
  set myPartnerId(String? v) => _box.put('myPartnerId', v);

  String get myName => _box.get('myName') as String? ?? '';
  set myName(String v) => _box.put('myName', v);

  String get myAvatar => _box.get('myAvatar') as String? ?? '🏠';
  set myAvatar(String v) => _box.put('myAvatar', v);

  String get partnerName => _box.get('partnerName') as String? ?? 'Партнёр';
  set partnerName(String v) => _box.put('partnerName', v);

  List<String> get members {
    final raw = _box.get('members');
    if (raw == null) return [];
    return (raw as List).cast<String>();
  }
  set members(List<String> m) => _box.put('members', m);

  int get serverVersion => _box.get('serverVersion') as int? ?? 0;
  set serverVersion(int v) => _box.put('serverVersion', v);

  // ============ ПОКУПКИ ============
  List<Purchase> get purchases {
    final raw = _box.get('purchases');
    if (raw == null) return [];
    try {
      final list = (raw as List).cast<Map>();
      return list.map((e) => Purchase.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      return [];
    }
  }
  set purchases(List<Purchase> items) => _box.put('purchases', items.map((e) => e.toJson()).toList());

  List<PurchaseList> get purchaseLists {
    final raw = _box.get('purchaseLists');
    if (raw == null) return PurchaseList.defaults();
    try {
      final list = (raw as List).cast<Map>();
      final result = list.map((e) => PurchaseList.fromJson(Map<String, dynamic>.from(e))).toList();
      return result.isEmpty ? PurchaseList.defaults() : result;
    } catch (e) {
      return PurchaseList.defaults();
    }
  }
  set purchaseLists(List<PurchaseList> lists) => _box.put('purchaseLists', lists.map((e) => e.toJson()).toList());

  List<PurchaseCategory> get purchaseCategories {
    final raw = _box.get('purchaseCategories');
    if (raw == null) return PurchaseCategory.defaults();
    try {
      final list = (raw as List).cast<Map>();
      final result = list.map((e) => PurchaseCategory.fromJson(Map<String, dynamic>.from(e))).toList();
      return result.isEmpty ? PurchaseCategory.defaults() : result;
    } catch (e) {
      return PurchaseCategory.defaults();
    }
  }
  set purchaseCategories(List<PurchaseCategory> cats) => _box.put('purchaseCategories', cats.map((e) => e.toJson()).toList());

  // ============ ЗАДАЧИ ============
  List<Task> get tasks {
    final raw = _box.get('tasks');
    if (raw == null) return [];
    try {
      final list = (raw as List).cast<Map>();
      return list.map((e) => Task.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      return [];
    }
  }
  set tasks(List<Task> items) => _box.put('tasks', items.map((e) => e.toJson()).toList());

  List<TaskCategory> get taskCategories {
    final raw = _box.get('taskCategories');
    if (raw == null) return TaskCategory.defaults();
    try {
      final list = (raw as List).cast<Map>();
      final result = list.map((e) => TaskCategory.fromJson(Map<String, dynamic>.from(e))).toList();
      return result.isEmpty ? TaskCategory.defaults() : result;
    } catch (e) {
      return TaskCategory.defaults();
    }
  }
  set taskCategories(List<TaskCategory> cats) => _box.put('taskCategories', cats.map((e) => e.toJson()).toList());

  // ============ СМЕНЫ ============
  List<Shift> get shifts {
    final raw = _box.get('shifts');
    if (raw == null) return [];
    try {
      final list = (raw as List).cast<Map>();
      return list.map((e) => Shift.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      return [];
    }
  }
  set shifts(List<Shift> items) => _box.put('shifts', items.map((e) => e.toJson()).toList());

  List<ShiftType> get shiftTypes {
    final raw = _box.get('shiftTypes');
    if (raw == null) return ShiftType.defaults();
    try {
      final list = (raw as List).cast<Map>();
      final result = list.map((e) => ShiftType.fromJson(Map<String, dynamic>.from(e))).toList();
      return result.isEmpty ? ShiftType.defaults() : result;
    } catch (e) {
      return ShiftType.defaults();
    }
  }
  set shiftTypes(List<ShiftType> types) => _box.put('shiftTypes', types.map((e) => e.toJson()).toList());

  List<Partner> get partners {
    final raw = _box.get('partners');
    if (raw == null) return Partner.defaults();
    try {
      final list = (raw as List).cast<Map>();
      final result = list.map((e) => Partner.fromJson(Map<String, dynamic>.from(e))).toList();
      return result.isEmpty ? Partner.defaults() : result;
    } catch (e) {
      return Partner.defaults();
    }
  }
  set partners(List<Partner> p) => _box.put('partners', p.map((e) => e.toJson()).toList());

  // ============ ТРАНЗАКЦИИ ============
  List<Transaction> get transactions {
    final raw = _box.get('transactions');
    if (raw == null) return [];
    try {
      final list = (raw as List).cast<Map>();
      return list.map((e) => Transaction.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      return [];
    }
  }
  set transactions(List<Transaction> items) => _box.put('transactions', items.map((e) => e.toJson()).toList());

  // ============ КАТЕГОРИИ БЮДЖЕТА ============
  List<BudgetCategory> get budgetCategories {
    final raw = _box.get('budgetCategories');
    if (raw == null) return _defaultBudgetCategories();
    try {
      final list = (raw as List).cast<Map>();
      final result = list.map((e) => BudgetCategory.fromJson(Map<String, dynamic>.from(e))).toList();
      return result.isEmpty ? _defaultBudgetCategories() : result;
    } catch (e) {
      return _defaultBudgetCategories();
    }
  }
  set budgetCategories(List<BudgetCategory> cats) => _box.put('budgetCategories', cats.map((e) => e.toJson()).toList());

  static List<BudgetCategory> _defaultBudgetCategories() {
    return [
      BudgetCategory(id: 'cat_food', name: 'Продукты', emoji: '🍎', type: 'expense', colorValue: 0xFFFF8FAB),
      BudgetCategory(id: 'cat_transport', name: 'Транспорт', emoji: '🚗', type: 'expense', colorValue: 0xFF5856D6),
      BudgetCategory(id: 'cat_home', name: 'Жильё', emoji: '🏠', type: 'expense', colorValue: 0xFF34C759),
      BudgetCategory(id: 'cat_fun', name: 'Развлечения', emoji: '🎬', type: 'expense', colorValue: 0xFFFF9500),
      BudgetCategory(id: 'cat_health', name: 'Здоровье', emoji: '💊', type: 'expense', colorValue: 0xFFFF3B30),
      BudgetCategory(id: 'cat_clothes', name: 'Одежда', emoji: '👕', type: 'expense', colorValue: 0xFF00C7BE),
      BudgetCategory(id: 'cat_other_expense', name: 'Другое', emoji: '📦', type: 'expense', colorValue: 0xFF9E9E9E),
      BudgetCategory(id: 'cat_salary', name: 'Зарплата', emoji: '💰', type: 'income', colorValue: 0xFF34C759),
      BudgetCategory(id: 'cat_gift', name: 'Подарки', emoji: '🎁', type: 'income', colorValue: 0xFFFF8FAB),
      BudgetCategory(id: 'cat_other_income', name: 'Другое', emoji: '📦', type: 'income', colorValue: 0xFF9E9E9E),
    ];
  }

  // ============ SNAPSHOT ============
  Map<String, dynamic> snapshot() {
    return {
      'purchases': _mapById(purchases.map((p) => p.toJson()).toList()),
      'purchaseLists': _mapById(purchaseLists.map((l) => l.toJson()).toList()),
      'purchaseCategories': _mapById(purchaseCategories.map((c) => c.toJson()).toList()),
      'tasks': _mapById(tasks.map((t) => t.toJson()).toList()),
      'taskCategories': _mapById(taskCategories.map((c) => c.toJson()).toList()),
      'shifts': _mapById(shifts.map((s) => s.toJson()).toList()),
      'shiftTypes': _mapById(shiftTypes.map((t) => t.toJson()).toList()),
      'partners': _mapById(partners.map((p) => p.toJson()).toList()),
      'transactions': _mapById(transactions.map((t) => t.toJson()).toList()),
      'budgetCategories': _mapById(budgetCategories.map((c) => c.toJson()).toList()),
    };
  }

  Map<String, dynamic> _mapById(List<Map<String, dynamic>> items) {
    final result = <String, dynamic>{};
    for (final item in items) {
      final id = item['id'];
      if (id != null) result[id.toString()] = item;
    }
    return result;
  }

  Future<void> clearAll() async => await _box.clear();
  bool get isConfigured => coupleCode != null && coupleCode!.isNotEmpty && myKey != null;
}