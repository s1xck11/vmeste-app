import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_apps_ng/device_apps_ng.dart';
import 'package:dpad/dpad.dart';
import 'supabase_config.dart';
import 'services/storage_service.dart';
import 'services/sync_service.dart';
import 'services/debug_log_service.dart';
import 'services/theme_service.dart';
import 'services/weather_service.dart';
import 'services/apps_service.dart';
import 'services/tuya_service.dart';
import 'services/launcher_service.dart';
import 'services/update_service.dart';
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

  await UpdateService.loadVersion();

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
  final weatherService = WeatherService();
  await weatherService.init();
  final appsService = AppsService();
  await appsService.init();
  final tuyaService = TuyaService();
  await tuyaService.init();
  final launcherService = LauncherService();
  await launcherService.init();

  _loadApps(appsService, logger);

  runApp(HubApp(
    storage: storage,
    sync: sync,
    themeService: themeService,
    weatherService: weatherService,
    appsService: appsService,
    tuyaService: tuyaService,
    launcherService: launcherService,
  ));
}

Future<void> _loadApps(AppsService appsService, DebugLogService logger) async {
  try {
    final apps = await DeviceApps.getInstalledApplications(
      includeSystemApps: false,
      onlyAppsWithLaunchIntent: true,
    );
    final list = apps.map((a) {
      return AppInfo(
        packageName: a.packageName,
        appName: a.appName,
      );
    }).toList();

    await appsService.setApps(list);
    logger.info('Apps', 'загружено приложений: ${list.length}');
  } catch (e, st) {
    logger.error('Apps', 'load FAILED', e, st);
  }
}

class HubApp extends StatelessWidget {
  final StorageService storage;
  final SyncService sync;
  final ThemeService themeService;
  final WeatherService weatherService;
  final AppsService appsService;
  final TuyaService tuyaService;
  final LauncherService launcherService;

  const HubApp({
    super.key,
    required this.storage,
    required this.sync,
    required this.themeService,
    required this.weatherService,
    required this.appsService,
    required this.tuyaService,
    required this.launcherService,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeConfig>(
      valueListenable: themeService.notifier,
      builder: (context, config, _) {
        // ВАЖНО: Dpad.wrap() в v3.1.1 не принимает child и onBack.
        // Оборачиваем MaterialApp целиком.
        return Dpad.wrap(
          child: MaterialApp(
            title: 'Вместе Хаб',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(config),
            builder: (context, child) {
              return AppBackground(
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: SplashScreen(
              storage: storage,
              sync: sync,
              themeService: themeService,
              weatherService: weatherService,
              appsService: appsService,
              tuyaService: tuyaService,
              launcherService: launcherService,
            ),
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
  final WeatherService weatherService;
  final AppsService appsService;
  final TuyaService tuyaService;
  final LauncherService launcherService;

  const SplashScreen({
    super.key,
    required this.storage,
    required this.sync,
    required this.themeService,
    required this.weatherService,
    required this.appsService,
    required this.tuyaService,
    required this.launcherService,
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

    bool connected = false;
    if (widget.storage.isConfigured) {
      connected = await widget.sync.autoConnect();
    }

    if (!mounted) return;

    final mainScreen = HubMainScreen(
      storage: widget.storage,
      sync: widget.sync,
      themeService: widget.themeService,
      weatherService: widget.weatherService,
      appsService: widget.appsService,
      tuyaService: widget.tuyaService,
      launcherService: widget.launcherService,
    );

    if (connected) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => mainScreen),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HubSetupScreen(
            storage: widget.storage,
            sync: widget.sync,
            themeService: widget.themeService,
            weatherService: widget.weatherService,
            appsService: widget.appsService,
            tuyaService: widget.tuyaService,
            launcherService: widget.launcherService,
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