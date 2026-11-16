// tv/lib/screens/tv_setup_screen.dart

import 'package:flutter/material.dart';

import '../main.dart' show sync;
import '../services/tv_sync_service.dart';
import '../theme/tv_theme.dart';
import '../widgets/tv_focusable.dart';

class TvSetupScreen extends StatefulWidget {
  const TvSetupScreen({super.key});

  @override
  State<TvSetupScreen> createState() => _TvSetupScreenState();
}

class _TvSetupScreenState extends State<TvSetupScreen> {
  final TextEditingController _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _connect() {
    if (sync.status == TvSyncStatus.connecting) return;
    FocusScope.of(context).unfocus();
    sync.connect(_code.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite_rounded, size: 72, color: TvColors.accent),
              const SizedBox(height: 16),
              Text('Вместе ТВ', style: TvText.heroNumber),
              const SizedBox(height: 8),
              Text('Домашний экран для вас двоих', style: TvText.bodyDim),
              const SizedBox(height: 40),
              TvTextField(
                controller: _code,
                label: 'Код группы',
                hint: 'Например: AB12CD',
                autofocus: true,
                onSubmit: _connect,
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: sync,
                builder: (_, __) {
                  if (sync.errorText == null || sync.isOnline) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      sync.errorText!,
                      style: TvText.caption.copyWith(color: TvColors.danger),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TvFocusable(
                  onTap: _connect,
                  scale: 1.02,
                  radius: 14,
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: TvColors.accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: AnimatedBuilder(
                        animation: sync,
                        builder: (_, __) => Text(
                          sync.status == TvSyncStatus.connecting
                              ? 'Подключение…'
                              : 'Подключиться',
                          style: TvText.button.copyWith(color: Colors.black),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Код группы: мобильное приложение → Настройки → Код группы',
                style: TvText.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
