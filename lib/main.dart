import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'services/storage_service.dart';
import 'services/sync_service.dart';
import 'services/debug_log_service.dart';
import 'screens/setup_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/purchases_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/shifts_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/debug_screen.dart';
import 'screens/data_management_screen.dart';

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

  final sync = SyncService(storage: storage);

  runApp(VmesteApp(storage: storage, sync: sync));
}

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

class VmesteApp extends StatelessWidget {
  final StorageService storage;
  final SyncService sync;

  const VmesteApp({
    super.key,
    required this.storage,
    required this.sync,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Вместе',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bgLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.transparent,
        ),
      ),
      home: SplashScreen(storage: storage, sync: sync),
    );
  }
}

class SplashScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;

  const SplashScreen({
    super.key,
    required this.storage,
    required this.sync,
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
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite, size: 80, color: AppColors.accent),
            SizedBox(height: 24),
            Text(
              'Вместе',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;

  const MainScreen({
    super.key,
    required this.storage,
    required this.sync,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  late final List<Widget> _fixedScreens;

  @override
  void initState() {
    super.initState();

    _fixedScreens = [
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

  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return _fixedScreens[0];
      case 1:
        return _fixedScreens[1];
      case 2:
        return _fixedScreens[2];
      case 3:
        return _fixedScreens[3];
      case 4:
      default:
        return SettingsScreen(
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
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _fixedScreens[0],
          _fixedScreens[1],
          _fixedScreens[2],
          _fixedScreens[3],
          _buildCurrentScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.accentLight,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart, color: AppColors.accent),
            label: 'Покупки',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle, color: AppColors.accent),
            label: 'Задачи',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today, color: AppColors.accent),
            label: 'Смены',
          ),
          NavigationDestination(
            icon: Icon(Icons.attach_money),
            selectedIcon: Icon(Icons.attach_money, color: AppColors.accent),
            label: 'Бюджет',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: AppColors.accent),
            label: 'Ещё',
          ),
        ],
      ),
    );
  }
}