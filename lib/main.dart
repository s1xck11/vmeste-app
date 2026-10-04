import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'services/storage_service.dart';
import 'services/sync_service.dart';
import 'screens/setup_screen.dart';
import 'screens/settings_screen.dart';

const String _supabaseHost = 'rgsefmrieltdmqbngsyo.supabase.co';
const String _supabaseIp = '104.18.38.10';

class _SupabaseHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);

    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      return host == _supabaseHost || host.endsWith('.supabase.co');
    };

    // Перехватываем подключение: если URI указывает на наш Supabase,
    // соединяемся по IP, но TLS-handshake делаем с правильным SNI (hostname).
    client.connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) {
      if (uri.host != _supabaseHost) {
        // Не наш домен — используем стандартное подключение
        return Socket.startConnect(uri.host, uri.port);
      }

      // Наш домен: подключаемся к IP, но передаём SNI = hostname
      final task = ConnectionTask<Socket>(() async {
        final rawSocket = await Socket.connect(_supabaseIp, uri.port);
        final secureSocket = await SecureSocket.secure(
          rawSocket,
          host: uri.host, // SNI
          onBadCertificate: (cert) => true,
        );
        return secureSocket;
      });
      return task;
    };

    return client;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  HttpOverrides.global = _SupabaseHttpOverrides();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  final storage = StorageService();
  await storage.init();

  final sync = SyncService(storage: storage);

  runApp(VmesteApp(storage: storage, sync: sync));
}

// ... остальное без изменений