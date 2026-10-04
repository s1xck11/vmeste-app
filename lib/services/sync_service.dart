// lib/services/sync_service.dart

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
import '../models/purchase_template.dart';
import '../models/purchase_history_entry.dart';
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

  /// Анонимный вход с retry — важно для Huawei с нестабильной сетью.
  Future<String> signInAnonymously() async {
    final existing = _supabase.auth.currentUser;
    if (existing != null) {
      storage.currentUserId = existing.id;
      _log.info('Auth', 'уже есть сессия: ${existing.id}');
      return existing.id;
    }

    Exception? lastError;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        _log.info('Auth', 'попытка $attempt/3: signInAnonymously...');
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
        if (attempt < 3) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
    throw lastError ?? Exception('Не удалось войти после 3 попыток');
  }

  Future<Map<String, String>> createGroup() async {
    final uid = await signInAnonymously();
    final myKey = _generateKey();
    String code;
    int attempts = 0;
    do {
      code = _generateGroupCode();
      final existing = await _supabase
          .from('couples')
          .select('code')
          .eq('code', code)
          .maybeSingle()
          .timeout(const Duration(seconds: 30));
      if (existing == null) break;
      attempts++;
    } while (attempts < 5);
    final profiles = {
      myKey: {'key': myKey, 'role': 'partner1', 'name': '', 'uids': [uid]},
    };
    await _supabase.from('couples').insert({
      'code': code,
      'members': [uid],
      'data': {...storage.snapshot(), 'profiles': profiles},
      'version': 1,
      'updated_by': uid,
    }).timeout(const Duration(seconds: 30));
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

  Future<String> joinGroup(String code) async {
    code = code.trim().toUpperCase();
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
    String? foundRole, foundKey;
    for (final entry in profiles.entries) {
      final profile = Map<String, dynamic>.from(entry.value as Map);
      final uids = List<String>.from(profile['uids'] as List? ?? []);
      if (uids.isEmpty) { foundRole = profile['role'] as String?; foundKey = entry.key; break; }
    }
    String myRole, myKey;
    if (foundRole != null && foundKey != null) {
      myRole = foundRole;
      myKey = foundKey;
    } else {
      final existingRoles = profiles.values
          .map((p) => (p as Map)['role'] as String?)
          .where((r) => r != null)
          .toSet();
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
    await _supabase
        .from('couples')
        .update({'members': members, 'data': data})
        .eq('code', code)
        .timeout(const Duration(seconds: 30));
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

  Future<void> restoreByKey(String key) async {
    final code = storage.coupleCode;
    if (code == null || code.isEmpty) throw Exception('Нет кода группы');
    key = key.trim().toUpperCase();
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
    onDataChanged?.call();
    onStatusChanged?.call();
  }

  Future<bool> autoConnect() async {
    final code = storage.coupleCode;
    final key = storage.myKey;
    if (code == null || code.isEmpty || key == null) return false;
    for (int attempt = 1; attempt <= 2; attempt++) {
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
        onDataChanged?.call();
        onStatusChanged?.call();
        return true;
      } catch (e, st) {
        _log.error('AutoConnect', 'attempt $attempt FAILED', e, st);
        if (attempt == 2) { _setStatus('offline'); _isFirstLoad = false; return false; }
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    return false;
  }

  void _subscribe() {
    final code = storage.coupleCode;
    if (code == null) return;
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
            final newVersion = (newRecord['version'] as int?) ?? 0;
            if (newVersion <= storage.serverVersion) return;
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
          if (status == RealtimeSubscribeStatus.subscribed) _setStatus('online');
          else if (status == RealtimeSubscribeStatus.channelError) _setStatus('error');
          else if (status == RealtimeSubscribeStatus.timedOut) _setStatus('offline');
        });
  }

  void _applyData(Map<String, dynamic> data) {
    _mergeList<Purchase>(data, 'purchases', localItems: storage.purchases, fromJson: (j) => Purchase.fromJson(j), toJson: (i) => i.toJson(), getUpdatedAt: (i) => i.updatedAt, onMerged: (items) => storage.purchases = items);
    _mergeList<Task>(data, 'tasks', localItems: storage.tasks, fromJson: (j) => Task.fromJson(j), toJson: (i) => i.toJson(), getUpdatedAt: (i) => i.updatedAt, onMerged: (items) => storage.tasks = items);
    _mergeList<Shift>(data, 'shifts', localItems: storage.shifts, fromJson: (j) => Shift.fromJson(j), toJson: (i) => i.toJson(), getUpdatedAt: (i) => i.updatedAt, onMerged: (items) => storage.shifts = items);
    _mergeList<Transaction>(data, 'transactions', localItems: storage.transactions, fromJson: (j) => Transaction.fromJson(j), toJson: (i) => i.toJson(), getUpdatedAt: (i) => i.updatedAt, onMerged: (items) => storage.transactions = items);
    _mergeList<PurchaseTemplate>(data, 'purchaseTemplates', localItems: storage.purchaseTemplates, fromJson: (j) => PurchaseTemplate.fromJson(j), toJson: (i) => i.toJson(), getUpdatedAt: (i) => i.updatedAt, onMerged: (items) => storage.purchaseTemplates = items);

    _replacePurchaseLists(data);
    _replacePurchaseCategories(data);
    _replaceTaskCategories(data);
    _replaceShiftTypes(data);
    _replacePartners(data);
    _replaceBudgetCategories(data);
    _replaceHistory(data);

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
      for (final entry in remoteMap.entries) {
        final id = entry.key.toString();
        final remoteJson = Map<String, dynamic>.from(entry.value as Map);
        final remoteItem = fromJson(remoteJson);
        if (remoteJson['deletedAt'] != null) continue;
        final localItem = localById[id];
        if (localItem == null) merged[id] = remoteItem;
        else if (getUpdatedAt(remoteItem) > getUpdatedAt(localItem)) merged[id] = remoteItem;
        else merged[id] = localItem;
      }
      for (final entry in localById.entries) {
        if (!merged.containsKey(entry.key)) {
          if (remoteMap[entry.key] == null) merged[entry.key] = entry.value;
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
    } catch (e) { _log.error('Sync', 'purchaseLists', e); }
  }

  void _replacePurchaseCategories(Map<String, dynamic> data) {
    final raw = data['purchaseCategories']; if (raw == null) return;
    try {
      final list = (raw as Map).values.map((v) => PurchaseCategory.fromJson(Map<String, dynamic>.from(v as Map))).toList();
      if (list.isNotEmpty) storage.purchaseCategories = list;
    } catch (e) { _log.error('Sync', 'purchaseCategories', e); }
  }

  void _replaceTaskCategories(Map<String, dynamic> data) {
    final raw = data['taskCategories']; if (raw == null) return;
    try {
      final list = (raw as Map).values.map((v) => TaskCategory.fromJson(Map<String, dynamic>.from(v as Map))).toList();
      if (list.isNotEmpty) storage.taskCategories = list;
    } catch (e) { _log.error('Sync', 'taskCategories', e); }
  }

  void _replaceShiftTypes(Map<String, dynamic> data) {
    final raw = data['shiftTypes']; if (raw == null) return;
    try {
      final list = (raw as Map).values.map((v) => ShiftType.fromJson(Map<String, dynamic>.from(v as Map))).toList();
      if (list.isNotEmpty) storage.shiftTypes = list;
    } catch (e) { _log.error('Sync', 'shiftTypes', e); }
  }

  void _replacePartners(Map<String, dynamic> data) {
    final raw = data['partners']; if (raw == null) return;
    try {
      final list = (raw as Map).values.map((v) => Partner.fromJson(Map<String, dynamic>.from(v as Map))).toList();
      if (list.isNotEmpty) storage.partners = list;
    } catch (e) { _log.error('Sync', 'partners', e); }
  }

  void _replaceBudgetCategories(Map<String, dynamic> data) {
    final raw = data['budgetCategories']; if (raw == null) return;
    try {
      final list = (raw as Map).values.map((v) => BudgetCategory.fromJson(Map<String, dynamic>.from(v as Map))).toList();
      if (list.isNotEmpty) storage.budgetCategories = list;
    } catch (e) { _log.error('Sync', 'budgetCategories', e); }
  }

  void _replaceHistory(Map<String, dynamic> data) {
    final raw = data['purchaseHistory']; if (raw == null) return;
    try {
      final list = (raw as List).map((e) => PurchaseHistoryEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      if (list.isNotEmpty) storage.purchaseHistory = list;
    } catch (e) { _log.error('Sync', 'history', e); }
  }

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
        onDataChanged?.call();
      }
      final myData = storage.snapshot();
      myData['profiles'] = remoteData['profiles'] ?? {};
      if (storage.myKey != null) {
        final profiles = Map<String, dynamic>.from(myData['profiles'] as Map);
        final myProfile = Map<String, dynamic>.from(profiles[storage.myKey] as Map? ?? <String, dynamic>{});
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
          .eq('code', storage.coupleCode!)
          .timeout(const Duration(seconds: 30));
      storage.serverVersion = newVersion;
      _setStatus('online');
    } catch (e, st) {
      _log.error('Push', 'FAILED', e, st);
      _setStatus('error');
    } finally { _isPushInProgress = false; }
  }

  Future<void> disconnect() async {
    _channel?.unsubscribe();
    _channel = null;
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
    _status = s;
    _log.info('Sync', 'статус → $s');
    onStatusChanged?.call();
  }
}