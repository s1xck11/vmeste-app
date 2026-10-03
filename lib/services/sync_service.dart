import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_config.dart';
import 'storage_service.dart';

/// Сервис синхронизации с Supabase.
/// 
/// Логика:
/// 1. Анонимный вход в Supabase
/// 2. Поиск группы по коду
/// 3. Присоединение к members
/// 4. Чтение данных + Realtime-подписка
/// 5. Отправка изменений с защитой от перезаписи
class SyncService {
  final StorageService storage;
  final SupabaseClient _supabase = Supabase.instance.client;

  RealtimeChannel? _channel;
  Timer? _pushDebounce;
  bool _isFirstLoad = true;
  bool _isRemoteUpdate = false;
  bool _isPushInProgress = false;

  // Колбэки для UI — вызываются при изменениях
  VoidCallback? onDataChanged;
  VoidCallback? onStatusChanged;

  String _status = 'offline'; // online | syncing | offline | error
  String get status => _status;

  SyncService({required this.storage});

  // ============ ПОДКЛЮЧЕНИЕ ============

  /// Войти анонимно и получить UID
  Future<String> signInAnonymously() async {
    // Если уже вошли — возвращаем сохранённый UID
    final existing = _supabase.auth.currentUser;
    if (existing != null) {
      storage.currentUserId = existing.id;
      return existing.id;
    }

    // Иначе — новый анонимный вход
    final response = await _supabase.auth.signInAnonymously();
    final user = response.user;
    if (user == null) throw Exception('Не удалось войти анонимно');
    storage.currentUserId = user.id;
    return user.id;
  }

  /// Создать новую группу
  Future<String> createGroup() async {
    final uid = await signInAnonymously();

    // Генерируем уникальный код
    String code;
    int attempts = 0;
    do {
      code = _generateCode();
      final existing = await _supabase
          .from('couples')
          .select('code')
          .eq('code', code)
          .maybeSingle();
      if (existing == null) break;
      attempts++;
    } while (attempts < 5);

    // Создаём группу с пустыми данными
    await _supabase.from('couples').insert({
      'code': code,
      'members': [uid],
      'data': storage.snapshot(),
      'version': 1,
      'updated_by': uid,
    });

    storage.coupleCode = code;
    storage.members = [uid];
    storage.serverVersion = 1;
    storage.myPartnerId = 'partner1'; // первый — всегда partner1

    _setStatus('online');
    _isFirstLoad = false;
    _subscribe();
    return code;
  }

  /// Присоединиться к существующей группе
  Future<void> joinGroup(String code) async {
    code = code.trim().toUpperCase();
    final uid = await signInAnonymously();

    // Ищем группу
    final group = await _supabase
        .from('couples')
        .select()
        .eq('code', code)
        .maybeSingle();

    if (group == null) {
      throw Exception('Группа не найдена');
    }

    // Добавляем себя в members
    final members = List<String>.from(group['members'] as List? ?? []);
    if (!members.contains(uid)) {
      members.add(uid);
      await _supabase
          .from('couples')
          .update({'members': members})
          .eq('code', code);
    }

    storage.coupleCode = code;
    storage.members = members;
    storage.serverVersion = (group['version'] as int?) ?? 0;

    // Определяем, кто я — тот, кто НЕ первый участник
    if (members.isNotEmpty && members.first == uid) {
      storage.myPartnerId = 'partner1';
    } else {
      storage.myPartnerId = 'partner2';
    }

    // Загружаем данные
    final data = group['data'] as Map<String, dynamic>? ?? {};
    _isRemoteUpdate = true;
    storage.restoreFromSnapshot(data);
    _isRemoteUpdate = false;

    _setStatus('online');
    _isFirstLoad = false;
    _subscribe();
  }

  /// Автоподключение при запуске (если код уже сохранён)
  Future<bool> autoConnect() async {
    final code = storage.coupleCode;
    if (code == null || code.isEmpty) return false;

    try {
      _setStatus('syncing');
      final uid = await signInAnonymously();

      final group = await _supabase
          .from('couples')
          .select()
          .eq('code', code)
          .maybeSingle();

      if (group == null) {
        // Группы нет — сбрасываем настройки
        storage.coupleCode = null;
        _setStatus('offline');
        return false;
      }

      final members = List<String>.from(group['members'] as List? ?? []);
      if (!members.contains(uid)) {
        members.add(uid);
        await _supabase
            .from('couples')
            .update({'members': members})
            .eq('code', code);
      }

      storage.members = members;
      storage.serverVersion = (group['version'] as int?) ?? 0;

      // Загружаем данные
      final data = group['data'] as Map<String, dynamic>? ?? {};
      _isRemoteUpdate = true;
      storage.restoreFromSnapshot(data);
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

  // ============ REALTIME-ПОДПИСКА ============

  void _subscribe() {
    final code = storage.coupleCode;
    if (code == null) return;

    // Отписываемся от старой
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
            if (newRecord['updated_by'] == storage.currentUserId) return;

            final newVersion = (newRecord['version'] as int?) ?? 0;
            if (newVersion <= storage.serverVersion) return;

            final data = newRecord['data'] as Map<String, dynamic>? ?? {};
            _isRemoteUpdate = true;
            storage.restoreFromSnapshot(data);
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

  // ============ ОТПРАВКА ИЗМЕНЕНИЙ ============

  /// Запланировать отправку в облако (с дебаунсом)
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
      // Читаем актуальные данные с сервера
      final remote = await _supabase
          .from('couples')
          .select('data, version')
          .eq('code', storage.coupleCode!)
          .maybeSingle();

      if (remote == null) return;

      final remoteData = remote['data'] as Map<String, dynamic>? ?? {};
      final remoteVersion = (remote['version'] as int?) ?? 0;

      // Если на сервере новее — сначала мержим к себе
      if (remoteVersion > storage.serverVersion) {
        _isRemoteUpdate = true;
        storage.restoreFromSnapshot(remoteData);
        storage.serverVersion = remoteVersion;
        _isRemoteUpdate = false;
        onDataChanged?.call();
      }

      // Отправляем наш снапшот
      final newVersion = remoteVersion + 1;
      await _supabase
          .from('couples')
          .update({
            'data': storage.snapshot(),
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

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = DateTime.now().microsecondsSinceEpoch;
    final buffer = StringBuffer();
    for (int i = 0; i < 9; i++) {
      if (i == 3 || i == 6) buffer.write('-');
      buffer.write(chars[(rand + i * 7) % chars.length]);
    }
    return buffer.toString();
  }

  void _setStatus(String s) {
    _status = s;
    onStatusChanged?.call();
  }
}

/// Простой колбэк без параметров
typedef VoidCallback = void Function();