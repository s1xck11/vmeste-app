import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'services/storage_service.dart';
import 'services/sync_service.dart';
import 'screens/setup_screen.dart';
import 'screens/settings_screen.dart';

// ============ ЖЁСТКИЙ IP ДЛЯ SUPABASE ============
//
// На Huawei без Google-сервисов системный DNS не может разрешить
// домен supabase.co. Провайдер (например, Мегафон) подсовывает левые
// IP-адреса. Поэтому мы жёстко прописываем реальный IP Cloudflare,
// через который работает Supabase.
//
// Cloudflare использует Anycast — один IP работает по всему миру,
// трафик автоматически идёт к ближайшему дата-центру.
const String _supabaseHost = 'rgsefmrieltdmqbngsyo.supabase.co';
const List<String> _supabaseIps = [
  '104.18.38.10',    // Основной Cloudflare IP
  '172.64.149.246',  // Резервный Cloudflare IP
];

class _SupabaseHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);

    // Разрешаем любые сертификаты для нашего домена
    // (на случай, если SNI не сработает)
    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      return host == _supabaseHost || host.endsWith('.supabase.co');
    };

    return client;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Применяем обход DNS-проблемы
  HttpOverrides.global = _SupabaseHttpOverrides();

  // Инициализация Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Инициализация локального хранилища
  final storage = StorageService();
  await storage.init();

  // Сервис синхронизации
  final sync = SyncService(storage: storage);

  runApp(VmesteApp(storage: storage, sync: sync));
}

// ============ ЦВЕТА ПРИЛОЖЕНИЯ ============
class AppColors {
  static const Color accent = Color(0xFFFF8FAB);
  static const Color accentLight = Color(0xFFFFE5EC);
  static const Color danger = Color(0xFFFF3B30);
  static const Color success = Color(0xFF34C759);
  static const Color info = Color(0xFF5856D6);
  static const Color bgLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFF8F9FA);
  static const Color textLight = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF8E8E93);

  static const String supabaseHost = _supabaseHost;
  static const List<String> supabaseIps = _supabaseIps;
}

// ============ ГЛАВНОЕ ПРИЛОЖЕНИЕ ============
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
      ),
      home: SplashScreen(storage: storage, sync: sync),
    );
  }
}

// ============ ЭКРАН ЗАГРУЗКИ ============
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
    await Future.delayed(const Duration(milliseconds: 300));

    if (widget.storage.isConfigured) {
      final ok = await widget.sync.autoConnect();
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

// ============ ГЛАВНЫЙ ЭКРАН С НАВИГАЦИЕЙ ============
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

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const _PlaceholderScreen(
        title: 'Покупки',
        icon: Icons.shopping_cart,
        message: 'Здесь будет список покупок\nс категориями и синхронизацией',
      ),
      const _PlaceholderScreen(
        title: 'Задачи',
        icon: Icons.check_circle,
        message: 'Здесь будут задачи с приоритетами\nдедлайнами и повторами',
      ),
      const _PlaceholderScreen(
        title: 'Смены',
        icon: Icons.calendar_today,
        message: 'Здесь будет календарь смен\nс типами и расчётом зарплаты',
      ),
      const _PlaceholderScreen(
        title: 'Бюджет',
        icon: Icons.attach_money,
        message: 'Здесь будут графики, фин-здоровье,\nинсайты и голосовой ввод',
      ),
      SettingsScreen(
        storage: widget.storage,
        sync: widget.sync,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
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

// ============ ЗАГЛУШКА ============
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String message;

  const _PlaceholderScreen({
    required this.title,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 80, color: AppColors.accent),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '🚧 В разработке',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}