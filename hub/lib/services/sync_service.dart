// lib/services/sync_service.dart

import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
import 'storage_service.dart';
import 'debug_log_service.dart';

typedef VoidCallback = void Function();

class SyncService {
  final StorageService storage;
  final SupabaseClient _supabase = Supabase.instance.client;
  final _log = DebugLogService();
  final _connectivity = Connectivity();

  RealtimeChannel? _channel;
  Timer? _pushDebounce;
  Timer? _pullTimer;
  Timer? _reconnectTimer;
  StreamSubscription<List<ConnectivityResult>>? _netSub;
  bool _isFirstLoad = true;
  bool _isRemoteUpdate = false;
  bool _isPushInProgress = false;
  bool _isPulling = false;
  bool _isOnline = true;
  bool _pendingPush = false;

  final List<VoidCallback> _listeners = [];
  VoidCallback? onStatusChanged;

  String _status = 'offline';
  String get status => _status;

  SyncService({required this.storage});

  void addListener(VoidCallback listener) {
    if (!_listeners.contains(listener)) _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyAll() {
    for (final l in List<VoidCallback>.from(_listeners)) {
      try { l(); } catch (e, st) { _log.error('Sync', 'listener error', e, st); }
    }
  }

  // ============================================================
  // СЕТЬ
  // ============================================================

  void _startWatchingNetwork() {
    if (_netSub != null) return;
    _netSub = _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      _onNetworkChanged(online);
    });
    _connectivity.checkConnectivity().then((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      _onNetworkChanged(online);
    });
  }

  void _onNetworkChanged(bool online) {
    if (_isOnline == online) return;
    _isOnline = online;
    _log.info('Network', online ? 'интернет появился' : 'интернета нет');

    if (online) {
      _setStatus('syncing');
      _subscribe();
      _startPullTimer();
      pullNow().then((_) {
        if (_pendingPush) {
          _pendingPush = false;
          _log.info('Network', 'отправляю отложенные изменения');
          schedulePush();
        }
      });
    } else {
      _setStatus('offline');
    }
  }

  Future<String> signInAnonymously() async {
    final existing = _supabase.auth.currentUser;
    if (existing != null) {
      storage.currentUserId = existing.id;
      return existing.id;
    }
    Exception? lastError;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        _log.info('Auth', 'попытка $attempt/3');
        final response = await _supabase.auth
            .signInAnonymously()
            .timeout(const Duration(seconds: 30));
        final user = response.user;
        if (user == null) throw Exception('пустой user');
        storage.currentUserId = user.id;
        _log.info('Auth', 'успех, uid=${user.id}');
        return user.id;
      } catch (e, st) {
        lastError = e is Exception ? e : Exception('$e');
        _log.error('Auth', 'попытка $attempt FAILED', e, st);
        if (attempt < 3) await Future.delayed(const Duration(seconds: 2));
      }
    }
    throw lastError ?? Exception('Не удалось войти');
  }

  /// Хаб присоединяется к существующей группе **по ключу**.
  /// 
  /// Используется механизм uids: если наш UID уже есть в профиле — пропуск,
  /// если нет — добавляется. Так хаб становится вторым устройством Серёжи.
  Future<void> restoreByKey(String code, String key) async {
    code = code.trim().toUpperCase();
    key = key.trim().toUpperCase();
    _log.info('Restore', 'подключаюсь к группе $code ключом $key');

    final uid = await signInAnonymously();
    final group = await _supabase
        .from('couples')
        .select()
        .eq('code', code)
        .maybeSingle()
        .timeout(const Duration(seconds: 30));
    if (group == null) throw Exception('Группа не найдена');

    final data = Map<String, dynamic>.from(group['data'] as Map? ?? {});
    final profiles = Map<String, dynamic>.from(data['profiles'] as Map? ?? {});
    if (!profiles.containsKey(key)) throw Exception('Ключ не найден');

    final myProfile = Map<String, dynamic>.from(profiles[key] as Map);
    final uids = List<String>.from(myProfile['uids'] as List? ?? []);
    if (!uids.contains(uid)) uids.add(uid);
    myProfile['uids'] = uids;
    profiles[key] = myProfile;

    final members = List<String>.from(group['members'] as List? ?? []);
    if (!members.contains(uid)) members.add(uid);
    data['profiles'] = profiles;

    await _supabase
        .from('couples')
        .update({'members': members, 'data': data})
        .eq('code', code)
        .timeout(const Duration(seconds: 30));

    storage.coupleCode = code;
    storage.members = members;
    storage.myKey = key;
    storage.myPartnerId = myProfile['role'] as String;
    storage.myName = (myProfile['name'] as String?) ?? '';
    storage.serverVersion = (group['version'] as int?) ?? 0;

    _isRemoteUpdate = true;
    _applyData(data);
    _isRemoteUpdate = false;

    _setStatus('online');
    _isFirstLoad = false;
    _subscribe();
    _startPullTimer();
    _startWatchingNetwork();
    _notifyAll();
  }

  /// Автоподключение при запуске хаба.
  /// Если сохранён `coupleCode` и `myKey` — восстанавливаем сессию.
  Future<bool> autoConnect() async {
    final code = storage.coupleCode;
    final key = storage.myKey;
    if (code == null || code.isEmpty || key == null) return false;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        _setStatus('syncing');
        final uid = await signInAnonymously();
        final group = await _supabase
            .from('couples')
            .select()
            .eq('code', code)
            .maybeSingle()
            .timeout(const Duration(seconds: 30));
        if (group == null) {
          storage.coupleCode = null;
          storage.myKey = null;
          _setStatus('offline');
          return false;
        }
        final data = Map<String, dynamic>.from(group['data'] as Map? ?? {});
        final profiles = Map<String, dynamic>.from(data['profiles'] as Map? ?? {});
        if (!profiles.containsKey(key)) {
          _setStatus('offline');
          return false;
        }

        final myProfile = Map<String, dynamic>.from(profiles[key] as Map);
        final uids = List<String>.from(myProfile['uids'] as List? ?? []);
        if (!uids.contains(uid)) {
          uids.add(uid);
          myProfile['uids'] = uids;
          profiles[key] = myProfile;
          final members = List<String>.from(group['members'] as List? ?? []);
          if (!members.contains(uid)) members.add(uid);
          data['profiles'] = profiles;
          await _supabase
              .from('couples')
              .update({'members': members, 'data': data})
              .eq('code', code)
              .timeout(const Duration(seconds: 30));
          storage.members = members;
        }

        storage.myPartnerId = myProfile['role'] as String;
        storage.myName = (myProfile['name'] as String?) ?? '';
        storage.serverVersion = (group['version'] as int?) ?? 0;
        _isRemoteUpdate = true;
        _applyData(data);
        _isRemoteUpdate = false;
        _setStatus('online');
        _isFirstLoad = false;
        _subscribe();
        _startPullTimer();
        _startWatchingNetwork();
        _notifyAll();
        return true;
      } catch (e, st) {
        _log.error('AutoConnect', 'attempt $attempt FAILED', e, st);
        if (attempt == 3) {
          _setStatus('offline');
          _isFirstLoad = false;
          _startWatchingNetwork();
          return false;
        }
        await Future.delayed(const Duration(seconds: 3));
      }
    }
    return false;
  }

  void _subscribe() {
    final code = storage.coupleCode;
    if (code == null) return;
    if (!_isOnline) return;
    _channel?.unsubscribe();
    _channel = _supabase
        .channel('hub_couple:$code')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'couples',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'code',
              value: code),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isEmpty) return;
            final newVersion = (newRecord['version'] as int?) ?? 0;
            if (newVersion <= storage.serverVersion) return;
            _log.info('Realtime', 'обновление v$newVersion');
            final data = Map<String, dynamic>.from(newRecord['data'] as Map? ?? {});
            _isRemoteUpdate = true;
            _applyData(data);
            storage.serverVersion = newVersion;
            _isRemoteUpdate = false;
            _setStatus('online');
            _notifyAll();
          },
        )
        .subscribe((status, error) {
          _log.info('Realtime', 'статус: $status');
          if (status == RealtimeSubscribeStatus.subscribed) {
            _setStatus('online');
          } else if (status == RealtimeSubscribeStatus.channelError) {
            _setStatus('error');
            _scheduleReconnect();
          } else if (status == RealtimeSubscribeStatus.timedOut) {
            _setStatus('offline');
            _scheduleReconnect();
          } else if (status == RealtimeSubscribeStatus.closed) {
            _setStatus('offline');
            _scheduleReconnect();
          }
        });
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_isOnline) return;
      _log.info('Realtime', 'переподключаюсь...');
      _subscribe();
    });
  }

  void _startPullTimer() {
    _pullTimer?.cancel();
    _pullTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isOnline) pullNow();
    });
  }

  Future<void> pullNow() async {
    if (_isPulling) return;
    if (storage.coupleCode == null) return;
    if (!_isOnline) return;
    _isPulling = true;
    try {
      final remote = await _supabase
          .from('couples')
          .select('data, version')
          .eq('code', storage.coupleCode!)
          .maybeSingle()
          .timeout(const Duration(seconds: 20));
      if (remote == null) return;
      final remoteVersion = (remote['version'] as int?) ?? 0;
      if (remoteVersion <= storage.serverVersion) return;

      _log.info('Pull', 'нашёл обновление v$remoteVersion');
      final remoteData = Map<String, dynamic>.from(remote['data'] as Map? ?? {});
      _isRemoteUpdate = true;
      _applyData(remoteData);
      storage.serverVersion = remoteVersion;
      _isRemoteUpdate = false;
      _setStatus('online');
      _notifyAll();
    } catch (e, st) {
      _log.error('Pull', 'FAILED', e, st);
    } finally {
      _isPulling = false;
    }
  }

  Future<void> forcePullNow() async {
    if (_isPulling) return;
    if (storage.coupleCode == null) return;
    if (!_isOnline) return;
    _isPulling = true;
    try {
      _log.info('Pull', 'force refresh...');
      final remote = await _supabase
          .from('couples')
          .select('data, version')
          .eq('code', storage.coupleCode!)
          .maybeSingle()
          .timeout(const Duration(seconds: 20));
      if (remote == null) return;
      final remoteVersion = (remote['version'] as int?) ?? 0;
      final remoteData = Map<String, dynamic>.from(remote['data'] as Map? ?? {});
      _isRemoteUpdate = true;
      _applyData(remoteData);
      storage.serverVersion = remoteVersion;
      _isRemoteUpdate = false;
      _setStatus('online');
      _notifyAll();
      _log.info('Pull', 'force refresh до v$remoteVersion');
    } catch (e, st) {
      _log.error('Pull', 'forcePullNow FAILED', e, st);
    } finally {
      _isPulling = false;
    }
  }

  void _applyData(Map<String, dynamic> data) {
    _mergeList<Purchase>(
      data, 'purchases',
      localItems: storage.purchases,
      fromJson: (j) => Purchase.fromJson(j),
      toJson: (i) => i.toJson(),
      getUpdatedAt: (i) => i.updatedAt,
      onMerged: (items) => storage.purchases = items,
    );
    _mergeList<Task>(
      data, 'tasks',
      localItems: storage.tasks,
      fromJson: (j) => Task.fromJson(j),
      toJson: (i) => i.toJson(),
      getUpdatedAt: (i) => i.updatedAt,
      onMerged: (items) => storage.tasks = items,
    );
    _mergeList<Shift>(
      data, 'shifts',
      localItems: storage.shifts,
      fromJson: (j) => Shift.fromJson(j),
      toJson: (i) => i.toJson(),
      getUpdatedAt: (i) => i.updatedAt,
      onMerged: (items) => storage.shifts = items,
    );
    _mergeList<Transaction>(
      data, 'transactions',
      localItems: storage.transactions,
      fromJson: (j) => Transaction.fromJson(j),
      toJson: (i) => i.toJson(),
      getUpdatedAt: (i) => i.updatedAt,
      onMerged: (items) => storage.transactions = items,
    );

    _replacePurchaseLists(data);
    _replacePurchaseCategories(data);
    _replaceTaskCategories(data);
    _replaceShiftTypes(data);
    _replacePartners(data);
    _replaceBudgetCategories(data);

    final profiles = data['profiles'] as Map?;
    if (profiles != null && storage.myKey != null) {
      final myProfile = profiles[storage.myKey!] as Map?;
      if (myProfile != null) {
        storage.myName = (myProfile['name'] as String?) ?? '';
      }
      for (final entry in profiles.entries) {
        if (entry.key == storage.myKey) continue;
        final profile = entry.value as Map?;
        if (profile != null) {
          final name = profile['name'] as String?;
          if (name != null && name.isNotEmpty) storage.partnerName = name;
        }
      }
    }
  }

  void _mergeList<T>(
    Map<String, dynamic> data,
    String key, {
    required List<T> localItems,
    required T Function(Map<String, dynamic>) fromJson,
    required Map<String, dynamic> Function(T) toJson,
    required int Function(T) getUpdatedAt,
    required void Function(List<T>) onMerged,
  }) {
    final raw = data[key];
    if (raw == null) return;
    try {
      final remoteMap = raw as Map;
      final localById = <String, T>{};
      for (final item in localItems) {
        final json = toJson(item);
        final id = json['id']?.toString();
        if (id != null) localById[id] = item;
      }
      final merged = <String, T>{};
      for (final entry in remoteMap.entries) {
        final id = entry.key.toString();
        final remoteJson = Map<String, dynamic>.from(entry.value as Map);
        final remoteItem = fromJson(remoteJson);
        if (remoteJson['deletedAt'] != null) continue;
        final localItem = localById[id];
        if (localItem == null) {
          merged[id] = remoteItem;
        } else if (getUpdatedAt(remoteItem) > getUpdatedAt(localItem)) {
          merged[id] = remoteItem;
        } else {
          merged[id] = localItem;
        }
      }
      for (final entry in localById.entries) {
        if (!merged.containsKey(entry.key)) {
          if (remoteMap[entry.key] == null) merged[entry.key] = entry.value;
        }
      }
      onMerged(merged.values.toList());
    } catch (e, st) {
      _log.error('Sync', 'merge $key FAILED', e, st);
    }
  }

  void _replacePurchaseLists(Map<String, dynamic> data) {
    final raw = data['purchaseLists'];
    if (raw == null) return;
    try {
      final list = (raw as Map)
          .values
          .map((v) => PurchaseList.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();
      if (list.isNotEmpty) storage.purchaseLists = list;
    } catch (e) {}
  }

  void _replacePurchaseCategories(Map<String, dynamic> data) {
    final raw = data['purchaseCategories'];
    if (raw == null) return;
    try {
      final list = (raw as Map)
          .values
          .map((v) => PurchaseCategory.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();
      if (list.isNotEmpty) storage.purchaseCategories = list;
    } catch (e) {}
  }

  void _replaceTaskCategories(Map<String, dynamic> data) {
    final raw = data['taskCategories'];
    if (raw == null) return;
    try {
      final list = (raw as Map)
          .values
          .map((v) => TaskCategory.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();
      if (list.isNotEmpty) storage.taskCategories = list;
    } catch (e) {}
  }

  void _replaceShiftTypes(Map<String, dynamic> data) {
    final raw = data['shiftTypes'];
    if (raw == null) return;
    try {
      final list = (raw as Map)
          .values
          .map((v) => ShiftType.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();
      if (list.isNotEmpty) storage.shiftTypes = list;
    } catch (e) {}
  }

  void _replacePartners(Map<String, dynamic> data) {
    final raw = data['partners'];
    if (raw == null) return;
    try {
      final list = (raw as Map)
          .values
          .map((v) => Partner.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();
      if (list.isNotEmpty) storage.partners = list;
    } catch (e) {}
  }

  void _replaceBudgetCategories(Map<String, dynamic> data) {
    final raw = data['budgetCategories'];
    if (raw == null) return;
    try {
      final list = (raw as Map)
          .values
          .map((v) => BudgetCategory.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();
      if (list.isNotEmpty) storage.budgetCategories = list;
    } catch (e) {}
  }

  void schedulePush() {
    if (storage.coupleCode == null) return;
    if (_isRemoteUpdate) return;
    if (_isFirstLoad) return;

    if (!_isOnline) {
      _pendingPush = true;
      _setStatus('offline');
      return;
    }
    _setStatus('syncing');
    _pushDebounce?.cancel();
    _pushDebounce = Timer(const Duration(milliseconds: 800), _push);
  }

  Future<void> _push() async {
    if (_isPushInProgress) return;
    if (storage.coupleCode == null) return;
    if (!_isOnline) {
      _pendingPush = true;
      return;
    }
    _isPushInProgress = true;
    try {
      final remote = await _supabase
          .from('couples')
          .select('data, version')
          .eq('code', storage.coupleCode!)
          .maybeSingle()
          .timeout(const Duration(seconds: 30));
      if (remote == null) return;
      final remoteData = Map<String, dynamic>.from(remote['data'] as Map? ?? {});
      final remoteVersion = (remote['version'] as int?) ?? 0;
      if (remoteVersion > storage.serverVersion) {
        _isRemoteUpdate = true;
        _applyData(remoteData);
        storage.serverVersion = remoteVersion;
        _isRemoteUpdate = false;
        _notifyAll();
      }
      final myData = storage.snapshot();
      myData['profiles'] = remoteData['profiles'] ?? {};
      if (storage.myKey != null) {
        final profiles = Map<String, dynamic>.from(myData['profiles'] as Map);
        final myProfile = Map<String, dynamic>.from(
            profiles[storage.myKey] as Map? ?? <String, dynamic>{});
        myProfile['name'] = storage.myName;
        profiles[storage.myKey!] = myProfile;
        myData['profiles'] = profiles;
      }
      final newVersion = remoteVersion + 1;
      await _supabase.from('couples').update({
        'data': myData,
        'version': newVersion,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'updated_by': storage.currentUserId,
      }).eq('code', storage.coupleCode!).timeout(const Duration(seconds: 30));
      storage.serverVersion = newVersion;
      _setStatus('online');
    } catch (e, st) {
      _log.error('Push', 'FAILED', e, st);
      _pendingPush = true;
      _setStatus('error');
    } finally {
      _isPushInProgress = false;
    }
  }

  Future<void> disconnect() async {
    _channel?.unsubscribe();
    _channel = null;
    _pullTimer?.cancel();
    _reconnectTimer?.cancel();
    _netSub?.cancel();
    _netSub = null;
    await _supabase.auth.signOut();
    await storage.clearAll();
    _setStatus('offline');
  }

  void _setStatus(String s) {
    if (_status == s) return;
    _status = s;
    onStatusChanged?.call();
  }
}