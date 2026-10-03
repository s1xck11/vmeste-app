import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/sync_service.dart';
import '../services/storage_service.dart';
import '../main.dart' show AppColors, MainScreen;

class SetupScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;

  const SetupScreen({
    super.key,
    required this.storage,
    required this.sync,
  });

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _successMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    setState(() {
      _loading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final code = await widget.sync.createGroup();
      setState(() {
        _successMessage = code;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка: $e';
        _loading = false;
      });
    }
  }

  Future<void> _joinGroup() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length < 9) {
      setState(() => _error = 'Введите код группы (например, ABC-123-XYZ)');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.sync.joinGroup(code);
      _goToMain();
    } catch (e) {
      setState(() {
        _error = 'Ошибка: $e';
        _loading = false;
      });
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _loading = true;
      _error = null;
      _successMessage = null;
    });

    final results = <String>[];
    results.add('=== ДИАГНОСТИКА ===');

    // Тест 1: Обычный DNS (должен упасть на Huawei)
    try {
      final addresses = await InternetAddress.lookup('rgsefmrieltdmqbngsyo.supabase.co')
          .timeout(const Duration(seconds: 5));
      if (addresses.isNotEmpty) {
        results.add('✅ DNS: ${addresses.first.address}');
      } else {
        results.add('❌ DNS: пустой ответ');
      }
    } catch (e) {
      results.add('❌ DNS: не работает (ожидаемо на Huawei)');
    }

    // Тест 2: HTTPS по IP напрямую (104.18.38.10)
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      client.badCertificateCallback = (cert, host, port) => true;

      final request = await client.getUrl(
        Uri.parse('https://104.18.38.10/rest/v1/'),
      );
      request.headers.set('Host', 'rgsefmrieltdmqbngsyo.supabase.co');
      request.headers.set('apikey', 'sb_publishable_aoqWgrFepcLLhwtUU7LkAA_389p_sdk');
      final response = await request.close().timeout(const Duration(seconds: 10));
      results.add('✅ HTTPS (IP .10): код ${response.statusCode}');
      client.close();
    } catch (e) {
      results.add('❌ HTTPS (IP .10): $e');
    }

    // Тест 3: HTTPS по резервному IP (172.64.149.246)
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      client.badCertificateCallback = (cert, host, port) => true;

      final request = await client.getUrl(
        Uri.parse('https://172.64.149.246/rest/v1/'),
      );
      request.headers.set('Host', 'rgsefmrieltdmqbngsyo.supabase.co');
      request.headers.set('apikey', 'sb_publishable_aoqWgrFepcLLhwtUU7LkAA_389p_sdk');
      final response = await request.close().timeout(const Duration(seconds: 10));
      results.add('✅ HTTPS (IP .246): код ${response.statusCode}');
      client.close();
    } catch (e) {
      results.add('❌ HTTPS (IP .246): $e');
    }

    results.add('✅ Supabase клиент: OK');

    setState(() {
      _error = results.join('\n');
      _loading = false;
    });
  }

  void _continueLocally() {
    _goToMain();
  }

  void _goToMain() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MainScreen(
          storage: widget.storage,
          sync: widget.sync,
        ),
      ),
    );
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Код скопирован')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: AppColors.accentLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite,
                  size: 56,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Вместе',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Синхронизация с близкими',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 48),

              if (_successMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accent, width: 2),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '🎉 Группа создана!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Отправь этот код партнёру:',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _successMessage!,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _copyCode(_successMessage!),
                              icon: const Icon(Icons.copy),
                              label: const Text('Скопировать'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accent,
                                side: const BorderSide(color: AppColors.accent),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _goToMain,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Продолжить'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _createGroup,
                    icon: const Icon(Icons.add_circle_outline),
                    label: Text(_loading ? 'Создаю...' : '✨ Создать группу'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'или',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: _codeController,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 11,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                  decoration: InputDecoration(
                    hintText: 'ABC-123-XYZ',
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.accent,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    final upper = value.toUpperCase();
                    if (upper != value) {
                      _codeController.value = TextEditingValue(
                        text: upper,
                        selection: TextSelection.collapsed(offset: upper.length),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _joinGroup,
                    icon: const Icon(Icons.link),
                    label: Text(_loading ? 'Подключаюсь...' : '🔗 Присоединиться'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.info,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                TextButton(
                  onPressed: _loading ? null : _continueLocally,
                  child: const Text(
                    'Работать локально',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),

                TextButton.icon(
                  onPressed: _loading ? null : _testConnection,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('🔍 Проверить соединение'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.info,
                  ),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE5E5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.danger),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}