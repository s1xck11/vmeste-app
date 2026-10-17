import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'services/storage_service.dart';
import 'services/sync_service.dart';
import 'services/debug_log_service.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_theme_config.dart';
import 'widgets/app_background.dart';
import 'screens/hub_setup_screen.dart';
import 'screens/hub_main_screen.dart';

class _HubHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (cert, host, port) => true;
    client.connectionTimeout = const Duration(seconds: 30);
    client.idleTimeout = const Duration(seconds: 30);
    return client;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final logger = DebugLogService();
  FlutterError.onError = (d) =>
      logger.error('Flutter', d.exceptionAsString(), d.exception, d.stack);
  HttpOverrides.global = _HubHttpOverrides();
  logger.info('Hub', 'HttpOverrides установлен');

  try {
    await Supabase.initialize(
        url: SupabaseConfig.url, anonKey: SupabaseConfig.anonKey);
    logger.info('Hub', 'Supabase инициализирован');
  } catch (e, st) {
    logger.error('Hub', 'Supabase init FAILED', e, st);
  }

  final storage = StorageService();
  await storage.init();
  final themeService = ThemeService();
  await themeService.init();
  final sync = SyncService(storage: storage);

  runApp(HubApp(
    storage: storage,
    sync: sync,
    themeService: themeService,
  ));
}

class HubApp extends StatelessWidget {
  final StorageService storage;
  final SyncService sync;
  final ThemeService themeService;

  const HubApp({
    super.key,
    required this.storage,
    required this.sync,
    required this.themeService,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeConfig>(
      valueListenable: themeService.notifier,
      builder: (context, config, _) {
        return MaterialApp(
          title: 'Вместе Хаб',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(config),
          builder: (context, child) {
            return AppBackground(child: child ?? const SizedBox.shrink());
          },
          home: SplashScreen(
            storage: storage,
            sync: sync,
            themeService: themeService,
          ),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;
  final ThemeService themeService;
  const SplashScreen({
    super.key,
    required this.storage,
    required this.sync,
    required this.themeService,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    await Future.delayed(const Duration(milliseconds: 400));

    // Пытаемся автоподключиться, если уже есть сохранённые данные
    bool connected = false;
    if (widget.storage.isConfigured) {
      connected = await widget.sync.autoConnect();
    }

    if (!mounted) return;

    if (connected) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HubMainScreen(
            storage: widget.storage,
            sync: widget.sync,
            themeService: widget.themeService,
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HubSetupScreen(
            storage: widget.storage,
            sync: widget.sync,
            themeService: widget.themeService,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_outlined, size: 80, color: cs.primary),
            const SizedBox(height: 24),
            Text('Вместе Хаб',
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface)),
            const SizedBox(height: 24),
            CircularProgressIndicator(color: cs.primary),
          ],
        ),
      ),
    );
  }
}