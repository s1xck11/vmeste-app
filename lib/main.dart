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
import 'screens/setup_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/purchases_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/shifts_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/debug_screen.dart';
import 'screens/data_management_screen.dart';
import 'screens/theme_picker_screen.dart';

class _SupabaseHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      return host.endsWith('.supabase.co') || host.endsWith('.supabase.in');
    };
    return client;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final logger = DebugLogService();
  FlutterError.onError = (details) {
    logger.error('Flutter', details.exceptionAsString(), details.exception, details.stack);
  };

  logger.info('App', '=== ВМЕСТЕ запускается ===');
  logger.info('App', 'Flutter ${Platform.version}');

  HttpOverrides.global = _SupabaseHttpOverrides();
  logger.info('App', 'HttpOverrides установлен');

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
    logger.info('App', 'Supabase инициализирован');
  } catch (e, st) {
    logger.error('App', 'Supabase init FAILED', e, st);
  }

  final storage = StorageService();
  await storage.init();
  logger.info('App', 'Storage инициализирован');

  final themeService = ThemeService();
  await themeService.init();
  logger.info('App', 'ThemeService инициализирован');

  final sync = SyncService(storage: storage);

  runApp(VmesteApp(storage: storage, sync: sync, themeService: themeService));
}

class VmesteApp extends StatelessWidget {
  final StorageService storage;
  final SyncService sync;
  final ThemeService themeService;

  const VmesteApp({
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
          title: 'Вместе',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(config),
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
    final log = DebugLogService();
    log.info('Splash', 'проверка конфигурации');
    await Future.delayed(const Duration(milliseconds: 300));

    if (widget.storage.isConfigured) {
      log.info('Splash', 'isConfigured=true, вызываем autoConnect');
      final ok = await widget.sync.autoConnect();
      log.info('Splash', 'autoConnect вернул: $ok');
      if (!mounted) return;

      if (ok) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MainScreen(
              storage: widget.storage,
              sync: widget.sync,
              themeService: widget.themeService,
            ),
          ),
        );
        return;
      }
    } else {
      log.info('Splash', 'isConfigured=false, идём в Setup');
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SetupScreen(
          storage: widget.storage,
          sync: widget.sync,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite, size: 80, color: cs.primary),
            const SizedBox(height: 24),
            Text(
              'Вместе',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(color: cs.primary),
          ],
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;
  final ThemeService themeService;

  const MainScreen({
    super.key,
    required this.storage,
    required this.sync,
    required this.themeService,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    _screens = [
      PurchasesScreen(storage: widget.storage, sync: widget.sync),
      TasksScreen(storage: widget.storage, sync: widget.sync),
      ShiftsScreen(storage: widget.storage, sync: widget.sync),
      BudgetScreen(storage: widget.storage, sync: widget.sync),
    ];

    widget.sync.onStatusChanged = () {
      if (mounted) setState(() {});
    };
    widget.sync.onDataChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    widget.sync.onStatusChanged = null;
    widget.sync.onDataChanged = null;
    super.dispose();
  }

  Future<void> _changeName(String newName) async {
    widget.storage.myName = newName;
    widget.sync.schedulePush();
    if (mounted) setState(() {});
  }

  Future<void> _reconnect() async {
    DebugLogService().info('UI', 'ручное переподключение');
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
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SetupScreen(
          storage: widget.storage,
          sync: widget.sync,
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          groupCode: widget.storage.coupleCode ?? '',
          myKey: widget.storage.myKey ?? '',
          myName: widget.storage.myName,
          partnerName: widget.storage.partnerName,
          dataVersion: widget.storage.serverVersion,
          syncStatus: widget.sync.status,
          onNameChanged: _changeName,
          onDisconnect: _disconnect,
          onReconnect: _reconnect,
          onOpenDebug: _openDebug,
          onOpenDataManagement: _openDataManagement,
          onOpenThemePicker: _openThemePicker,
        ),
      ),
    );
  }

  void _openDebug() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DebugScreen()),
    );
  }

  void _openDataManagement() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DataManagementScreen(
          storage: widget.storage,
          sync: widget.sync,
        ),
      ),
    );
  }

  void _openThemePicker() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ThemePickerScreen(themeService: widget.themeService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          // Аватарка поверх всего — открывает настройки
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(50),
                    onTap: _openSettings,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.surfaceVariant,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.outline),
                      ),
                      child: Center(
                        child: Text(
                          _initial(),
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag),
            label: 'Покупки',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Задачи',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Смены',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Бюджет',
          ),
        ],
      ),
    );
  }

  String _initial() {
    final name = widget.storage.myName.trim();
    if (name.isEmpty) return '👤';
    return name.characters.first.toUpperCase();
  }
}