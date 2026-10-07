import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'services/storage_service.dart';
import 'services/sync_service.dart';
import 'services/debug_log_service.dart';
import 'services/theme_service.dart';
import 'services/background_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_theme_config.dart';
import 'widgets/glass_container.dart';
import 'widgets/app_background.dart';
import 'screens/setup_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/purchases_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/shifts_screen.dart';
import 'screens/budget_screen.dart';

class AppColors {
  static const Color accent = Color(0xFFFF8FAB);
  static const Color accentLight = Color(0xFFFFE5EC);
  static const Color danger = Color(0xFFFF3B30);
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9500);
  static const Color info = Color(0xFF5856D6);
  static const Color bgLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFF8F9FA);
  static const Color textLight = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF8E8E93);
}

class _SupabaseHttpOverrides extends HttpOverrides {
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
  FlutterError.onError = (d) => logger.error('Flutter', d.exceptionAsString(), d.exception, d.stack);
  HttpOverrides.global = _SupabaseHttpOverrides();
  logger.info('App', 'HttpOverrides установлен');
  try {
    await Supabase.initialize(url: SupabaseConfig.url, anonKey: SupabaseConfig.anonKey);
    logger.info('App', 'Supabase инициализирован');
  } catch (e, st) { logger.error('App', 'Supabase init FAILED', e, st); }
  final storage = StorageService();
  await storage.init();
  final themeService = ThemeService();
  await themeService.init();
  final sync = SyncService(storage: storage);
  runApp(VmesteApp(storage: storage, sync: sync, themeService: themeService));
}

class VmesteApp extends StatelessWidget {
  final StorageService storage;
  final SyncService sync;
  final ThemeService themeService;
  const VmesteApp({super.key, required this.storage, required this.sync, required this.themeService});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeConfig>(
      valueListenable: themeService.notifier,
      builder: (context, config, _) {
        return MaterialApp(
          title: 'Вместе',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(config),
          home: SplashScreen(storage: storage, sync: sync, themeService: themeService),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;
  final ThemeService themeService;
  const SplashScreen({super.key, required this.storage, required this.sync, required this.themeService});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() { super.initState(); _check(); }

  Future<void> _check() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (widget.storage.isConfigured) {
      final ok = await widget.sync.autoConnect();
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => MainScreen(storage: widget.storage, sync: widget.sync, themeService: widget.themeService),
        ));
        return;
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => SetupScreen(storage: widget.storage, sync: widget.sync, themeService: widget.themeService),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.background,
      body: Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite, size: 80, color: cs.primary),
          const SizedBox(height: 24),
          Text('Вместе', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: cs.onSurface)),
          const SizedBox(height: 24),
          CircularProgressIndicator(color: cs.primary),
        ],
      )),
    );
  }
}

class MainScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;
  final ThemeService themeService;
  const MainScreen({super.key, required this.storage, required this.sync, required this.themeService});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late final List<Widget> _screens;
  late BackgroundService _bgService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bgService = BackgroundService(widget.storage);
    _screens = [
      PurchasesScreen(storage: widget.storage, sync: widget.sync, themeService: widget.themeService, onAvatarTap: _openSettings),
      TasksScreen(storage: widget.storage, sync: widget.sync, themeService: widget.themeService, onAvatarTap: _openSettings),
      ShiftsScreen(storage: widget.storage, sync: widget.sync, themeService: widget.themeService, onAvatarTap: _openSettings),
      BudgetScreen(storage: widget.storage, sync: widget.sync, themeService: widget.themeService, onAvatarTap: _openSettings),
    ];
    widget.sync.onStatusChanged = () { if (mounted) setState(() {}); };
    Future.delayed(const Duration(milliseconds: 500), () { widget.sync.pullNow(); });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.sync.onStatusChanged = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.sync.pullNow();
    }
  }

  Future<void> _reconnect() async {
    final ok = await widget.sync.autoConnect();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Подключено' : 'Не удалось подключиться')),
      );
    }
  }

  Future<void> _disconnect() async {
    await widget.sync.disconnect();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => SetupScreen(storage: widget.storage, sync: widget.sync, themeService: widget.themeService),
    ));
  }

  void _openSettings() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SettingsScreen(
        storage: widget.storage,
        sync: widget.sync,
        themeService: widget.themeService,
        onDisconnect: _disconnect,
        onReconnect: _reconnect,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.background,
      body: AppBackground(
        service: _bgService,
        child: IndexedStack(index: _currentIndex, children: _screens),
      ),
      bottomNavigationBar: GlassContainer(
        child: SafeArea(
          top: false,
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), selectedIcon: Icon(Icons.shopping_bag), label: 'Покупки'),
              NavigationDestination(icon: Icon(Icons.check_circle_outline), selectedIcon: Icon(Icons.check_circle), label: 'Задачи'),
              NavigationDestination(icon: Icon(Icons.calendar_today_outlined), selectedIcon: Icon(Icons.calendar_today), label: 'Смены'),
              NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Бюджет'),
            ],
          ),
        ),
      ),
    );
  }
}