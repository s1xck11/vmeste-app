// lib/main.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:home_widget/home_widget.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'supabase_config.dart';
import 'services/storage_service.dart';
import 'services/sync_service.dart';
import 'services/debug_log_service.dart';
import 'services/theme_service.dart';
import 'services/background_service.dart';
import 'services/update_service.dart';
import 'services/widget_service.dart';
import 'services/tile_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_theme_config.dart';
import 'widgets/app_background.dart';
import 'widgets/add_fab.dart';
import 'widgets/curved_nav_bar.dart';
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

  tz_data.initializeTimeZones();
  await UpdateService.loadVersion();

  final logger = DebugLogService();
  FlutterError.onError = (d) =>
      logger.error('Flutter', d.exceptionAsString(), d.exception, d.stack);
  HttpOverrides.global = _SupabaseHttpOverrides();
  logger.info('App', 'HttpOverrides установлен');
  logger.info('App', 'Версия приложения: ${UpdateService.currentFull}');

  try {
    await Supabase.initialize(
        url: SupabaseConfig.url, anonKey: SupabaseConfig.anonKey);
    logger.info('App', 'Supabase инициализирован');
  } catch (e, st) {
    logger.error('App', 'Supabase init FAILED', e, st);
  }

  final storage = StorageService();
  await storage.init();
  final themeService = ThemeService();
  await themeService.init();
  final bgService = BackgroundService.init(storage);
  final sync = SyncService(storage: storage);
  final widgetService = WidgetService(storage);
  sync.widgetService = widgetService;
  final tileService = TileService();

  int? initialTab;
  try {
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    initialTab = _tabFromUri(uri);
    if (initialTab != null) {
      logger.info('Widget', 'запущено из виджета, tab=$initialTab');
    }
  } catch (e, st) {
    logger.error('Widget', 'initiallyLaunchedFromHomeWidget FAILED', e, st);
  }

  String? initialAction;
  try {
    initialAction = await tileService.getInitialAction();
    if (initialAction != null) {
      logger.info('Tile', 'запущено из плитки: $initialAction');
    }
  } catch (e, st) {
    logger.error('Tile', 'initial action FAILED', e, st);
  }

  runApp(VmesteApp(
    storage: storage,
    sync: sync,
    themeService: themeService,
    bgService: bgService,
    widgetService: widgetService,
    tileService: tileService,
    initialTab: initialTab,
    initialAction: initialAction,
  ));
}

class VmesteApp extends StatelessWidget {
  final StorageService storage;
  final SyncService sync;
  final ThemeService themeService;
  final BackgroundService bgService;
  final WidgetService widgetService;
  final TileService tileService;
  final int? initialTab;
  final String? initialAction;

  const VmesteApp({
    super.key,
    required this.storage,
    required this.sync,
    required this.themeService,
    required this.bgService,
    required this.widgetService,
    required this.tileService,
    this.initialTab,
    this.initialAction,
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
            bgService: bgService,
            widgetService: widgetService,
            tileService: tileService,
            initialTab: initialTab,
            initialAction: initialAction,
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
  final BackgroundService bgService;
  final WidgetService widgetService;
  final TileService tileService;
  final int? initialTab;
  final String? initialAction;

  const SplashScreen({
    super.key,
    required this.storage,
    required this.sync,
    required this.themeService,
    required this.bgService,
    required this.widgetService,
    required this.tileService,
    this.initialTab,
    this.initialAction,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _updateService = UpdateService();

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _autoCheckUpdate();
    _checkQuickExpenseNotification();

    if (widget.storage.isConfigured) {
      final ok = await widget.sync.autoConnect();
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => MainScreen(
            storage: widget.storage,
            sync: widget.sync,
            themeService: widget.themeService,
            bgService: widget.bgService,
            widgetService: widget.widgetService,
            tileService: widget.tileService,
            initialTab: widget.initialTab,
            initialAction: widget.initialAction,
          ),
        ));
        return;
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => SetupScreen(
        storage: widget.storage,
        sync: widget.sync,
        themeService: widget.themeService,
        bgService: widget.bgService,
        widgetService: widget.widgetService,
        tileService: widget.tileService,
      ),
    ));
  }

  Future<void> _autoCheckUpdate() async {
    final info = await _updateService.checkForUpdate();
    if (info != null && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Доступно обновление ${info.tag}'),
          content: Text(info.body.isNotEmpty ? info.body : 'Вышла новая версия'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Позже')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateService.downloadApk(info).then((f) {
                  if (f != null) _updateService.installApk(f);
                });
              },
              child: const Text('Обновить'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _checkQuickExpenseNotification() async {
    try {
      final box = Hive.box('vmeste_data');
      final enabled = box.get('quick_expense_notif_enabled') as bool? ?? false;
      if (enabled) {
        await widget.tileService.showNotification();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icon/logo.svg',
              width: 140,
              height: 140,
            ),
            const SizedBox(height: 24),
            Text('Вместе', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 32),
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
  final BackgroundService bgService;
  final WidgetService widgetService;
  final TileService tileService;
  final int? initialTab;
  final String? initialAction;
  const MainScreen({
    super.key,
    required this.storage,
    required this.sync,
    required this.themeService,
    required this.bgService,
    required this.widgetService,
    required this.tileService,
    this.initialTab,
    this.initialAction,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late final List<Widget> _screens;
  final _updateService = UpdateService();

  final _purchasesKey = GlobalKey<PurchasesScreenState>();
  final _tasksKey = GlobalKey<TasksScreenState>();
  final _shiftsKey = GlobalKey<ShiftsScreenState>();
  final _budgetKey = GlobalKey<BudgetScreenState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.initialTab != null) {
      _currentIndex = widget.initialTab!;
    }

    _screens = [
      PurchasesScreen(key: _purchasesKey, storage: widget.storage, sync: widget.sync, themeService: widget.themeService, onAvatarTap: _openSettings),
      TasksScreen(key: _tasksKey, storage: widget.storage, sync: widget.sync, themeService: widget.themeService, onAvatarTap: _openSettings),
      ShiftsScreen(key: _shiftsKey, storage: widget.storage, sync: widget.sync, themeService: widget.themeService, onAvatarTap: _openSettings),
      BudgetScreen(key: _budgetKey, storage: widget.storage, sync: widget.sync, themeService: widget.themeService, onAvatarTap: _openSettings),
    ];

    widget.sync.onStatusChanged = () { if (mounted) setState(() {}); };
    Future.delayed(const Duration(milliseconds: 500), () {
      widget.sync.pullNow();
      widget.widgetService.updateAll();
    });

    // Обработка запуска из плитки/уведомления
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialAction == 'openExpense') {
        _openQuickExpense();
      }
    });

    // Слушаем события, пока приложение открыто
    widget.tileService.setHandler((call) async {
      if (call.method == 'openExpense') {
        _openQuickExpense();
      }
      return null;
    });

    try {
      HomeWidget.widgetClicked.listen((uri) {
        final tab = _tabFromUri(uri);
        if (tab != null && mounted) {
          setState(() => _currentIndex = tab);
        }
      });
    } catch (_) {}
  }

  void _openQuickExpense() {
    if (!mounted) return;
    setState(() => _currentIndex = 3); // Кошелёк
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        _budgetKey.currentState?.openAddModal();
      });
    });
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
      _checkUpdateOnResume();
    }
  }

  Future<void> _checkUpdateOnResume() async {
    final info = await _updateService.checkForUpdate();
    if (info != null && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Доступно обновление ${info.tag}'),
          content: Text(info.body.isNotEmpty ? info.body : 'Вышла новая версия'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Позже')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateService.downloadApk(info).then((f) {
                  if (f != null) _updateService.installApk(f);
                });
              },
              child: const Text('Обновить'),
            ),
          ],
        ),
      );
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
      builder: (_) => SetupScreen(
        storage: widget.storage,
        sync: widget.sync,
        themeService: widget.themeService,
        bgService: widget.bgService,
        widgetService: widget.widgetService,
        tileService: widget.tileService,
      ),
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

  void _onFabPick(int kind) {
    int targetTab;
    switch (kind) {
      case 0: targetTab = 0; break;
      case 1: targetTab = 1; break;
      case 2: targetTab = 2; break;
      case 3: targetTab = 3; break;
      case 4: targetTab = 3; break;
      case 5: targetTab = 3; break;
      default: targetTab = 0;
    }

    final needSwitch = _currentIndex != targetTab;
    if (needSwitch) setState(() => _currentIndex = targetTab);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) return;
        switch (kind) {
          case 0: _purchasesKey.currentState?.openAddModal(); break;
          case 1: _tasksKey.currentState?.openAddModal(); break;
          case 2: _shiftsKey.currentState?.openAddForToday(); break;
          case 3: _budgetKey.currentState?.openAddModal(); break;
          case 4: _budgetKey.currentState?.openAddIncomeModal(); break;
          case 5: _budgetKey.currentState?.openAddTransferModal(); break;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: AppBackground(
        service: widget.bgService,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            IndexedStack(index: _currentIndex, children: _screens),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0 + bottomInset * 0.5,
              child: CurvedNavBar(
                currentIndex: _currentIndex,
                onTap: (i) => setState(() => _currentIndex = i),
                onFabTap: () => _showFabMenu(),
                cs: cs,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFabMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.18),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: AddFabContent(
              onPick: (kind) {
                Navigator.pop(ctx);
                _onFabPick(kind);
              },
            ),
          ),
        );
      },
    );
  }
}

int? _tabFromUri(Uri? uri) {
  if (uri == null) return null;
  final t = uri.queryParameters['tab'];
  if (t == null) return null;
  final v = int.tryParse(t);
  if (v == null || v < 0 || v > 3) return null;
  return v;
}