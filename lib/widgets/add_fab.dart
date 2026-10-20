import 'package:flutter/material.dart';

/// Содержимое меню FAB (то, что открывается при нажатии на "+")
class AddFabContent extends StatelessWidget {
  final void Function(int kind) onPick;
  
  // kind: 0=покупка, 1=задача, 2=смена, 3=расход, 4=доход, 5=перевод

  const AddFabContent({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: cs.outline.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _menuItem(Icons.shopping_bag_outlined, 'Покупка', cs.primary, 0, cs),
              const SizedBox(width: 12),
              _menuItem(Icons.check_circle_outline, 'Задача', cs.tertiary, 1, cs),
              const SizedBox(width: 12),
              _menuItem(Icons.calendar_today_outlined, 'Смена', cs.secondary, 2, cs),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _menuItem(Icons.payments_outlined, 'Расход', cs.error, 3, cs),
              const SizedBox(width: 12),
              _menuItem(Icons.trending_up, 'Доход', cs.tertiary, 4, cs),
              const SizedBox(width: 12),
              _menuItem(Icons.swap_horiz, 'Перевод', cs.secondary, 5, cs),
            ],
          ),
        ],
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, Color color, int kind, ColorScheme cs) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onPick(kind),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: cs.surfaceVariant, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Старый AddFab (кнопка) — оставляем для совместимости, но больше не используем в main.dart
class AddFab extends StatelessWidget {
  final void Function(int kind) onPick;
  const AddFab({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    // Возвращаем пустой контейнер, так как кнопка теперь в CurvedNavBar
    return const SizedBox.shrink();
  }
}