import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/theme_service.dart';
import '../services/weather_service.dart';
import '../services/apps_service.dart';
import '../services/tuya_service.dart';
import '../widgets/glass_container.dart';
import 'hub_main_screen.dart';

class HubSetupScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;
  final ThemeService themeService;
  final WeatherService weatherService;
  final AppsService appsService;
  final TuyaService tuyaService;

  const HubSetupScreen({
    super.key,
    required this.storage,
    required this.sync,
    required this.themeService,
    required this.weatherService,
    required this.appsService,
    required this.tuyaService,
  });

  @override
  State<HubSetupScreen> createState() => _HubSetupScreenState();
}

class _HubSetupScreenState extends State<HubSetupScreen> {
  final _codeController = TextEditingController();
  final _keyController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  String _humanizeError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('socketexception') || s.contains('connection') || s.contains('network')) {
      return 'Нет соединения с сервером.\nПроверь интернет.';
    }
    if (s.contains('timeout') || s.contains('timed out')) {
      return 'Сервер не отвечает.\nПопробуй ещё раз.';
    }
    if (s.contains('группа') || s.contains('not found')) {
      return 'Группа не найдена.\nПроверь код группы.';
    }
    if (s.contains('ключ') || s.contains('key')) {
      return 'Ключ не найден в этой группе.';
    }
    return 'Что-то пошло не так. Попробуй ещё раз.';
  }

  Future<void> _connect() async {
    final code = _codeController.text.trim().toUpperCase();
    final key = _keyController.text.trim().toUpperCase();

    if (code.length < 5) {
      setState(() => _error = 'Введи код группы');
      return;
    }
    if (key.length < 5) {
      setState(() => _error = 'Введи свой ключ');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      widget.storage.coupleCode = code;
      await widget.sync.restoreByKey(code, key);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HubMainScreen(
            storage: widget.storage,
            sync: widget.sync,
            themeService: widget.themeService,
            weatherService: widget.weatherService,
            appsService: widget.appsService,
            tuyaService: widget.tuyaService,
          ),
        ),
      );
    } catch (e) {
      widget.storage.coupleCode = null;
      setState(() { _error = _humanizeError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: GlassContainer(
              radius: 32,
              showAllBorder: true,
              shadow: true,
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.home_outlined, size: 56, color: cs.primary),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Вместе Хаб',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Подключение к вашей группе',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _codeController,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 15,
                    enabled: !_loading,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 3),
                    decoration: InputDecoration(
                      labelText: 'Код группы',
                      hintText: 'ABC-123-XYZ',
                      counterText: '',
                      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _keyController,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 15,
                    enabled: !_loading,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 3),
                    decoration: InputDecoration(
                      labelText: 'Мой ключ',
                      hintText: 'A-XXXX-XXXX',
                      counterText: '',
                      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cs.error.withOpacity(0.3), width: 1.5),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline, color: cs.error, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: cs.error, fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _loading ? null : _connect,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: _loading
                        ? SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimary),
                            ),
                          )
                        : const Text('Подключиться', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Код и ключ можно найти\nв настройках мобильного «Вместе»',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}