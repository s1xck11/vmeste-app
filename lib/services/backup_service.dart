import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'storage_service.dart';

/// Сервис резервного копирования.
/// 
/// Экспорт — сохраняет JSON со всеми данными в файл.
/// Импорт — читает JSON и восстанавливает данные.
class BackupService {
  final StorageService storage;
  BackupService({required this.storage});

  /// Экспортировать все данные в JSON-строку
  String exportToJson() {
    final snapshot = storage.snapshot();
    final backup = {
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      ...snapshot,
    };
    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  /// Импортировать данные из JSON-строки
  /// Возвращает количество восстановленных элементов
  Map<String, int> importFromJson(String jsonString) {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    
    // Считаем элементы до импорта
    final counts = <String, int>{};

    if (data['purchases'] != null) {
      final map = data['purchases'] as Map<String, dynamic>;
      counts['purchases'] = map.length;
    }
    if (data['purchaseLists'] != null) {
      final map = data['purchaseLists'] as Map<String, dynamic>;
      counts['purchaseLists'] = map.length;
    }
    if (data['purchaseCategories'] != null) {
      final map = data['purchaseCategories'] as Map<String, dynamic>;
      counts['purchaseCategories'] = map.length;
    }

    // Восстанавливаем
    storage.restoreFromSnapshot(data);

    return counts;
  }

  /// Сохранить бэкап в файл (для Android)
  Future<String> saveToFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().split('T').first;
    final file = File('${dir.path}/vmeste-backup-$timestamp.json');
    await file.writeAsString(exportToJson());
    return file.path;
  }

  /// Прочитать бэкап из файла
  Future<Map<String, int>> loadFromFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Файл не найден');
    }
    final jsonString = await file.readAsString();
    return importFromJson(jsonString);
  }
}