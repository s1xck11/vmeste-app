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
import '../models/bank.dart';
import '../models/recurring_payment.dart';
import '../models/purchase_template.dart';
import '../models/purchase_history_entry.dart';
import 'storage_service.dart';
import 'debug_log_service.dart';
import 'widget_service.dart';

typedef VoidCallback = void Function();

class SyncService {
  final StorageService storage;
  WidgetService? widgetService;
  final SupabaseClient _supabase = Supabase.instance.client;
  final _log = DebugLogService();
  final _connectivity = Connectivity();

  RealtimeChannel? _channel;
  Timer? _pushDebounce;
  Timer? _pullTimer;
  Timer? _reconnectTimer;
  Timer? _antiEntropyTimer;  // НОВОЕ: полная сверка раз в 12 часов
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
    widgetService?.updateAll();
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
      _startAntiEntropyTimer();  // НОВОЕ
      pullNow().then((_) {
        if (_pendingPush) {
          _pendingPush = false;
          _log.info('Network', 'отправляю отложенные изменения');
          schedulePush();
        }
      });
    } else {
      _setStatus('offline');
      _antiEntropyTimer?.cancel();
    }
  }

  // ============================================================
  // АУТЕНТИФИКАЦИЯ И ГРУППЫ
  // ============================================================

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

  Future<Map<String, String>> createGroup() async {
    final uid = await signInAnonymously();
    final myKey = _generateKey();
    String code;
    int attempts = 0;
    do {
      code = _generateGroupCode();
      final existing = await _supabase.from('couples').select('code').eq('code', code).maybeSingle().timeout(const Duration(seconds: 30));
      if (existing == null) break;
      attempts++;
    } while (attempts < 5);

    final profiles = {myKey: {'key': myKey, 'role': 'partner1', 'name': '', 'uids': [uid]}};
    final initialVectorClock = {'partner1': 0, 'partner2': 0};

    await _supabase.from('couples').insert({
      'code': code, 'members': [uid],
      'data': {...storage.snapshot(), 'profiles': profiles, 'vectorClock': initialVectorClock},
      'version': 1, 'updated_by': uid,
    }).timeout(const Duration(seconds: 30));

    storage.coupleCode = code;
    storage.members = [uid];
    storage.vectorClock = initialVectorClock;
    storage.myKey = myKey;
    storage.myPartnerId = 'partner1';

    _setStatus('online');
    _isFirstLoad = false;
    _subscribe();
    _startPullTimer();
    _startAntiEntropyTimer();
    _startWatchingNetwork();
    await migrateToVectorClock();
    return {'code': code, 'myKey': myKey};
  }

  Future<String> joinGroup(String code) async {
    code = code.trim().toUpperCase();
    final uid = await signInAnonymously();
    final group = await _supabase.from('couples').select().eq('code', code).maybeSingle().timeout(const Duration(seconds: 30));
    if (group == null) throw Exception('Группа не найдена');
    final data = Map<String, dynamic>.from(group['data'] as Map? ?? {});
    final profiles = Map<String, dynamic>.from(data['profiles'] as Map? ?? {});

    String? foundRole, foundKey;
    for (final entry in profiles.entries) {
      final profile = Map<String, dynamic>.from(entry.value as Map);
      final uids = List<String>.from(profile['uids'] as List? ?? []);
      if (uids.isEmpty) { foundRole = profile['role'] as String?; foundKey = entry.key; break; }
    }

    String myRole, myKey;
    if (foundRole != null && foundKey != null) {
      myRole = foundRole; myKey = foundKey;
    } else {
      final existingRoles = profiles.values.map((p) => (p as Map)['role'] as String?).where((r) => r != null).toSet();
      if (existingRoles.contains('partner1') && existingRoles.contains('partner2')) {
        throw Exception('В группе уже 2 участника');
      }
      myRole = existingRoles.contains('partner1') ? 'partner2' : 'partner1';
      myKey = _generateKey();
      profiles[myKey] = {'key': myKey, 'role': myRole, 'name': '', 'uids': <String>[]};
    }

    final myProfile = Map<String, dynamic>.from(profiles[myKey] as Map);
    final uids = List<String>.from(myProfile['uids'] as List? ?? []);
    if (!uids.contains(uid)) uids.add(uid);
    myProfile['uids'] = uids;
    profiles[myKey] = myProfile;
    final members = List<String>.from(group['members'] as List? ?? []);
    if (!members.contains(uid)) members.add(uid);
    data['profiles'] = profiles;

    // Инициализация vector clock если его нет
    if (data['vectorClock'] == null) {
      data['vectorClock'] = {'partner1': 0, 'partner2': 0};
    }

    await _supabase.from('couples').update({'members': members, 'data': data}).eq('code', code).timeout(const Duration(seconds: 30));

    storage.coupleCode = code;
    storage.members = members;
    storage.myKey = myKey;
    storage.myPartnerId = myRole;
    storage.vectorClock = Map<String, int>.from(data['vectorClock'] as Map);

    _isRemoteUpdate = true;
    _applyData(data);
    _isRemoteUpdate = false;

    _setStatus('online');
    _isFirstLoad = false;
    _subscribe();
    _startPullTimer();
    _startAntiEntropyTimer();
    _startWatchingNetwork();
    await migrateToVectorClock();
    return myKey;
  }

  Future<void> restoreByKey(String key) async {
    final code = storage.coupleCode;
    if (code == null || code.isEmpty) throw Exception('Нет кода группы');
    key = key.trim().toUpperCase();
    final uid = await signInAnonymously();
    final group = await _supabase.from('couples').select().eq('code', code).maybeSingle().timeout(const Duration(seconds: 30));
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
    await _supabase.from('couples').update({'members': members, 'data': data}).eq('code', code).timeout(const Duration(seconds: 30));
    storage.members = members;
    storage.myKey = key;
    storage.myPartnerId = myProfile['role'] as String;
    storage.myName = (myProfile['name'] as String?) ?? '';
    storage.vectorClock = Map<String, int>.from(data['vectorClock'] as Map);
    _isRemoteUpdate = true;
    _applyData(data);
    _isRemoteUpdate = false;
    _setStatus('online');
    _isFirstLoad = false;
    _subscribe();
    _startPullTimer();
    _startAntiEntropyTimer();
    _startWatchingNetwork();
    _notifyAll();
    await migrateToVectorClock();
  }

  Future<bool> autoConnect() async {
    final code = storage.coupleCode;
    final key = storage.myKey;
    if (code == null || code.isEmpty || key == null) return false;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        _setStatus('syncing');
        final uid = await signInAnonymously();
        final group = await _supabase.from('couples').select().eq('code', code).maybeSingle().timeout(const Duration(seconds: 30));
        if (group == null) {
          storage.coupleCode = null;
          storage.myKey = null;
          _setStatus('offline');
          return false;
        }
        final data = Map<String, dynamic>.from(group['data'] as Map? ?? {});
        final profiles = Map<String, dynamic>.from(data['profiles'] as Map? ?? {});
        if (!profiles.containsKey(key)) { _setStatus('offline'); return false; }

        final myProfile = Map<String, dynamic>.from(profiles[key] as Map);
        final uids = List<String>.from(myProfile['uids'] as List? ?? []);
        if (!uids.contains(uid)) {
          uids.add(uid);
          myProfile['uids'] = uids;
          profiles[key] = myProfile;
          final members = List<String>.from(group['members'] as List? ?? []);
          if (!members.contains(uid)) members.add(uid);
          data['profiles'] = profiles;
          await _supabase.from('couples').update({'members': members, 'data': data}).eq('code', code).timeout(const Duration(seconds: 30));
          storage.members = members;
        }

        storage.myPartnerId = myProfile['role'] as String;
        storage.myName = (myProfile['name'] as String?) ?? '';
        storage.vectorClock = Map<String, int>.from(data['vectorClock'] as Map);
        _isRemoteUpdate = true;
        _applyData(data);
        _isRemoteUpdate = false;
        _setStatus('online');
        _isFirstLoad = false;
        _subscribe();
        _startPullTimer();
        _startAntiEntropyTimer();
        _startWatchingNetwork();
        _notifyAll();
        await migrateToVectorClock();
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

  // ============================================================
  // REALTIME ПОДПИСКА
  // ============================================================

  void _subscribe() {
    final code = storage.coupleCode;
    if (code == null) return;
    if (!_isOnline) return;
    _channel?.unsubscribe();
    _channel = _supabase
        .channel('couple:$code')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'couples',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'code', value: code),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isEmpty) return;
            final newData = Map<String, dynamic>.from(newRecord['data'] as Map? ?? {});
            final remoteClock = Map<String, int>.from(newData['vectorClock'] as Map? ?? {});
            _log.info('Realtime', 'обновление clock=$remoteClock');
            _isRemoteUpdate = true;
            _applyData(newData);
            storage.applyRemoteClock(remoteClock);
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
      if (!_isOnline) {
        _log.info('Realtime', 'офлайн — откладываю переподписку');
        return;
      }
      _log.info('Realtime', 'переподключаюсь...');
      _subscribe();
    });
  }

  // ============================================================
  // PULL (получение изменений)
  // ============================================================

  void _startPullTimer() {
    _pullTimer?.cancel();
    _pullTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isOnline) pullNow();
    });
  }

  void _startAntiEntropyTimer() {
    _antiEntropyTimer?.cancel();
    _antiEntropyTimer = Timer.periodic(const Duration(hours: 12), (_) {
      if (_isOnline) {
        _log.info('AntiEntropy', 'полная сверка данных');
        _fullSync();
      }
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
      final remoteData = Map<String, dynamic>.from(remote['data'] as Map? ?? {});
      final remoteClock = Map<String, int>.from(remoteData['vectorClock'] as Map? ?? {});

      _log.info('Pull', 'remote clock=$remoteClock, local clock=${storage.vectorClock}');

      _isRemoteUpdate = true;
      _applyData(remoteData);
      storage.applyRemoteClock(remoteClock);
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
      final remoteData = Map<String, dynamic>.from(remote['data'] as Map? ?? {});
      final remoteClock = Map<String, int>.from(remoteData['vectorClock'] as Map? ?? {});

      _isRemoteUpdate = true;
      _applyData(remoteData);
      storage.applyRemoteClock(remoteClock);
      _isRemoteUpdate = false;
      _setStatus('online');
      _notifyAll();
      _log.info('Pull', 'force refresh done');
    } catch (e, st) {
      _log.error('Pull', 'forcePullNow FAILED', e, st);
    } finally {
      _isPulling = false;
    }
  }

  // Полная сверка (anti-entropy)
  Future<void> _fullSync() async {
    if (_isPulling || !_isOnline) return;
    _isPulling = true;
    try {
      _log.info('AntiEntropy', 'начинаю полную сверку');
      final remote = await _supabase
          .from('couples')
          .select('data')
          .eq('code', storage.coupleCode!)
          .maybeSingle()
          .timeout(const Duration(seconds: 30));
      if (remote == null) return;

      final remoteData = Map<String, dynamic>.from(remote['data'] as Map? ?? {});
      final remoteClock = Map<String, int>.from(remoteData['vectorClock'] as Map? ?? {});

      // Применяем все удалённые данные
      _isRemoteUpdate = true;
      _applyData(remoteData);
      storage.applyRemoteClock(remoteClock);
      _isRemoteUpdate = false;

      // Отправляем свои изменения
      await _push();

      _log.info('AntiEntropy', 'полная сверка завершена');
      _setStatus('online');
      _notifyAll();
    } catch (e, st) {
      _log.error('AntiEntropy', 'FAILED', e, st);
    } finally {
      _isPulling = false;
    }
  }

  // ============================================================
  // ПРИМЕНЕНИЕ ДАННЫХ (с tombstones)
  // ============================================================

  void _applyData(Map<String, dynamic> data) {
    // Применяем tombstones из удалённых данных
    final remoteTombstones = data['tombstones'] as Map?;
    if (remoteTombstones != null) {
      for (final entry in remoteTombstones.entries) {
        final tombstoneData = Map<String, dynamic>.from(entry.value as Map);
        final entityType = tombstoneData['entityType'] as String;
        final entityId = tombstoneData['entityId'] as String;
        final deletedAt = tombstoneData['deletedAt'] as int;
        final deletedBy = tombstoneData['deletedBy'] as String;

        // Проверяем, есть ли локальный tombstone
        final localTombstone = storage.getTombstone(entityType, entityId);
        if (localTombstone != null) {
          // Если удалённый tombstone новее, используем его
          if (deletedAt > (localTombstone['deletedAt'] as int)) {
            storage.addTombstone(entityType, entityId, deletedAt, deletedBy);
          }
        } else {
          // Локального tombstone нет, добавляем удалённый
          storage.addTombstone(entityType, entityId, deletedAt, deletedBy);
        }
      }
    }

    // Сливаем списки с учётом tombstones
    _mergeList<Purchase>(data, 'purchases', localItems: storage.purchases, fromJson: (j) => Purchase.fromJson(j), toJson: (i) => i.toJson(), getUpdatedAt: (i) => i.updatedAt, onMerged: (items) => storage.purchases = items);
    _mergeList<Task>(data, 'tasks', localItems: storage.tasks, fromJson: (j) => Task.fromJson(j), toJson: (i) => i.toJson(), getUpdatedAt: (i) => i.updatedAt, onMerged: (items) => storage.tasks = items);
    _mergeList<Shift>(data, 'shifts', localItems: storage.shifts, fromJson: (j) => Shift.fromJson(j), toJson: (i) => i.toJson(), getUpdatedAt: (i) => i.updatedAt, onMerged: (items) => storage.shifts = items);
    _mergeList<Transaction>(data, 'transactions', localItems: storage.transactions, fromJson: (j) => Transaction.fromJson(j), toJson: (i) => i.toJson(), getUpdatedAt: (i) => i.updatedAt, onMerged: (items) => storage.transactions = items);
    _mergeList<PurchaseTemplate>(data, 'purchaseTemplates', localItems: storage.purchaseTemplates, fromJson: (j) => PurchaseTemplate.fromJson(j), toJson: (i) => i.toJson(), getUpdatedAt: (i) => i.updatedAt, onMerged: (items) => storage.purchaseTemplates = items);
    _mergeList<RecurringPayment>(data, 'recurringPayments', localItems: storage.recurringPayments, fromJson: (j) => RecurringPayment.fromJson(j), toJson: (i) => i.toJson(), getUpdatedAt: (i) => i.updatedAt, onMerged: (items) => storage.recurringPayments = items);

    _replacePurchaseLists(data);
    _replacePurchaseCategories(data);
    _replaceTaskCategories(data);
    _replaceShiftTypes(data);
    _replacePartners(data);
    _replaceBudgetCategories(data);
    _replaceHistory(data);
    _replaceBanks(data);

    final profiles = data['profiles'] as Map?;
    if (profiles != null && storage.myKey != null) {
      final myProfile = profiles[storage.myKey!] as Map?;
      if (myProfile != null) storage.myName = (myProfile['name'] as String?) ?? '';
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

  void _mergeList<T>(Map<String, dynamic> data, String key, {required List<T> localItems, required T Function(Map<String, dynamic>) fromJson, required Map<String, dynamic> Function(T) toJson, required int Function(T) getUpdatedAt, required void Function(List<T>) onMerged}) {
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

      // Проходим по удалённым элементам
      for (final entry in remoteMap.entries) {
        final id = entry.key.toString();
        final remoteJson = Map<String, dynamic>.from(entry.value as Map);

        // ПРОВЕРКА TOMBSTONE: если элемент удалён, пропускаем его
        if (remoteJson['deletedAt'] != null) {
          // Добавляем tombstone локально
          final deletedAt = remoteJson['deletedAt'] as int;
          final deletedBy = remoteJson['deletedBy'] as String? ?? 'unknown';
          storage.addTombstone(key, id, deletedAt, deletedBy);
          continue;  // НЕ добавляем в merged
        }

        // Проверяем, есть ли локальный tombstone
        if (storage.isTombstoned(key, id)) {
          final localTombstone = storage.getTombstone(key, id)!;
          final localDeletedAt = localTombstone['deletedAt'] as int;
          final remoteDeletedAt = remoteJson['deletedAt'] as int? ?? 0;

          // Если локально удалено раньше, чем удалённое изменение — удаляем
          if (localDeletedAt <= remoteDeletedAt) {
            continue;  // Tombstone побеждает
          }
        }

        final remoteItem = fromJson(remoteJson);
        final localItem = localById[id];

        if (localItem == null) {
          merged[id] = remoteItem;
        } else {
          // Last-Writer-Wins по updatedAt
          if (getUpdatedAt(remoteItem) > getUpdatedAt(localItem)) {
            merged[id] = remoteItem;
          } else {
            merged[id] = localItem;
          }
        }
      }

      // Добавляем локальные элементы, которых нет на сервере
      for (final entry in localById.entries) {
        if (!merged.containsKey(entry.key) && remoteMap[entry.key] == null) {
          // Проверяем tombstone
          if (!storage.isTombstoned(key, entry.key)) {
            merged[entry.key] = entry.value;
          }
        }
      }

      onMerged(merged.values.toList());
    } catch (e, st) { _log.error('Sync', 'merge $key FAILED', e, st); }
  }

  void _replacePurchaseLists(Map<String, dynamic> data) {
    final raw = data['purchaseLists']; if (raw == null) return;
    try {
      final list = (raw as Map).values.map((v) => PurchaseList.fromJson(Map<String, dynamic>.from(v as Map))).toList();
      if (list.isNotEmpty) storage.purchaseLists = list;
    } catch (e) {}
  }

  void _replacePurchaseCategories(Map<String, dynamic> data) {
    final raw = data['purchaseCategories']; if (raw == null) return;
    try {
      final list = (raw as Map).values.map((v) => PurchaseCategory.fromJson(Map<String, dynamic>.from(v as Map))).toList();
      if (list.isNotEmpty) storage.purchaseCategories = list;
    } catch (e) {}
  }

  void _replaceTaskCategories(Map<String, dynamic> data) {
    final raw = data['taskCategories']; if (raw == null) return;
    try {
      final list = (raw as Map).values.map((v) => TaskCategory.fromJson(Map<String, dynamic>.from(v as Map))).toList();
      if (list.isNotEmpty) storage.taskCategories = list;
    } catch (e) {}
  }

  void _replaceShiftTypes(Map<String, dynamic> data) {
    final raw = data['shiftTypes']; if (raw == null) return;
    try {
      final list = (raw as Map).values.map((v) => ShiftType.fromJson(Map<String, dynamic>.from(v as Map))).toList();
      if (list.isNotEmpty) storage.shiftTypes = list;
    } catch (e) {}
  }

  void _replacePartners(Map<String, dynamic> data) {
    final raw = data['partners']; if (raw == null) return;
    try {
      final list = (raw as Map).values.map((v) => Partner.fromJson(Map<String, dynamic>.from(v as Map))).toList();
      if (list.isNotEmpty) storage.partners = list;
    } catch (e) {}
  }

  void _replaceBudgetCategories(Map<String, dynamic> data) {
    final raw = data['budgetCategories']; if (raw == null) return;
    try {
      final list = (raw as Map).values.map((v) => BudgetCategory.fromJson(Map<String, dynamic>.from(v as Map))).toList();
      if (list.isNotEmpty) storage.budgetCategories = list;
    } catch (e) {}
  }

  void _replaceHistory(Map<String, dynamic> data) {
    final raw = data['purchaseHistory']; if (raw == null) return;
    try {
      final list = (raw as List).map((e) => PurchaseHistoryEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      if (list.isNotEmpty) storage.purchaseHistory = list;
    } catch (e) {}
  }

  void _replaceBanks(Map<String, dynamic> data) {
    final raw = data['banks']; if (raw == null) return;
    try {
      final list = (raw as Map).values.map((v) => Bank.fromJson(Map<String, dynamic>.from(v as Map))).toList();
      if (list.isNotEmpty) storage.banks = list;
    } catch (e) {}
  }

  // ============================================================
  // PUSH (отправка изменений)
  // ============================================================

  void schedulePush() {
    if (storage.coupleCode == null) return;
    if (_isRemoteUpdate) return;
    if (_isFirstLoad) return;

    if (!_isOnline) {
      _pendingPush = true;
      _log.info('Sync', 'офлайн — изменения ждут отправки');
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
      // Получаем текущие данные с сервера
      final remote = await _supabase.from('couples').select('data, version').eq('code', storage.coupleCode!).maybeSingle().timeout(const Duration(seconds: 30));
      if (remote == null) return;
      final remoteData = Map<String, dynamic>.from(remote['data'] as Map? ?? {});
      final remoteClock = Map<String, int>.from(remoteData['vectorClock'] as Map? ?? {});

      // Применяем удалённые изменения если они новее
      _isRemoteUpdate = true;
      _applyData(remoteData);
      storage.applyRemoteClock(remoteClock);
      _isRemoteUpdate = false;
      _notifyAll();

      // Формируем snapshot с нашими данными
      final myData = storage.snapshot();
      myData['profiles'] = remoteData['profiles'] ?? {};
      if (storage.myKey != null) {
        final profiles = Map<String, dynamic>.from(myData['profiles'] as Map);
        final myProfile = Map<String, dynamic>.from(profiles[storage.myKey] as Map? ?? <String, dynamic>{});
        myProfile['name'] = storage.myName;
        profiles[storage.myKey!] = myProfile;
        myData['profiles'] = profiles;
      }

      // Инкрементируем vector clock
      final myPartnerId = storage.myPartnerId ?? 'partner1';
      final newClock = Map<String, int>.from(storage.vectorClock);
      newClock[myPartnerId] = (newClock[myPartnerId] ?? 0) + 1;
      myData['vectorClock'] = newClock;

      final newVersion = (remote['version'] as int? ?? 0) + 1;
      await _supabase.from('couples').update({
        'data': myData, 'version': newVersion,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'updated_by': storage.currentUserId,
      }).eq('code', storage.coupleCode!).timeout(const Duration(seconds: 30));

      storage.vectorClock = newClock;
      _setStatus('online');
      widgetService?.updateAll();

      // Очищаем отправленные операции из outbox
      storage.clearSentOperations();
    } catch (e, st) {
      _log.error('Push', 'FAILED', e, st);
      _pendingPush = true;
      _setStatus('error');
    } finally { _isPushInProgress = false; }
  }

  // ============================================================
  // УТИЛИТЫ
  // ============================================================
  // ============================================================
  // МИГРАЦИЯ V2: Vector Clock + Tombstones
  // ============================================================

  Future<void> migrateToVectorClock() async {
    // Проверяем флаг миграции
    if (storage.box.get('migration_v2_vector_clock_done') == true) {
      return; // Уже мигрировано, выходим
    }

    _log.info('Migration', '🚀 Начало миграции V2 (Vector Clock + Tombstones)...');

    try {
      // 1. Забираем абсолютную правду с сервера, чтобы синхронизировать состояние
      _log.info('Migration', 'Шаг 1: Получение актуальных данных с сервера...');
      await forcePullNow();

      // 2. Безопасная инициализация Vector Clock.
      // Мы берем старый serverVersion как базовую линию для ОБОИХ партнеров.
      // Например, если версия была 15, ставим {partner1: 15, partner2: 15}.
      // Следующее локальное изменение сделает его 16, что строго больше
      // последнего известного состояния сервера, предотвращая конфликты перезаписи.
      final baseline = storage.serverVersion > 0 ? storage.serverVersion : 1;
      final newClock = {
        'partner1': baseline,
        'partner2': baseline,
      };
      storage.vectorClock = newClock;
      _log.info('Migration', 'Шаг 2: Vector Clock инициализирован как $newClock');

      // 3. Конвертация старых "мягких удалений" в полноценные tombstones
      _log.info('Migration', 'Шаг 3: Очистка старых удаленных элементов...');
      _migrateSoftDeletesToTombstones();

      // 4. Отправляем новую структуру (с vectorClock и tombstones) на сервер
      _log.info('Migration', 'Шаг 4: Отправка обновленной структуры на сервер...');
      await _push();

      // 5. Ставим флаг завершения
      storage.box.put('migration_v2_vector_clock_done', true);
      _log.info('Migration', '✅ Миграция V2 успешно завершена!');

    } catch (e, st) {
      _log.error('Migration', '❌ Ошибка миграции. Будет повторена при следующем запуске.', e, st);
      // Мы НЕ ставим флаг 'migration_v2_vector_clock_done', чтобы миграция
      // попробовала выполниться снова при следующем запуске приложения.
    }
  }

  void _migrateSoftDeletesToTombstones() {
    final actor = storage.myPartnerId ?? 'unknown';

    // 1. Покупки (Purchase)
    final activePurchases = <Purchase>[];
    for (final p in storage.purchases) {
      if (p.deletedAt != null) {
        storage.addTombstone('purchases', p.id.toString(), p.deletedAt!, actor);
      } else {
        activePurchases.add(p);
      }
    }
    storage.purchases = activePurchases;

    // 2. Задачи (Task) - используем флаг archived как признак удаления для очистки
    final activeTasks = <Task>[];
    for (final t in storage.tasks) {
      if (t.archived) {
        storage.addTombstone('tasks', t.id.toString(), t.updatedAt, actor);
      } else {
        activeTasks.add(t);
      }
    }
    storage.tasks = activeTasks;

    // 3. Транзакции (Transaction) - если у них есть deletedAt
    final activeTransactions = <Transaction>[];
    for (final t in storage.transactions) {
      // Проверяем наличие deletedAt через динамический доступ, если поле есть в модели
      final deletedAt = (t as dynamic).deletedAt as int?;
      if (deletedAt != null) {
        storage.addTombstone('transactions', t.id.toString(), deletedAt, actor);
      } else {
        activeTransactions.add(t);
      }
    }
    storage.transactions = activeTransactions;
  }

  Future<void> disconnect() async {
    _channel?.unsubscribe();
    _channel = null;
    _pullTimer?.cancel();
    _antiEntropyTimer?.cancel();
    _reconnectTimer?.cancel();
    _netSub?.cancel();
    _netSub = null;
    await _supabase.auth.signOut();
    await storage.clearAll();
    _setStatus('offline');
  }

  String _generateGroupCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    final buffer = StringBuffer();
    for (int i = 0; i < 9; i++) {
      if (i == 3 || i == 6) buffer.write('-');
      buffer.write(chars[rand.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  String _generateKey() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    final buffer = StringBuffer();
    buffer.write(chars.substring(0, 26)[rand.nextInt(26)]);
    for (int i = 0; i < 8; i++) {
      if (i == 4) buffer.write('-');
      buffer.write(chars[rand.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  void _setStatus(String s) {
    if (_status == s) return;
    _status = s;
    onStatusChanged?.call();
  }
}
