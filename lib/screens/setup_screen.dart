// lib/screens/setup_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/sync_service.dart';
import '../services/storage_service.dart';
import '../services/theme_service.dart';
import '../main.dart' show AppColors, MainScreen;

class SetupScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;
  final ThemeService themeService;

  const SetupScreen({
    super.key,
    required this.storage,
    required this.sync,
    required this.themeService,
  });

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  bool _loading = false;
  String? _error;

  String? _createdCode;
  String? _createdKey;

  String _mode = 'main';

  @override
  void dispose() {
    _codeController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.sync.createGroup();
      setState(() {
        _createdCode = result['code'];
        _createdKey = result['myKey'];
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
      widget.storage.coupleCode = code;
      final myKey = await widget.sync.joinGroup(code);

      setState(() {
        _createdCode = code;
        _createdKey = myKey;
        _loading = false;
      });
    } catch (e) {
      widget.storage.coupleCode = null;
      setState(() {
        _error = 'Ошибка: $e';
        _loading = false;
      });
    }
  }

  Future<void> _restoreByKey() async {
    final key = _keyController.text.trim().toUpperCase();
    if (key.length < 9) {
      setState(() => _error = 'Введите ключ (например, M-7X4K-9P2Q)');
      return;
    }

    final code = _codeController.text.trim().toUpperCase();
    if (code.length < 9) {
      setState(() => _error = 'Сначала введи код группы');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      widget.storage.coupleCode = code;
      await widget.sync.restoreByKey(key);
      _goToMain();
    } catch (e) {
      widget.storage.coupleCode = null;
      setState(() {
        _error = 'Ошибка: $e';
        _loading = false;
      });
    }
  }

  void _goToMain() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MainScreen(
          storage: widget.storage,
          sync: widget.sync,
          themeService: widget.themeService,
        ),
      ),
    );
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Скопировано')),
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
                child: const Icon(Icons.favorite, size: 56, color: AppColors.accent),
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
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),

              if (_createdCode != null) ...[
                _showCreatedCard(),
              ] else if (_mode == 'main') ...[
                _showMainMenu(),
              ] else if (_mode == 'join') ...[
                _showJoinForm(),
              ] else if (_mode == 'restore') ...[
                _showRestoreForm(),
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
                      fontSize: 12,
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

  Widget _showMainMenu() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _createGroup,
            icon: const Icon(Icons.add_circle_outline),
            label: Text(_loading ? 'Создаю...' : '✨ Создать новую группу'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : () => setState(() { _mode = 'join'; _error = null; }),
            icon: const Icon(Icons.link),
            label: const Text('🔗 Присоединиться по коду'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.info,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _loading ? null : () => setState(() { _mode = 'restore'; _error = null; }),
            icon: const Icon(Icons.key),
            label: const Text('🔑 Войти под своим ключом'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent),
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _showJoinForm() {
    return Column(
      children: [
        const Text(
          'Введи код группы',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _codeController,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          maxLength: 11,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
          decoration: InputDecoration(
            hintText: 'ABC-123-XYZ',
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _joinGroup,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.info,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(_loading ? 'Подключаюсь...' : 'Присоединиться'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() { _mode = 'main'; _error = null; }),
          child: const Text('Назад', style: TextStyle(color: AppColors.textSecondary)),
        ),
      ],
    );
  }

  Widget _showRestoreForm() {
    return Column(
      children: [
        const Text(
          'Восстановление доступа',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Введи код группы и свой личный ключ',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _codeController,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          maxLength: 11,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 2),
          decoration: InputDecoration(
            hintText: 'Код группы',
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _keyController,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          maxLength: 11,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 2),
          decoration: InputDecoration(
            hintText: 'M-XXXX-XXXX',
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _restoreByKey,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(_loading ? 'Восстанавливаю...' : 'Войти'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() { _mode = 'main'; _error = null; }),
          child: const Text('Назад', style: TextStyle(color: AppColors.textSecondary)),
        ),
      ],
    );
  }

  Widget _showCreatedCard() {
    return Column(
      children: [
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
                '🎉 Готово!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Код группы (отправь партнёру):',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                _createdCode!,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _copy(_createdCode!),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Скопировать код'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      '🔑 Твой личный ключ:',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _createdKey!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontFamily: 'monospace',
                        color: AppColors.info,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Сохрани его! Он нужен для входа с нового телефона.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _copy(_createdKey!),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Скопировать ключ'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.info,
                        side: const BorderSide(color: AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _goToMain,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Продолжить'),
          ),
        ),
      ],
    );
  }
}