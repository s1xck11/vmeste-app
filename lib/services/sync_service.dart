import 'dart:async';
import 'dart:math';
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

  RealtimeChannel? _channel;
  Timer? _pushDebounce;
  bool _isFirstLoad = true;
  bool _isRemoteUpdate = false;
  bool _isPushInProgress = false;

  VoidCallback? onDataChanged;
  VoidCallback? onStatusChanged;

  String _status = 'offline';
  String get status => _status;

  SyncService({required this.storage});

  // ============ АВТОРИЗАЦИЯ ============

  Future<String> signInAnonymously() async {
    _log.info('Auth', 'signInAnonymously: start');
    try {
      final existing = _supabase.auth.currentUser;
      if (existing != null) {
        _log.info('Auth', 'уже есть сессия: ${existing.id}');
        storage.currentUserId = existing.id;
        return existing.id;
      }

      _log.info('Auth', 'нет сессии, вызываем signInAnonymously...');
      final response = await _supabase.auth
          .signInAnonymously()
          .timeout(const Duration(seconds: 15));
      final user = response.user;
      if (user == null) {
        _log.error('Auth', 'вернулся null user');
        throw Exception('Не удалось войти анонимно');
      }
      _log.info('Auth', 'успех, uid=${user.id}');
      storage.currentUserId = user.id;
      return user.id;
    } catch (e, st) {
      _log.error('Auth', 'signInAnonymously FAILED', e, st);
      rethrow;
    }
  }

  // ============ СОЗДАНИЕ ГРУППЫ ============

  Future<Map<String, String>> createGroup() async {
    _log.info('Sync', 'createGroup: старт');
    final uid = await signInAnonymously();
    final myKey = _generateKey();
    _log.info('Sync', 'createGroup: сгенерирован ключ $myKey');

    String code;
    int attempts = 0;
    do {
      code = _generateGroupCode();
      final existing = await _supabase
          .from('couples')
          .select('code')
          .eq('code', code)
          .maybeSingle();
      if (existing == null) break;
      attempts++;
    } while (attempts < 5);
    _log.info('Sync', 'createGroup: код группы $code');

    final profiles = {
      myKey: {
        'key': myKey,
        'role': 'partner1',
        'name': '',
        'uids': [uid],
      },
    };

    try {
      await _supabase.from('couples').insert({
        'code': code,
        'members': [uid],
        'data': {
          ...storage.snapshot(),
          'profiles': profiles,
        },
        'version': 1,
        'updated_by': uid,
      });
      _log.info('Sync', 'createGroup: insert в Supabase успешно');
    } catch (e, st) {
      _log.error('Sync', 'createGroup: insert FAILED', e, st);
      rethrow;
    }

    storage.coupleCode = code;
    storage.members = [uid];
    storage.serverVersion = 1;
    storage.myKey = myKey;
    storage.myPartnerId = 'partner1';

    _setStatus('online');
    _isFirstLoad = false;
    _subscribe();

    return {'code': code, 'myKey': myKey};
  }

  // ============ ПРИСОЕДИНЕНИЕ ============

  Future<String> joinGroup(String code) async {
    code = code.trim().toUpperCase();
    _log.info('Sync', 'joinGroup: код $code');
    final uid = await signInAnonymously();

    final group = await _supabase
        .from('couples')
        .select()
        .eq('code', code)
        .maybeSingle();

    if (group == null) {
      _log.warn('Sync', 'joinGroup: группа не найдена');
      throw Exception('Группа не найдена');
    }
    _log.info('Sync', 'joinGroup: группа найдена, версия ${group['version']}');

    final data = Map<String, dynamic>.from(group['data'] as Map? ?? {});
    final profiles = Map<String, dynamic>.from(data['profiles'] as Map? ?? {});

    String? foundRole;
    String? foundKey;
    for (final entry in profiles.entries) {
      final profile = Map<String, dynamic>.from(entry.value as Map);
      final uids = List<String>.from(profile['uids'] as List? ?? []);
      if (uids.isEmpty) {
        foundRole = profile['role'] as String?;
        foundKey = entry.key;
        break;
      }
    }

    String myRole;
    String myKey;

    if (foundRole != null && foundKey != null) {
      myRole = foundRole;
      myKey = foundKey;
      _log.info('Sync', 'joinGroup: используем пустой слот $myKey');
    } else {
      final existingRoles = profiles.values
          .map((p) => (p as Map)['role'] as String?)
          .where((r) => r != null)
          .toSet();

      if (existingRoles.contains('partner1') && existingRoles.contains('partner2')) {
        _log.warn('Sync', 'joinGroup: оба слота заняты');
        throw Exception('В группе уже 2 участника. Войди по своему ключу.');
      }

      myRole = existingRoles.contains('partner1') ? 'partner2' : 'partner1';
      myKey = _generateKey();
      profiles[myKey] = {
        'key': myKey,
        'role': myRole,
        'name': '',
        'uids': <String>[],
      };
      _log.info('Sync', 'joinGroup: создан новый профиль $myKey ($myRole)');
    }

    final myProfile = Map<String, dynamic>.from(profiles[myKey] as Map);
    final uids = List<String>.from(myProfile['uids'] as List? ?? []);
    if (!uids.contains(uid)) uids.add(uid);
    myProfile['uids'] = uids;
    profiles[myKey] = myProfile;

    final members = List<String>.from(group['members'] as List? ?? []);
    if (!members.contains(uid)) members.add(uid);

    data['profiles'] = profiles;
    await _supabase.from('couples').update({
      'members': members,
      'data': data,
    }).eq('code', code);

    storage.coupleCode = code;
    storage.members = members;
    storage.myKey = myKey;
    storage.myPartnerId = myRole;
    storage.serverVersion = (group['version'] as int?) ?? 0;

    _isRemoteUpdate = true;
    _applyData(data);
    _isRemoteUpdate = false;

    _setStatus('online');
    _isFirstLoad = false;
    _subscribe();
    return myKey;
  }

  // ============ ВОССТАНОВЛЕНИЕ ПО КЛЮЧУ ============

  Future<void> restoreByKey(String key) async {
    final code = storage.coupleCode;
    if (code == null || code.isEmpty) {
      throw Exception('Сначала подключись к группе по её коду');
    }

    key = key.trim().toUpperCase();
    _log.info('Sync', 'restoreByKey: код=$code ключ=$key');
    final uid = await signInAnonymously();

    final group = await _supabase
        .from('couples')
        .select()
        .eq('code', code)
        .maybeSingle();

    if (group == null) throw Exception('Группа не найдена');

    final data = Map<String, dynamic>.from(group['data'] as Map? ?? {});
    final profiles = Map<String, dynamic>.from(data['profiles'] as Map? ?? {});

    if (!profiles.containsKey(key)) {
      _log.warn('Sync', 'restoreByKey: ключ не найден в profiles');
      throw Exception('Ключ не найден в этой группе');
    }

    final myProfile = Map<String, dynamic>.from(profiles[key] as Map);
    final uids = List<String>.from(myProfile['uids'] as List? ?? []);
    if (!uids.contains(uid)) uids.add(uid);
    myProfile['uids'] = uids;
    profiles[key] = myProfile;

    final members = List<String>.from(group['members'] as List? ?? []);
    if (!members.contains(uid)) members.add(uid);

    data['profiles'] = profiles;
    await _supabase.from('couples').update({
      'members': members,
      'data': data,
    }).eq('code', code);

    storage.members = members;
    storage.myKey = key;
    storage.myPartnerId = myProfile['role'] as String;
    storage.myName = (myProfile['name'] as String?) ?? '';

    _isRemoteUpdate = true;
    _applyData(data);
    _isRemoteUpdate = false;

    _setStatus('online');
    _isFirstLoad = false;
    _subscribe();
  }

  // ============ АВТОПОДКЛЮЧЕНИЕ ============

  Future<bool> autoConnect() async {
    final code = storage.coupleCode;
    final key = storage.myKey;
    _log.info('AutoConnect', 'старт: code=$code key=$key');

    if (code == null || code.isEmpty || key == null) {
      _log.warn('AutoConnect', 'не хватает данных (code/key), выходим');
      return false;
    }

    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        _log.info('AutoConnect', 'попытка $attempt/2: set status syncing');
        _setStatus('syncing');

        _log.info('AutoConnect', 'попытка $attempt: signInAnonymously...');
        final uid = await signInAnonymously();
        _log.info('AutoConnect', 'попытка $attempt: uid=$uid, идём в Supabase');

        _log.info('AutoConnect', 'попытка $attempt: select couples WHERE code=$code');
        final group = await _supabase
            .from('couples')
            .select()
            .eq('code', code)
            .maybeSingle()
            .timeout(const Duration(seconds: 15));

        if (group == null) {
          _log.warn('AutoConnect', 'попытка $attempt: группа не найдена');
          storage.coupleCode = null;
          storage.myKey = null;
          _setStatus('offline');
          return false;
        }
        _log.info('AutoConnect', 'попытка $attempt: группа найдена');

        final data = Map<String, dynamic>.from(group['data'] as Map? ?? {});
        final profiles = Map<String, dynamic>.from(data['profiles'] as Map? ?? {});

        if (!profiles.containsKey(key)) {
          _log.warn('AutoConnect', 'попытка $attempt: ключ $key отсутствует в profiles');
          _setStatus('offline');
          return false;
        }
        _log.info('AutoConnect', 'попытка $attempt: ключ найден в profiles');

        final myProfile = Map<String, dynamic>.from(profiles[key] as Map);
        final uids = List<String>.from(myProfile['uids'] as List? ?? []);
        if (!uids.contains(uid)) {
          uids.add(uid);
          myProfile['uids'] = uids;
          profiles[key] = myProfile;

          final members = List<String>.from(group['members'] as List? ?? []);
          if (!members.contains(uid)) members.add(uid);

          data['profiles'] = profiles;
          await _supabase.from('couples').update({
            'members': members,
            'data': data,
          }).eq('code', code);

          storage.members = members;
          _log.info('AutoConnect', 'обновили uids/members');
        }

        storage.myPartnerId = myProfile['role'] as String;
        storage.myName = (myProfile['name'] as String?) ?? '';
        storage.serverVersion = (group['version'] as int?) ?? 0;
        _log.info('AutoConnect', 'версия сервера=${storage.serverVersion}');

        _isRemoteUpdate = true;
        _applyData(data);
        _isRemoteUpdate = false;

        _setStatus('online');
        _isFirstLoad = false;
        _subscribe();
        _log.info('AutoConnect', '✅ успех, статус=online');
        return true;
      } catch (e, st) {
        _log.error('AutoConnect', 'попытка $attempt FAILED', e, st);
        if (attempt == 2) {
          _setStatus('offline');
          _isFirstLoad = false;
          return false;
        }
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    return false;
  }

  // ============ REALTIME ============

  void _subscribe() {
    final code = storage.coupleCode;
    if (code == null) return;
    _log.info('Realtime', 'подписка на code=$code');

    _channel?.unsubscribe();

    _channel = _supabase
        .channel('couple:$code')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'couples',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'code',
            value: code,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isEmpty) return;

            final newVersion = (newRecord['version'] as int?) ?? 0;
            if (newVersion <= storage.serverVersion) return;

            _log.info('Realtime', 'пришло обновление v$newVersion');
            final data = Map<String, dynamic>.from(newRecord['data'] as Map? ?? {});
            _isRemoteUpdate = true;
            _applyData(data);
            storage.serverVersion = newVersion;
            _isRemoteUpdate = false;

            _setStatus('online');
            onDataChanged?.call();
          },
        )
        .subscribe((status, error) {
          _log.info('Realtime', 'статус подписки: $status${error != null ? ' err=$error' : ''}');
          if (status == RealtimeSubscribeStatus.subscribed) {
            _setStatus('online');
          } else if (status == RealtimeSubscribeStatus.channelError) {
            _setStatus('error');
          } else if (status == RealtimeSubscribeStatus.timedOut) {
            _setStatus('offline');
          }
        });
  }

  void _applyData(Map<String, dynamic> data) {
    _mergeList<Purchase>(
      data, 'purchases',
      localItems: storage.purchases,
      fromJson: (j) => Purchase.fromJson(j),
      toJson: (item) => item.toJson(),
      getUpdatedAt: (item) => item.updatedAt,
      onMerged: (items) => storage.purchases = items,
    );
    _mergeList<Task>(
      data, 'tasks',
      localItems: storage.tasks,
      fromJson: (j) => Task.fromJson(j),
      toJson: (item) => item.toJson(),
      getUpdatedAt: (item) => item.updatedAt,
      onMerged: (items) => storage.tasks = items,
    );
    _mergeList<Shift>(
      data, 'shifts',
      localItems: storage.shifts,
      fromJson: (j) => Shift.fromJson(j),
      toJson: (item) => item.toJson(),
      getUpdatedAt: (item) => item.updatedAt,
      onMerged: (items) => storage.shifts = items,
    );
    _mergeList<Transaction>(
      data, 'transactions',
      localItems: storage.transactions,
      fromJson: (j) => Transaction.fromJson(j),
      toJson: (item) => item.toJson(),
      getUpdatedAt: (item) => item.updatedAt,
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
          if (name != null && name.isNotEmpty) {
            storage.partnerName = name;
          }
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

        final remoteDeleted = remoteJson['deletedAt'] != null;
        if (remoteDeleted) continue;

        final localItem = localById[id];
        if (localItem == null) {
          merged[id] = remoteItem;
        } else {
          if (getUpdatedAt(remoteItem) > getUpdatedAt(localItem)) {
            merged[id] = remoteItem;
          } else {
            merged[id] = localItem;
          }
        }
      }

      for (final entry in localById.entries) {
        if (!merged.containsKey(entry.key)) {
          final remoteRaw = remoteMap[entry.key];
          if (remoteRaw == null) {
            merged[entry.key] = entry.value;
          }
        }
      }

      onMerged(merged.values.toList());
    } catch (e, st) {
      _log.error('Sync', 'merge error for $key', e, st);
    }
  }

  void _replacePurchaseLists(Map<String, dynamic> data) {
    final raw = data['purchaseLists'];
    if (raw == null) return;
    try {
      final map = raw as Map;
      final list = map.values
          .map((v) => PurchaseList.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();
      if (list.isNotEmpty) storage.purchaseLists = list;
    } catch (e) {
      _log.error('Sync', 'replace purchaseLists error', e);
    }
  }

  void _replacePurchaseCategories(Map<String, dynamic> data) {
    final raw = data['purchaseCategories'];
    if (raw == null) return;
    try {
      final map = raw as Map;
      final list = map.values
          .map((v) => PurchaseCategory.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();
      if (list.isNotEmpty) storage.purchaseCategories = list;
    } catch (e) {
      _log.error('Sync', 'replace purchaseCategories error', e);
    }
  }

  void _replaceTaskCategories(Map<String, dynamic> data) {
    final raw = data['taskCategories'];
    if (raw == null) return;
    try {
      final map = raw as Map;
      final list = map.values
          .map((v) => TaskCategory.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();
      if (list.isNotEmpty) storage.taskCategories = list;
    } catch (e) {
      _log.error('Sync', 'replace taskCategories error', e);
    }
  }

  void _replaceShiftTypes(Map<String, dynamic> data) {
    final raw = data['shiftTypes'];
    if (raw == null) return;
    try {
      final map = raw as Map;
      final list = map.values
          .map((v) => ShiftType.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();
      if (list.isNotEmpty) storage.shiftTypes = list;
    } catch (e) {
      _log.error('Sync', 'replace shiftTypes error', e);
    }
  }

  void _replacePartners(Map<String, dynamic> data) {
    final raw = data['partners'];
    if (raw == null) return;
    try {
      final map = raw as Map;
      final list = map.values
          .map((v) => Partner.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();
      if (list.isNotEmpty) storage.partners = list;
    } catch (e) {
      _log.error('Sync', 'replace partners error', e);
    }
  }

  void _replaceBudgetCategories(Map<String, dynamic> data) {
    final raw = data['budgetCategories'];
    if (raw == null) return;
    try {
      final map = raw as Map;
      final list = map.values
          .map((v) => BudgetCategory.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();
      if (list.isNotEmpty) storage.budgetCategories = list;
    } catch (e) {
      _log.error('Sync', 'replace budgetCategories error', e);
    }
  }

  // ============ ОТПРАВКА ============

  void schedulePush() {
    if (storage.coupleCode == null) return;
    if (_isRemoteUpdate) return;
    if (_isFirstLoad) return;

    _setStatus('syncing');
    _pushDebounce?.cancel();
    _pushDebounce = Timer(const Duration(milliseconds: 1000), _push);
  }

  Future<void> _push() async {
    if (_isPushInProgress) return;
    if (storage.coupleCode == null) return;

    _isPushInProgress = true;
    try {
      _log.info('Push', 'push start');
      final remote = await _supabase
          .from('couples')
          .select('data, version')
          .eq('code', storage.coupleCode!)
          .maybeSingle();

      if (remote == null) {
        _log.warn('Push', 'группа не найдена на сервере');
        return;
      }

      final remoteData = Map<String, dynamic>.from(remote['data'] as Map? ?? {});
      final remoteVersion = (remote['version'] as int?) ?? 0;

      if (remoteVersion > storage.serverVersion) {
        _log.info('Push', 'на сервере свежее: v$remoteVersion > v${storage.serverVersion}');
        _isRemoteUpdate = true;
        _applyData(remoteData);
        storage.serverVersion = remoteVersion;
        _isRemoteUpdate = false;
        onDataChanged?.call();
      }

      final myData = storage.snapshot();
      myData['profiles'] = remoteData['profiles'] ?? {};

      if (storage.myKey != null) {
        final profiles = Map<String, dynamic>.from(myData['profiles'] as Map);
        final myProfile = Map<String, dynamic>.from(
          profiles[storage.myKey] as Map? ?? <String, dynamic>{},
        );
        myProfile['name'] = storage.myName;
        profiles[storage.myKey!] = myProfile;
        myData['profiles'] = profiles;
      }

      final newVersion = remoteVersion + 1;
      await _supabase
          .from('couples')
          .update({
            'data': myData,
            'version': newVersion,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
            'updated_by': storage.currentUserId,
          })
          .eq('code', storage.coupleCode!);

      storage.serverVersion = newVersion;
      _setStatus('online');
      _log.info('Push', 'push ok, v$newVersion');
    } catch (e, st) {
      _log.error('Push', 'push FAILED', e, st);
      _setStatus('error');
    } finally {
      _isPushInProgress = false;
    }
  }

  // ============ ОТКЛЮЧЕНИЕ ============

  Future<void> disconnect() async {
    _log.info('Sync', 'disconnect');
    _channel?.unsubscribe();
    _channel = null;
    await _supabase.auth.signOut();
    await storage.clearAll();
    _setStatus('offline');
  }

  // ============ УТИЛИТЫ ============

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
    _status = s;
    _log.info('Sync', 'статус → $s');
    onStatusChanged?.call();
  }
}