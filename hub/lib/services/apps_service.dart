import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'debug_log_service.dart';

/// Модель приложения.
class AppInfo {
  final String packageName;
  final String appName;
  final Uint8List? icon;
  final String? categoryId;
  final bool isFavorite;

  AppInfo({
    required this.packageName,
    required this.appName,
    this.icon,
    this.categoryId,
    this.isFavorite = false,
  });

  AppInfo copyWith({
    String? categoryId,
    bool? isFavorite,
    bool clearCategory = false,
  }) {
    return AppInfo(
      packageName: packageName,
      appName: appName,
      icon: icon,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

/// Модель категории приложений.
class AppCategory {
  final String id;
  String name;
  String emoji;
  int order;

  AppCategory({
    required this.id,
    required this.name,
    this.emoji = '📱',
    this.order = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'order': order,
      };

  factory AppCategory.fromJson(Map<String, dynamic> j) => AppCategory(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Без названия',
        emoji: j['emoji'] as String? ?? '📱',
        order: (j['order'] as num?)?.toInt() ?? 0,
      );

  static List<AppCategory> defaults() => [
        AppCategory(id: 'cat_social', name: 'Соцсети', emoji: '💬', order: 1),
        AppCategory(id: 'cat_games', name: 'Игры', emoji: '🎮', order: 2),
        AppCategory(id: 'cat_media', name: 'Медиа', emoji: '🎬', order: 3),
        AppCategory(id: 'cat_work', name: 'Работа', emoji: '💼', order: 4),
        AppCategory(id: 'cat_other', name: 'Прочее', emoji: '📦', order: 99),
      ];
}

/// Сервис управления приложениями и категориями.
/// 
/// Категории храним в Hive. Список приложений тянем из системного API
/// (через `flutter_device_apps`, инициализируется в другом месте).
class AppsService extends ChangeNotifier {
  static const String _boxName = 'vmeste_hub_data';
  static const String _keyCategories = 'apps_categories';
  static const String _keyMapping = 'apps_category_mapping';
  static const String _keyFavorites = 'apps_favorites';

  final _log = DebugLogService();
  late Box _box;

  List<AppInfo> _apps = [];
  List<AppCategory> _categories = [];

  List<AppInfo> get apps => _apps;
  List<AppCategory> get categories => _categories;

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox(_boxName);
    } else {
      _box = Hive.box(_boxName);
    }
    _loadCategories();
    _log.info('Apps', 'сервис инициализирован, категорий: ${_categories.length}');
  }

  // ============ КАТЕГОРИИ ============

  void _loadCategories() {
    final raw = _box.get(_keyCategories);
    if (raw == null) {
      _categories = AppCategory.defaults();
      _saveCategories();
      return;
    }
    try {
      final list = (raw as List)
          .map((j) => AppCategory.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
      _categories = list.isEmpty ? AppCategory.defaults() : list;
    } catch (_) {
      _categories = AppCategory.defaults();
    }
  }

  void _saveCategories() {
    _box.put(_keyCategories, _categories.map((c) => c.toJson()).toList());
  }

  Future<AppCategory> addCategory(String name, String emoji) async {
    final cat = AppCategory(
      id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      emoji: emoji,
      order: _categories.length,
    );
    _categories.add(cat);
    _saveCategories();
    notifyListeners();
    return cat;
  }

  Future<void> updateCategory(String id, {String? name, String? emoji}) async {
    final i = _categories.indexWhere((c) => c.id == id);
    if (i < 0) return;
    final old = _categories[i];
    _categories[i] = AppCategory(
      id: old.id,
      name: name ?? old.name,
      emoji: emoji ?? old.emoji,
      order: old.order,
    );
    _saveCategories();
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    _categories.removeWhere((c) => c.id == id);
    _saveCategories();
    // Сбрасываем категорию у приложений
    final map = _getMapping();
    map.removeWhere((_, v) => v == id);
    _box.put(_keyMapping, map);
    for (var i = 0; i < _apps.length; i++) {
      if (_apps[i].categoryId == id) {
        _apps[i] = _apps[i].copyWith(clearCategory: true);
      }
    }
    notifyListeners();
  }

  // ============ ПРИЛОЖЕНИЯ ============

  /// Устанавливает список приложений (например, из `flutter_device_apps`).
  Future<void> setApps(List<AppInfo> apps) async {
    final map = _getMapping();
    final favorites = _getFavorites();

    _apps = apps.map((a) {
      return a.copyWith(
        categoryId: map[a.packageName],
        isFavorite: favorites.contains(a.packageName),
      );
    }).toList();

    _apps.sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));
    notifyListeners();
  }

  /// Приложения в категории.
  List<AppInfo> appsInCategory(String categoryId) {
    return _apps.where((a) => a.categoryId == categoryId).toList();
  }

  /// Избранные приложения.
  List<AppInfo> get favorites => _apps.where((a) => a.isFavorite).toList();

  /// Приложения без категории.
  List<AppInfo> get uncategorized => _apps.where((a) => a.categoryId == null).toList();

  Future<void> setCategoryForApp(String packageName, String? categoryId) async {
    final map = _getMapping();
    if (categoryId == null) {
      map.remove(packageName);
    } else {
      map[packageName] = categoryId;
    }
    _box.put(_keyMapping, map);

    final i = _apps.indexWhere((a) => a.packageName == packageName);
    if (i >= 0) {
      _apps[i] = categoryId == null
          ? _apps[i].copyWith(clearCategory: true)
          : _apps[i].copyWith(categoryId: categoryId);
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(String packageName) async {
    final favs = _getFavorites();
    if (favs.contains(packageName)) {
      favs.remove(packageName);
    } else {
      favs.add(packageName);
    }
    _box.put(_keyFavorites, favs.toList());

    final i = _apps.indexWhere((a) => a.packageName == packageName);
    if (i >= 0) {
      _apps[i] = _apps[i].copyWith(isFavorite: favs.contains(packageName));
      notifyListeners();
    }
  }

  // ============ ВНУТРЕННЕЕ ============

  Map<String, String> _getMapping() {
    final raw = _box.get(_keyMapping);
    if (raw == null) return {};
    return Map<String, String>.from(raw as Map);
  }

  Set<String> _getFavorites() {
    final raw = _box.get(_keyFavorites);
    if (raw == null) return {};
    return (raw as List).cast<String>().toSet();
  }
}