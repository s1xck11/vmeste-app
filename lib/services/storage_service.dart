import 'package:hive_flutter/hive_flutter.dart';
import '../models/purchase.dart';
import '../models/purchase_list.dart';
import '../models/purchase_category.dart';

/// Сервис локального хранения данных.
/// 
/// Сохраняет всё локально, чтобы приложение работало без интернета.
/// Когда появится связь — данные синхронизируются с Supabase.
class StorageService {
  static const String _boxName = 'vmeste_data';
  late Box _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  // ============ ГРУППА ============

  String? get coupleCode => _box.get('coupleCode') as String?;
  set coupleCode(String? code) => _box.put('coupleCode', code);

  String? get currentUserId => _box.get('currentUserId') as String?;
  set currentUserId(String? uid) => _box.put('currentUserId', uid);

  /// Кто я в паре: 'partner1' или 'partner2'
  String? get myPartnerId => _box.get('myPartnerId') as String?;
  set myPartnerId(String? pid) => _box.put('myPartnerId', pid);

  /// Участники группы (UID из Supabase)
  List<String> get members {
    final raw = _box.get('members');
    if (raw == null) return [];
    return (raw as List).cast<String>();
  }

  set members(List<String> m) => _box.put('members', m);

  /// Версия данных на сервере (для защиты от перезаписи)
  int get serverVersion => _box.get('serverVersion') as int? ?? 0;
  set serverVersion(int v) => _box.put('serverVersion', v);

  // ============ ПОКУПКИ ============

  /// Все покупки (включая удалённые — для корректного merge)
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

  set purchases(List<Purchase> items) {
    _box.put('purchases', items.map((e) => e.toJson()).toList());
  }

  List<int> get deletedPurchaseIds {
    final raw = _box.get('deletedPurchaseIds');
    if (raw == null) return [];
    return (raw as List).cast<int>();
  }

  set deletedPurchaseIds(List<int> ids) => _box.put('deletedPurchaseIds', ids);

  // ============ СПИСКИ ============

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

  set purchaseLists(List<PurchaseList> lists) {
    _box.put('purchaseLists', lists.map((e) => e.toJson()).toList());
  }

  // ============ КАТЕГОРИИ ============

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

  set purchaseCategories(List<PurchaseCategory> cats) {
    _box.put('purchaseCategories', cats.map((e) => e.toJson()).toList());
  }

  // ============ JSON-СНИМОК ВСЕХ ДАННЫХ ============

  /// Собрать всё локальное состояние в один Map — для отправки в Supabase
  Map<String, dynamic> snapshot() {
    return {
      'purchases': _mapById(purchases.map((p) => p.toJson()).toList()),
      'purchaseLists': _mapById(purchaseLists.map((l) => l.toJson()).toList()),
      'purchaseCategories': _mapById(purchaseCategories.map((c) => c.toJson()).toList()),
    };
  }

  /// Восстановить всё состояние из Map — после получения от Supabase
  void restoreFromSnapshot(Map<String, dynamic> data) {
    if (data['purchases'] != null) {
      final map = data['purchases'] as Map;
      purchases = map.values
          .map((v) => Purchase.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();
    }
    if (data['purchaseLists'] != null) {
      final map = data['purchaseLists'] as Map;
      purchaseLists = map.values
          .map((v) => PurchaseList.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();
    }
    if (data['purchaseCategories'] != null) {
      final map = data['purchaseCategories'] as Map;
      purchaseCategories = map.values
          .map((v) => PurchaseCategory.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();
    }
  }

  /// Преобразовать список объектов (у которых есть поле 'id') в Map по ID
  Map<String, dynamic> _mapById(List<Map<String, dynamic>> items) {
    final result = <String, dynamic>{};
    for (final item in items) {
      final id = item['id'];
      if (id != null) {
        result[id.toString()] = item;
      }
    }
    return result;
  }

  // ============ ОЧИСТКА ============

  Future<void> clearAll() async {
    await _box.clear();
  }

  bool get isConfigured => coupleCode != null && coupleCode!.isNotEmpty;
}