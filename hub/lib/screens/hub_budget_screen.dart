import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../widgets/glass_container.dart';

/// Экран «Бюджет» (справа от центра).
/// 
/// Пока заглушка — реальная адаптация мобильного бюджета будет позже.
class HubBudgetScreen extends StatelessWidget {
  final StorageService storage;
  final SyncService sync;

  const HubBudgetScreen({
    super.key,
    required this.storage,
    required this.sync,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final txCount = storage.transactions.length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Бюджет',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                'свайп ← к центру',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
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
                    Icon(Icons.pie_chart_outline,
                        size: 64, color: cs.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Бюджет',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Транзакций: $txCount',
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Полная адаптация — на этапе 6',
                      style: TextStyle(
                        fontSize: 12,
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
}