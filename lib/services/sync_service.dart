import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'storage_service.dart';

typedef VoidCallback = void Function();

/// Сервис синхронизации с Supabase.
class SyncService {
  final StorageService storage;
  final SupabaseClient _supabase = Supabase.instance.client;

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
    final existing = _supabase.auth.currentUser;
    if (existing != null) {
      storage.currentUserId = existing.id;
      return existing.id;
    }
    final response = await _supabase.auth.signInAnonymously();
    final user = response.user;
    if (user == null) throw Exception('Не удалось войти анонимно');
    storage.currentUserId = user.id;
    return user.id;
  }

  // ============ СОЗДАНИЕ ГРУППЫ ============

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
          .maybeSingle();
      if (existing == null) break;
      attempts++;
    } while (attempts < 5);

    final profiles = {
      myKey: {
        'key': myKey,
        'role': 'partner1',
        'name': '',
        'uids': [uid],
      },
    };

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

    storage.coupleCode = code;
    storage.members = [uid];
    storage.serverVersion = 1;
    storage.myKey = myKey;
    storage.myPartnerId = 'partner1';

    _setStatus('online');
    _isFirstLoad = false;
    _subscribe();

    return {
      'code': code,
      'myKey': myKey,
    };
  }

  /// Присоединиться к существующей группе как партнёр
  Future<String> joinGroup(String code) async {
    code = code.trim().toUpperCase();
    final uid = await signInAnonymously();

    final group = await _supabase
        .from('couples')
        .select()
        .eq('code', code)
        .maybeSingle();

    if (group == null) throw Exception('Группа не найдена');

    final data = Map<String, dynamic>.from(group['data'] as Map? ?? {});
    final profiles = Map<String, dynamic>.from(data['profiles'] as Map? ?? {});

    // Ищем свободный слот (uids пустой)
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

    // Если нет свободного слота — создаём partner2
    String myRole;
    String myKey;

    if (foundRole != null && foundKey != null) {
      myRole = foundRole;
      myKey = foundKey;
    } else {
      final existingRoles = profiles.values
          .map((p) => (p as Map)['role'] as String?)
          .where((r) => r != null)
          .toSet();

      if (existingRoles.contains('partner1') && existingRoles.contains('partner2')) {
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
    }

    // Добавляем себя в профиль
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

  /// Войти под существующим личным ключом (для смены устройства)
  Future<void> restoreByKey(String key) async {
    final code = storage.coupleCode;
    if (code == null || code.isEmpty) {
      throw Exception('Сначала подключись к группе по её коду');
    }

    key = key.trim().toUpperCase();
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

  /// Автоподключение при запуске
  Future<bool> autoConnect() async {
    final code = storage.coupleCode;
    final key = storage.myKey;
    if (code == null || code.isEmpty || key == null) return false;

    try {
      _setStatus('syncing');
      final uid = await signInAnonymously();

      final group = await _supabase
          .from('couples')
          .select()
          .eq('code', code)
          .maybeSingle();

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
        await _supabase.from('couples').update({
          'members': members,
          'data': data,
        }).eq('code', code);

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
      return true;
    } catch (e) {
      print('autoConnect error: $e');
      _setStatus('offline');
      _isFirstLoad = false;
      return false;
    }
  }

  // ============ REALTIME ============

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
    storage.restoreFromSnapshot(data);

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
      final remote = await _supabase
          .from('couples')
          .select('data, version')
          .eq('code', storage.coupleCode!)
          .maybeSingle();

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

      // Обновляем своё имя в profiles
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
    } catch (e) {
      print('push error: $e');
      _setStatus('error');
    } finally {
      _isPushInProgress = false;
    }
  }

  // ============ ОТКЛЮЧЕНИЕ ============

  Future<void> disconnect() async {
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

  /// Генерирует личный ключ: X-XXXX-XXXX (10 символов)
  String _generateKey() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    final buffer = StringBuffer();
    buffer.write(chars.substring(0, 26)[rand.nextInt(26)]); // только буквы
    for (int i = 0; i < 8; i++) {
      if (i == 4) buffer.write('-');
      buffer.write(chars[rand.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  void _setStatus(String s) {
    _status = s;
    onStatusChanged?.call();
  }
}