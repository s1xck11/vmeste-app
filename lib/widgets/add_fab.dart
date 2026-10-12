// lib/widgets/add_fab.dart

import 'package:flutter/material.dart';

/// Центральная кнопка "+" над плавающим навбаром.
/// 
/// Вписана в навбар: сидит на нём, выпирает вверх на ~24px.
/// Без агрессивной обводки, с мягкой тенью.
/// 
/// onPick получает индекс:
///   0 = покупка, 1 = задача, 2 = смена, 3 = расход
class AddFab extends StatefulWidget {
  final void Function(int kind) onPick;

  const AddFab({super.key, required this.onPick});

  @override
  State<AddFab> createState() => _AddFabState();
}

class _AddFabState extends State<AddFab> with SingleTickerProviderStateMixin {
  bool _open = false;
  late AnimationController _ctrl;
  late Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _rotate = Tween<double>(begin: 0, end: 0.125).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  void _pick(int kind) {
    _toggle();
    Future.delayed(const Duration(milliseconds: 150), () {
      widget.onPick(kind);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Меню — над FAB
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.bottomCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _menuItem(
                        icon: Icons.shopping_bag_outlined,
                        label: 'Покупка',
                        color: cs.primary,
                        onTap: () => _pick(0),
                        cs: cs,
                      ),
                      const SizedBox(height: 8),
                      _menuItem(
                        icon: Icons.check_circle_outline,
                        label: 'Задача',
                        color: cs.tertiary,
                        onTap: () => _pick(1),
                        cs: cs,
                      ),
                      const SizedBox(height: 8),
                      _menuItem(
                        icon: Icons.calendar_today_outlined,
                        label: 'Смена',
                        color: cs.secondary,
                        onTap: () => _pick(2),
                        cs: cs,
                      ),
                      const SizedBox(height: 8),
                      _menuItem(
                        icon: Icons.payments_outlined,
                        label: 'Расход',
                        color: cs.error,
                        onTap: () => _pick(3),
                        cs: cs,
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        // Круглая кнопка — обводка цвета навбара, чтобы «вписалась»
        GestureDetector(
          onTap: _toggle,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
              // Обводка в цвет стекла навбара — визуально «прикрепляет» к навбару
              border: Border.all(
                color: (isDark ? const Color(0xFF1C1A1B) : Colors.white)
                    .withOpacity(0.95),
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _rotate,
              builder: (ctx, _) => Transform.rotate(
                angle: _rotate.value * 3.14159 * 2,
                child: Icon(Icons.add, color: cs.onPrimary, size: 26),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceVariant,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cs.outline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}