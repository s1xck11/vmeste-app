// tv/lib/services/tv_sync_service.dart
//
// READ-ONLY синк для ТВ-лаунчера.
// Логика один-в-один из мобильной main (lib/services/sync_service.dart):
// та же таблица couples, те же ключи data, тот же realtime-канал,
// тот же пулл раз в 30 секунд и сравнение vectorClock.
//
// ВАЖНО: этот сервис НИЧЕГО не пишет в Supabase.
// Никаких push, members, profiles, tombstones.
// ТВ только читает данные — стереть или сломать что-либо он не может.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bank.dart';
import '../models/budget_category.dart';
import '../models/partner.dart';
import '../models/purchase.dart';
import '../models/purchase_category.dart';
import '../models/purchase_list.dart';
import '../models/shift.dart';
import '../models/shift_type.dart';
import '../models/task.dart';
import '../models/task_category.dart';
import '../models/transaction.dart';

enum TvSyncStatus { noGroup, connecting, online, offline }

class TvSyncService extends ChangeNotifier {
  static const String _boxName = 'vmeste_tv_cache';
  static const String _keyCode = 'group_code';
  static const String _keyData = 'last_data';
  static const String _keyClock = 'last_clock';
  static const Duration _pullInterval = Duration(seconds: 30);

  final SupabaseClient _supabase = Supabase.instance.client;
  late Box _box;

  RealtimeChannel? _channel;
  Timer? _pullTimer;
  bool _isPulling = false;
  bool _hasApplied = false;
  bool _disposed = false;

  TvSyncStatus status = TvSyncStatus.noGroup;
  String? errorText;
  String? groupCode;
  DateTime? lastSyncAt;
  Map<String, int> _clock = {};

  List<Task> tasks = [];
  List<Purchase> purchases = [];
  List<Shift> shifts = [];
  List<Transaction> transactions = [];
  List<Partner> partners = [];
  List<ShiftType> shiftTypes = [];
  List<BudgetCategory> budgetCategories = [];
  List<TaskCategory> taskCategories = [];
  List<PurchaseCategory> purchaseCategories = [];
  List<PurchaseList> purchaseLists = [];
  List<Bank> banks = [];

  bool get hasGroup => groupCode != null && groupCode!.isNotEmpty;
  bool get isOnline => status == TvSyncStatus.online;

  // ============================================================
  // INIT / CONNECT
  // ============================================================

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    groupCode = (_box.get(_keyCode) as String?)?.trim();

    // Кэш с прошлого запуска — показываем данные сразу, даже без интернета
    final cached = _box.get(_keyData);
    if (cached is Map) {
      try {
        _applyData(Map<String, dynamic>.from(cached));
        _clock = _parseClock(_box.get(_keyClock));
      } catch (_) {}
    }

    if (hasGroup) {
      await connect(groupCode!);
    } else {
      _notify();
    }
  }

  /// Подключение по коду группы. true — данные получены.
  Future<bool> connect(String code) async {
    final c = code.trim().toUpperCase();
    if (c.isEmpty) return false;
    groupCode = c;
    await _box.put(_keyCode, c);
    errorText = null;
    _setStatus(TvSyncStatus.connecting);

    final ok = await _tryConnect();
    if (ok) {
      _startPullTimer();
      return true;
    }
    if (status == TvSyncStatus.noGroup) {
      // Группа не найдена — забываем код
      groupCode = null;
      await _box.delete(_keyCode);
      return false;
    }
    // Проблема сети — код сохраняем, пробуем снова в фоне
    _startPullTimer();
    return false;
  }

  Future<bool> _tryConnect() async {
    try {
      await _signInAnonymously();
      final found = await _fetchAndApply();
      if (!found) {
        errorText = 'Группа с кодом ${groupCode ?? ''} не найдена';
        _setStatus(TvSyncStatus.noGroup);
        return false;
      }
      _subscribe();
      _setStatus(TvSyncStatus.online);
      return true;
    } catch (_) {
      errorText = 'Нет связи с сервером. Проверь интернет.';
      _setStatus(TvSyncStatus.offline);
      return false;
    }
  }

  /// Анонимный вход как в main: переиспользуем сессию, 3 попытки.
  Future<void> _signInAnonymously() async {
    if (_supabase.auth.currentUser != null) return;
    Object? lastError;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final res = await _supabase.auth
            .signInAnonymously()
            .timeout(const Duration(seconds: 30));
        if (res.user == null) throw Exception('пустой user');
        return;
      } catch (e) {
        lastError = e;
        if (attempt < 3) await Future.delayed(const Duration(seconds: 2));
      }
    }
    throw lastError ?? Exception('Не удалось войти');
  }

  // ============================================================
  // PULL (каждые 30 сек, как в main)
  // ============================================================

  void _startPullTimer() {
    _pullTimer?.cancel();
    _pullTimer = Timer.periodic(_pullInterval, (_) => pullNow());
  }

  Future<void> pullNow() async {
    if (!hasGroup || _isPulling) return;
    _isPulling = true;
    try {
      if (status != TvSyncStatus.online || _channel == null) {
        // Переподключение после офлайна
        final ok = await _tryConnect();
        if (ok) errorText = null;
        return;
      }
      final found = await _fetchAndApply();
      if (!found) {
        errorText = 'Группа больше не существует';
        _setStatus(TvSyncStatus.noGroup);
        return;
      }
      if (_channel == null) _subscribe();
      _setStatus(TvSyncStatus.online);
    } catch (_) {
      _setStatus(TvSyncStatus.offline);
    } finally {
      _isPulling = false;
    }
  }

  /// Читает строку группы. ТОЛЬКО select, никаких update/insert.
  Future<bool> _fetchAndApply() async {
    final remote = await _supabase
        .from('couples')
        .select('data, version')
        .eq('code', groupCode!)
        .maybeSingle()
        .timeout(const Duration(seconds: 20));
    if (remote == null) return false;

    final data = Map<String, dynamic>.from(remote['data'] as Map? ?? {});
    final remoteClock = _parseClock(data['vectorClock']);
    lastSyncAt = DateTime.now();

    if (_hasApplied && _clocksEqual(remoteClock, _clock)) return true;

    _applyData(data);
    _clock = remoteClock;
    await _box.put(_keyData, data);
    await _box.put(_keyClock, remoteClock);
    errorText = null;
    _notify();
    return true;
  }

  // ============================================================
  // REALTIME (канал и фильтр как в main)
  // ============================================================

  void _subscribe() {
    if (!hasGroup) return;
    _channel?.unsubscribe();
    _channel = _supabase
        .channel('couple:$groupCode')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'couples',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'code',
            value: groupCode!,
          ),
          callback: (payload) {
            final rec = payload.newRecord;
            if (rec.isEmpty) return;
            final data = Map<String, dynamic>.from(rec['data'] as Map? ?? {});
            final remoteClock = _parseClock(data['vectorClock']);
            if (_hasApplied && _clocksEqual(remoteClock, _clock)) return;
            _applyData(data);
            _clock = remoteClock;
            lastSyncAt = DateTime.now();
            errorText = null;
            _box.put(_keyData, data);
            _box.put(_keyClock, remoteClock);
            _setStatus(TvSyncStatus.online);
            _notify();
          },
        )
        .subscribe((s, err) {
          if (s == RealtimeSubscribeStatus.subscribed) {
            _setStatus(TvSyncStatus.online);
          } else if (s == RealtimeSubscribeStatus.channelError ||
              s == RealtimeSubscribeStatus.timedOut ||
              s == RealtimeSubscribeStatus.closed) {
            _channel = null;
            if (status == TvSyncStatus.online) {
              _setStatus(TvSyncStatus.offline);
            }
          }
        });
  }

  // ============================================================
  // РАЗБОР ДАННЫХ (ключи и tombstones как в main)
  // ============================================================

  void _applyData(Map<String, dynamic> data) {
    tasks = _items(data, 'tasks', Task.fromJson);
    purchases = _items(data, 'purchases', Purchase.fromJson);
    shifts = _items(data, 'shifts', Shift.fromJson);
    transactions = _items(data, 'transactions', Transaction.fromJson);

    partners = _refs(data, 'partners', Partner.fromJson, partners);
    shiftTypes = _refs(data, 'shiftTypes', ShiftType.fromJson, shiftTypes);
    budgetCategories = _refs(data, 'budgetCategories', BudgetCategory.fromJson, budgetCategories);
    taskCategories = _refs(data, 'taskCategories', TaskCategory.fromJson, taskCategories);
    purchaseCategories = _refs(data, 'purchaseCategories', PurchaseCategory.fromJson, purchaseCategories);
    purchaseLists = _refs(data, 'purchaseLists', PurchaseList.fromJson, purchaseLists);
    banks = _refs(data, 'banks', Bank.fromJson, banks);
    _hasApplied = true;
  }

  /// Элементы — Map по id. Пропускаем удалённые (deletedAt != null).
  List<T> _items<T>(
    Map<String, dynamic> data,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = data[key];
    if (raw is! Map) return [];
    final out = <T>[];
    for (final entry in raw.entries) {
      final j = Map<String, dynamic>.from(entry.value as Map? ?? {});
      if (j.isEmpty) continue;
      if (j['deletedAt'] != null) continue; // tombstone
      try {
        out.add(fromJson(j));
      } catch (_) {}
    }
    return out;
  }

  /// Справочники. Если ключа нет в data — оставляем прежние (из кэша).
  List<T> _refs<T>(
    Map<String, dynamic> data,
    String key,
    T Function(Map<String, dynamic>) fromJson,
    List<T> current,
  ) {
    final raw = data[key];
    if (raw is! Map) return current;
    final out = <T>[];
    for (final entry in raw.entries) {
      final j = Map<String, dynamic>.from(entry.value as Map? ?? {});
      if (j.isEmpty) continue;
      try {
        out.add(fromJson(j));
      } catch (_) {}
    }
    return out;
  }

  Map<String, int> _parseClock(dynamic raw) {
    if (raw is! Map) return {};
    final out = <String, int>{};
    raw.forEach((k, v) {
      out[k.toString()] = (v as num?)?.toInt() ?? 0;
    });
    return out;
  }

  bool _clocksEqual(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  // ============================================================
  // СМЕНА ГРУППЫ / СТАТУС
  // ============================================================

  Future<void> disconnect() async {
    _pullTimer?.cancel();
    _pullTimer = null;
    _channel?.unsubscribe();
    _channel = null;
    groupCode = null;
    _clock = {};
    _hasApplied = false;
    tasks = [];
    purchases = [];
    shifts = [];
    transactions = [];
    partners = [];
    shiftTypes = [];
    budgetCategories = [];
    taskCategories = [];
    purchaseCategories = [];
    purchaseLists = [];
    banks = [];
    lastSyncAt = null;
    errorText = null;
    await _box.delete(_keyCode);
    await _box.delete(_keyData);
    await _box.delete(_keyClock);
    _setStatus(TvSyncStatus.noGroup);
  }

  void _setStatus(TvSyncStatus s) {
    if (status == s) return;
    status = s;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pullTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }
}
