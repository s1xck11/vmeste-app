// lib/services/import_export_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/purchase.dart';
import '../models/purchase_list.dart';
import '../models/purchase_category.dart';
import '../models/task.dart';
import '../models/task_category.dart';
import '../models/shift.dart';
import '../models/shift_type.dart';
import '../models/partner.dart';
import 'storage_service.dart';
import 'debug_log_service.dart';

class ImportStats {
  final int tasks;
  final int shifts;
  final int purchases;
  final int partners;
  final int shiftTypes;
  final int taskCategories;
  final int purchaseCategories;
  final int purchaseLists;

  const ImportStats({
    this.tasks = 0,
    this.shifts = 0,
    this.purchases = 0,
    this.partners = 0,
    this.shiftTypes = 0,
    this.taskCategories = 0,
    this.purchaseCategories = 0,
    this.purchaseLists = 0,
  });

  int get total =>
      tasks +
      shifts +
      purchases +
      partners +
      shiftTypes +
      taskCategories +
      purchaseCategories +
      purchaseLists;

  @override
  String toString() {
    return 'Задачи: $tasks\n'
        'Смены: $shifts\n'
        'Покупки: $purchases\n'
        'Партнёры: $partners\n'
        'Типы смен: $shiftTypes\n'
        'Категории задач: $taskCategories\n'
        'Категории покупок: $purchaseCategories\n'
        'Списки покупок: $purchaseLists';
  }
}

class ImportExportService {
  final StorageService storage;
  final _log = DebugLogService();

  ImportExportService(this.storage);

  // ============ ЭКСПОРТ ============

  String buildExportJson() {
    final snapshot = storage.snapshot();
    final payload = {
      '_meta': {
        'app': 'Vmeste Flutter',
        'exportedAt': DateTime.now().toIso8601String(),
        'version': 1,
      },
      ...snapshot,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<String> exportToFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final name =
        'vmeste-backup-${now.year}-${_two(now.month)}-${_two(now.day)}-${_two(now.hour)}${_two(now.minute)}.json';
    final file = File('${dir.path}/$name');
    final json = buildExportJson();
    await file.writeAsString(json);
    _log.info('ImportExport', 'экспорт сохранён: ${file.path}');
    return file.path;
  }

  // ============ ИМПОРТ ============

  Future<ImportStats> importFromFile(String path, {required bool replaceAll}) async {
    _log.info('ImportExport', 'импорт из $path (replaceAll=$replaceAll)');
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Файл не найден: $path');
    }
    final raw = await file.readAsString();
    return importFromJson(raw, replaceAll: replaceAll);
  }

  Future<ImportStats> importFromJson(String rawJson, {required bool replaceAll}) async {
    Map<String, dynamic> root;
    try {
      root = Map<String, dynamic>.from(jsonDecode(rawJson) as Map);
    } catch (e, st) {
      _log.error('ImportExport', 'не удалось распарсить JSON', e, st);
      throw Exception('Файл не является корректным JSON');
    }

    if (replaceAll) {
      _log.info('ImportExport', 'полная замена данных');
      storage.purchases = [];
      storage.tasks = [];
      storage.shifts = [];
      storage.partners = Partner.defaults();
      storage.shiftTypes = ShiftType.defaults();
      storage.taskCategories = TaskCategory.defaults();
      storage.purchaseCategories = PurchaseCategory.defaults();
      storage.purchaseLists = PurchaseList.defaults();
    }

    int countTasks = 0;
    int countShifts = 0;
    int countPurchases = 0;
    int countPartners = 0;
    int countShiftTypes = 0;
    int countTaskCats = 0;
    int countPurchCats = 0;
    int countPurchLists = 0;

    // ---------- ЗАДАЧИ ----------
    final tasksRaw = _extractMap(root, 'tasks');
    if (tasksRaw != null) {
      final existing = {for (final t in storage.tasks) t.id.toString(): t};
      for (final entry in tasksRaw.entries) {
        final map = Map<String, dynamic>.from(entry.value as Map);
        if (map['deletedAt'] != null) continue;
        try {
          final task = Task.fromJson(map);
          existing[task.id.toString()] = task;
          countTasks++;
        } catch (e) {
          _log.warn('ImportExport', 'задача ${entry.key} пропущена: $e');
        }
      }
      storage.tasks = existing.values.toList();
    }

    // ---------- СМЕНЫ ----------
    final shiftsRaw = _extractMap(root, 'shifts');
    if (shiftsRaw != null) {
      final existing = {for (final s in storage.shifts) s.id.toString(): s};
      for (final entry in shiftsRaw.entries) {
        final map = Map<String, dynamic>.from(entry.value as Map);
        if (map['deletedAt'] != null) continue;
        try {
          final shift = Shift.fromJson(map);
          existing[shift.id.toString()] = shift;
          countShifts++;
        } catch (e) {
          _log.warn('ImportExport', 'смена ${entry.key} пропущена: $e');
        }
      }
      storage.shifts = existing.values.toList();
    }

    // ---------- ПОКУПКИ ----------
    final purchasesRaw = _extractMap(root, 'purchases');
    if (purchasesRaw != null) {
      final existing = {for (final p in storage.purchases) p.id.toString(): p};
      for (final entry in purchasesRaw.entries) {
        final map = Map<String, dynamic>.from(entry.value as Map);
        if (map['deletedAt'] != null) continue;
        try {
          final purchase = Purchase.fromJson(map);
          existing[purchase.id.toString()] = purchase;
          countPurchases++;
        } catch (e) {
          _log.warn('ImportExport', 'покупка ${entry.key} пропущена: $e');
        }
      }
      storage.purchases = existing.values.toList();
    }

    // ---------- ПАРТНЁРЫ ----------
    final partnersRaw = root['partners'];
    if (partnersRaw != null) {
      try {
        List<Partner> partners = [];
        if (partnersRaw is List) {
          partners = partnersRaw
              .map((e) => Partner.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        } else if (partnersRaw is Map) {
          for (final entry in partnersRaw.entries) {
            if (entry.key == 'updatedAt') continue;
            final p = Map<String, dynamic>.from(entry.value as Map);
            p['id'] = entry.key;
            partners.add(Partner.fromJson(p));
          }
        }
        if (partners.isNotEmpty) {
          storage.partners = partners;
          countPartners = partners.length;
        }
      } catch (e) {
        _log.warn('ImportExport', 'partners пропущены: $e');
      }
    }

    // ---------- ТИПЫ СМЕН ----------
    final shiftTypesRaw = _extractMap(root, 'shiftTypes');
    if (shiftTypesRaw != null) {
      try {
        final list = <ShiftType>[];
        for (final entry in shiftTypesRaw.entries) {
          final m = Map<String, dynamic>.from(entry.value as Map);
          m['id'] = entry.key;
          list.add(ShiftType.fromJson(m));
        }
        if (list.isNotEmpty) {
          storage.shiftTypes = list;
          countShiftTypes = list.length;
        }
      } catch (e) {
        _log.warn('ImportExport', 'shiftTypes пропущены: $e');
      }
    }

    // ---------- КАТЕГОРИИ ЗАДАЧ ----------
    final taskCatsRaw = _extractMap(root, 'taskCategories');
    if (taskCatsRaw != null) {
      try {
        final list = <TaskCategory>[];
        for (final entry in taskCatsRaw.entries) {
          final m = Map<String, dynamic>.from(entry.value as Map);
          m['id'] = entry.key;
          list.add(TaskCategory.fromJson(m));
        }
        if (list.isNotEmpty) {
          storage.taskCategories = list;
          countTaskCats = list.length;
        }
      } catch (e) {
        _log.warn('ImportExport', 'taskCategories пропущены: $e');
      }
    }

    // ---------- КАТЕГОРИИ ПОКУПОК ----------
    final purchCatsRaw = _extractMap(root, 'purchaseCategories');
    if (purchCatsRaw != null) {
      try {
        final list = <PurchaseCategory>[];
        for (final entry in purchCatsRaw.entries) {
          final m = Map<String, dynamic>.from(entry.value as Map);
          m['id'] = entry.key;
          list.add(PurchaseCategory.fromJson(m));
        }
        if (list.isNotEmpty) {
          storage.purchaseCategories = list;
          countPurchCats = list.length;
        }
      } catch (e) {
        _log.warn('ImportExport', 'purchaseCategories пропущены: $e');
      }
    }

    // ---------- СПИСКИ ПОКУПОК ----------
    final purchListsRaw = _extractMap(root, 'purchaseLists');
    if (purchListsRaw != null) {
      try {
        final list = <PurchaseList>[];
        for (final entry in purchListsRaw.entries) {
          final m = Map<String, dynamic>.from(entry.value as Map);
          m['id'] = entry.key;
          list.add(PurchaseList.fromJson(m));
        }
        if (list.isNotEmpty) {
          storage.purchaseLists = list;
          countPurchLists = list.length;
        }
      } catch (e) {
        _log.warn('ImportExport', 'purchaseLists пропущены: $e');
      }
    }

    final stats = ImportStats(
      tasks: countTasks,
      shifts: countShifts,
      purchases: countPurchases,
      partners: countPartners,
      shiftTypes: countShiftTypes,
      taskCategories: countTaskCats,
      purchaseCategories: countPurchCats,
      purchaseLists: countPurchLists,
    );
    _log.info('ImportExport', 'импорт завершён: $stats');
    return stats;
  }

  Map<dynamic, dynamic>? _extractMap(Map<String, dynamic> root, String key) {
    final raw = root[key];
    if (raw is Map) return raw;
    return null;
  }

  String _two(int n) => n < 10 ? '0$n' : '$n';

  Future<String> getBackupDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }
}