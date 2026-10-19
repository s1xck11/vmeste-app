import 'package:flutter/material.dart';

class AddFab extends StatelessWidget {
  final void Function(int kind) onPick;
  
  // kind: 0=покупка, 1=задача, 2=смена, 3=расход, 4=доход

  const AddFab({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _showMenu(context),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: cs.primary,
          shape: BoxShape.circle,
          border: Border.all(
            color: cs.surface, // Цвет окантовки под навбар
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(Icons.add, color: cs.onPrimary, size: 28),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.18), // Затемнение на 18%
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cs.surface.withOpacity(0.95),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: cs.outline.withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ряд 1: Покупка, Задача, Смена
                  Row(
                    children: [
                      _menuItem(ctx, Icons.shopping_bag_outlined, 'Покупка', cs.primary, 0, cs),
                      const SizedBox(width: 12),
                      _menuItem(ctx, Icons.check_circle_outline, 'Задача', cs.tertiary, 1, cs),
                      const SizedBox(width: 12),
                      _menuItem(ctx, Icons.calendar_today_outlined, 'Смена', cs.secondary, 2, cs),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Ряд 2: Расход, Доход (по центру)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _menuItem(ctx, Icons.payments_outlined, 'Расход', cs.error, 3, cs),
                      const SizedBox(width: 12),
                      _menuItem(ctx, Icons.trending_up, 'Доход', cs.success, 4, cs),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _menuItem(BuildContext ctx, IconData icon, String label, Color color, int kind, ColorScheme cs) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Navigator.pop(ctx);
          onPick(kind);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: cs.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}