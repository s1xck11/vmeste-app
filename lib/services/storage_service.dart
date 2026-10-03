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

  /// Инициализация хранилища. Вызывать один раз при запуске.
  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  // ============ ГРУППА ============
  
  /// Код группы (например, JFA-K3R-LUM)
  String? get coupleCode => _box.get('coupleCode') as String?;
  set coupleCode(String? code) => _box.put('coupleCode', code);

  /// Мой UID в Supabase
  String? get currentUserId => _box.get('currentUserId') as String?;
  set currentUserId(String? uid) => _box.put('currentUserId', uid);

  /// Имя моего партнёра (partner1 или partner2)
  /// Определяется при первом присоединении к группе.
  String? get myPartnerId => _box.get('myPartnerId') as String?;
  set myPartnerId(String? pid) => _box.put('myPartnerId', pid);

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

  /// Удалённые ID покупок (для мягкого удаления)
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

  // ============ ОБЩЕЕ ============

  /// Очистить всё (при сбросе данных)
  Future<void> clearAll() async {
    await _box.clear();
  }

  /// Проверка: настроено ли приложение (есть ли группа)
  bool get isConfigured => coupleCode != null && coupleCode!.isNotEmpty;
}