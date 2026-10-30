import 'dart:convert';
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
import '../models/bank.dart';
import '../models/recurring_payment.dart';
import '../models/purchase_template.dart';
import '../models/purchase_history_entry.dart';

class StorageService {
  late Box _box;
  late Box _outboxBox;  // НОВОЕ: очередь исходящих операций
  late Box _tombstonesBox;  // НОВОЕ: надгробия удалённых элементов

  // Vector clock: {partner1: 5, partner2: 3}
  Map<String, int> _vectorClock = {};

  String? get coupleCode => _box.get('coupleCode') as String?;
  set coupleCode(String? v) => _box.put('coupleCode', v);

  String? get myKey => _box.get('myKey') as String?;
  set myKey(String? v) => _box.put('myKey', v);

  String? get myPartnerId => _box.get('myPartnerId') as String?;
  set myPartnerId(String? v) => _box.put('myPartnerId', v);

  String get myName => _box.get('myName', defaultValue: '') as String;
  set myName(String v) => _box.put('myName', v);

  String get partnerName => _box.get('partnerName', defaultValue: '') as String;
  set partnerName(String v) => _box.put('partnerName', v);

  String? get currentUserId => _box.get('currentUserId') as String?;
  set currentUserId(String? v) => _box.put('currentUserId', v);

  int get serverVersion => _box.get('serverVersion', defaultValue: 0) as int;
  set serverVersion(int v) => _box.put('serverVersion', v);

  List<String> get members => List<String>.from(_box.get('members', defaultValue: <String>[]) as List);
  set members(List<String> v) => _box.put('members', v);

  String get myAvatar => _box.get('myAvatar', defaultValue: '🐻') as String;
  set myAvatar(String v) => _box.put('myAvatar', v);

  bool get isConfigured => coupleCode != null && myKey != null;

  // Vector clock getters/setters
  Map<String, int> get vectorClock => Map<String, int>.from(_vectorClock);
  set vectorClock(Map<String, int> v) {
    _vectorClock = Map<String, int>.from(v);
    _box.put('vectorClock', v);
  }

  int incrementClock(String partnerId) {
    final current = _vectorClock[partnerId] ?? 0;
    _vectorClock[partnerId] = current + 1;
    _box.put('vectorClock', _vectorClock);
    return current + 1;
  }

  void applyRemoteClock(Map<String, int> remoteClock) {
    for (final entry in remoteClock.entries) {
      final current = _vectorClock[entry.key] ?? 0;
      if (entry.value > current) {
        _vectorClock[entry.key] = entry.value;
      }
    }
    _box.put('vectorClock', _vectorClock);
  }

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox('vmeste_data');
    _outboxBox = await Hive.openBox('vmeste_outbox');  // НОВОЕ
    _tombstonesBox = await Hive.openBox('vmeste_tombstones');  // НОВОЕ

    final savedClock = _box.get('vectorClock');
    if (savedClock != null) {
      _vectorClock = Map<String, int>.from(savedClock as Map);
    }
  }

  // ============================================================
  // OUTBOX (очередь исходящих операций)
  // ============================================================

  void addToOutbox(String type, String entityId, String operation, Map<String, dynamic>? data) {
    final id = '${DateTime.now().millisecondsSinceEpoch}_${entityId}';
    _outboxBox.put(id, {
      'id': id,
      'type': type,
      'entityId': entityId,
      'operation': operation,  // create, update, delete
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'status': 'pending',
      'attempts': 0,
    });
  }

  List<Map<String, dynamic>> getPendingOperations() {
    return _outboxBox.values
        .where((v) => v['status'] == 'pending')
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList()
      ..sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));
  }

  void markOperationSent(String id) {
    final op = _outboxBox.get(id);
    if (op != null) {
      final updated = Map<String, dynamic>.from(op as Map);
      updated['status'] = 'sent';
      _outboxBox.put(id, updated);
    }
  }

  void markOperationFailed(String id) {
    final op = _outboxBox.get(id);
    if (op != null) {
      final updated = Map<String, dynamic>.from(op as Map);
      updated['status'] = 'failed';
      updated['attempts'] = (updated['attempts'] as int? ?? 0) + 1;
      _outboxBox.put(id, updated);
    }
  }

  void clearSentOperations() {
    final keysToDelete = _outboxBox.keys
        .where((k) => _outboxBox.get(k)?['status'] == 'sent')
        .toList();
    for (final key in keysToDelete) {
      _outboxBox.delete(key);
    }
  }

  // ============================================================
  // TOMBSTONES (надгробия удалённых элементов)
  // ============================================================

  void addTombstone(String entityType, String entityId, int deletedAt, String deletedBy) {
    _tombstonesBox.put('${entityType}_$entityId', {
      'entityType': entityType,
      'entityId': entityId,
      'deletedAt': deletedAt,
      'deletedBy': deletedBy,
    });
  }

  bool isTombstoned(String entityType, String entityId) {
    return _tombstonesBox.containsKey('${entityType}_$entityId');
  }

  Map<String, dynamic>? getTombstone(String entityType, String entityId) {
    final data = _tombstonesBox.get('${entityType}_$entityId');
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  Map<String, Map<String, dynamic>> getAllTombstones() {
    final result = <String, Map<String, dynamic>>{};
    for (final key in _tombstonesBox.keys) {
      final data = _tombstonesBox.get(key);
      if (data != null) {
        result[key.toString()] = Map<String, dynamic>.from(data as Map);
      }
    }
    return result;
  }

  void removeTombstone(String entityType, String entityId) {
    _tombstonesBox.delete('${entityType}_$entityId');
  }

  // Очистка старых tombstones (старше 90 дней)
  void cleanupOldTombstones() {
    final cutoff = DateTime.now().millisecondsSinceEpoch - (90 * 24 * 60 * 60 * 1000);
    final keysToDelete = <String>[];
    for (final key in _tombstonesBox.keys) {
      final data = _tombstonesBox.get(key);
      if (data != null) {
        final deletedAt = data['deletedAt'] as int? ?? 0;
        if (deletedAt < cutoff) {
          keysToDelete.add(key.toString());
        }
      }
    }
    for (final key in keysToDelete) {
      _tombstonesBox.delete(key);
    }
  }

  // ============================================================
  // ДАННЫЕ
  // ============================================================

  List<Purchase> get purchases {
    final raw = _box.get('purchases');
    if (raw == null) return [];
    return (raw as List).map((e) => Purchase.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  set purchases(List<Purchase> v) {
    _box.put('purchases', v.map((e) => e.toJson()).toList());
  }

  List<PurchaseList> get purchaseLists {
    final raw = _box.get('purchaseLists');
    if (raw == null) return [];
    return (raw as List).map((e) => PurchaseList.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  set purchaseLists(List<PurchaseList> v) {
    _box.put('purchaseLists', v.map((e) => e.toJson()).toList());
  }

  List<PurchaseCategory> get purchaseCategories {
    final raw = _box.get('purchaseCategories');
    if (raw == null) return [];
    return (raw as List).map((e) => PurchaseCategory.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  set purchaseCategories(List<PurchaseCategory> v) {
    _box.put('purchaseCategories', v.map((e) => e.toJson()).toList());
  }

  List<Task> get tasks {
    final raw = _box.get('tasks');
    if (raw == null) return [];
    return (raw as List).map((e) => Task.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  set tasks(List<Task> v) {
    _box.put('tasks', v.map((e) => e.toJson()).toList());
  }

  List<TaskCategory> get taskCategories {
    final raw = _box.get('taskCategories');
    if (raw == null) return [];
    return (raw as List).map((e) => TaskCategory.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  set taskCategories(List<TaskCategory> v) {
    _box.put('taskCategories', v.map((e) => e.toJson()).toList());
  }

  List<Shift> get shifts {
    final raw = _box.get('shifts');
    if (raw == null) return [];
    return (raw as List).map((e) => Shift.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  set shifts(List<Shift> v) {
    _box.put('shifts', v.map((e) => e.toJson()).toList());
  }

  List<ShiftType> get shiftTypes {
    final raw = _box.get('shiftTypes');
    if (raw == null) return [];
    return (raw as List).map((e) => ShiftType.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  set shiftTypes(List<ShiftType> v) {
    _box.put('shiftTypes', v.map((e) => e.toJson()).toList());
  }

  List<Partner> get partners {
    final raw = _box.get('partners');
    if (raw == null) return [];
    return (raw as List).map((e) => Partner.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  set partners(List<Partner> v) {
    _box.put('partners', v.map((e) => e.toJson()).toList());
  }

  List<Transaction> get transactions {
    final raw = _box.get('transactions');
    if (raw == null) return [];
    return (raw as List).map((e) => Transaction.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  set transactions(List<Transaction> v) {
    _box.put('transactions', v.map((e) => e.toJson()).toList());
  }

  List<BudgetCategory> get budgetCategories {
    final raw = _box.get('budgetCategories');
    if (raw == null) return [];
    return (raw as List).map((e) => BudgetCategory.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  set budgetCategories(List<BudgetCategory> v) {
    _box.put('budgetCategories', v.map((e) => e.toJson()).toList());
  }

  List<Bank> get banks {
    final raw = _box.get('banks');
    if (raw == null) return [];
    return (raw as List).map((e) => Bank.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  set banks(List<Bank> v) {
    _box.put('banks', v.map((e) => e.toJson()).toList());
  }

  List<RecurringPayment> get recurringPayments {
    final raw = _box.get('recurringPayments');
    if (raw == null) return [];
    return (raw as List).map((e) => RecurringPayment.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  set recurringPayments(List<RecurringPayment> v) {
    _box.put('recurringPayments', v.map((e) => e.toJson()).toList());
  }

  List<PurchaseTemplate> get purchaseTemplates {
    final raw = _box.get('purchaseTemplates');
    if (raw == null) return [];
    return (raw as List).map((e) => PurchaseTemplate.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  set purchaseTemplates(List<PurchaseTemplate> v) {
    _box.put('purchaseTemplates', v.map((e) => e.toJson()).toList());
  }

  List<PurchaseHistoryEntry> get purchaseHistory {
    final raw = _box.get('purchaseHistory');
    if (raw == null) return [];
    return (raw as List).map((e) => PurchaseHistoryEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  set purchaseHistory(List<PurchaseHistoryEntry> v) {
    _box.put('purchaseHistory', v.map((e) => e.toJson()).toList());
  }

  Map<String, dynamic> snapshot() {
    return {
      'purchases': {for (final p in purchases) p.id.toString(): p.toJson()},
      'purchaseLists': {for (final l in purchaseLists) l.id.toString(): l.toJson()},
      'purchaseCategories': {for (final c in purchaseCategories) c.id.toString(): c.toJson()},
      'tasks': {for (final t in tasks) t.id.toString(): t.toJson()},
      'taskCategories': {for (final c in taskCategories) c.id.toString(): c.toJson()},
      'shifts': {for (final s in shifts) s.id.toString(): s.toJson()},
      'shiftTypes': {for (final t in shiftTypes) t.id.toString(): t.toJson()},
      'partners': {for (final p in partners) p.id.toString(): p.toJson()},
      'transactions': {for (final t in transactions) t.id.toString(): t.toJson()},
      'budgetCategories': {for (final c in budgetCategories) c.id.toString(): c.toJson()},
      'banks': {for (final b in banks) b.id.toString(): b.toJson()},
      'recurringPayments': {for (final r in recurringPayments) r.id.toString(): r.toJson()},
      'purchaseTemplates': {for (final t in purchaseTemplates) t.id.toString(): t.toJson()},
      'purchaseHistory': purchaseHistory.map((e) => e.toJson()).toList(),
      'tombstones': getAllTombstones(),  // НОВОЕ
      'vectorClock': vectorClock,  // НОВОЕ
    };
  }

  Future<void> clearAll() async {
    await _box.clear();
    await _outboxBox.clear();
    await _tombstonesBox.clear();
    _vectorClock = {};
  }
}
