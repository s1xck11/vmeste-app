import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../widgets/glass_container.dart';

/// Экран «Меню приложений».
/// 
/// Пока заглушка — реальный список приложений будет на этапе 7.
class HubAppsScreen extends StatelessWidget {
  final StorageService storage;

  const HubAppsScreen({
    super.key,
    required this.storage,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _header('Приложения', cs),
          const SizedBox(height: 16),
          Expanded(
            child: GlassContainer(
              radius: 28,
              showAllBorder: true,
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.apps, size: 64, color: cs.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text(
                      'Список приложений',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Подключим на этапе 7',
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(String title, ColorScheme cs) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const Spacer(),
        Text(
          'свайп → вправо к центру',
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}