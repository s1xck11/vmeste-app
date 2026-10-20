import 'package:flutter/material.dart';

class CurvedNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback onFabTap;
  final ColorScheme cs;

  const CurvedNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onFabTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    const double barHeight = 68.0;
    const double fabRadius = 28.0; // Половина от 56.0
    const double notchRadius = fabRadius + 8.0; // Вырез чуть больше кнопки

    return SizedBox(
      height: barHeight + 20, // Запас сверху для выреза
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // 1. Фон навбара с вырезом
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: CustomPaint(
              painter: _NavBarPainter(
                color: cs.surface,
                notchRadius: notchRadius,
                barHeight: barHeight,
              ),
              child: SizedBox(
                height: barHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _navItem(0, Icons.shopping_bag_outlined, Icons.shopping_bag, 'Покупки', cs),
                      _navItem(1, Icons.check_circle_outline, Icons.check_circle, 'Задачи', cs),
                      const SizedBox(width: 72), // Место под FAB
                      _navItem(2, Icons.calendar_today_outlined, Icons.calendar_today, 'Смены', cs),
                      _navItem(3, Icons.pie_chart_outline, Icons.pie_chart, 'Кошелёк', cs),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. FAB в вырезе (без тени, как просил)
          Positioned(
            bottom: barHeight - fabRadius - 4, // Поднимаем чуть выше края
            child: GestureDetector(
              onTap: onFabTap,
              child: Container(
                width: fabRadius * 2,
                height: fabRadius * 2,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                  // Убрали тень
                ),
                child: Icon(Icons.add, color: cs.onPrimary, size: 32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData activeIcon, String label, ColorScheme cs) {
    final selected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? activeIcon : icon, size: 24, color: selected ? cs.primary : cs.onSurfaceVariant),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBarPainter extends CustomPainter {
  final Color color;
  final double notchRadius;
  final double barHeight;

  _NavBarPainter({
    required this.color,
    required this.notchRadius,
    required this.barHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    const radius = 32.0; // Скругление самого навбара
    final centerX = size.width / 2;
    
    // Стартуем сверху слева, но с учетом выреза
    // 1. Левая часть (до выреза)
    path.moveTo(radius, 0);
    path.lineTo(centerX - notchRadius - 10, 0); // -10 для плавности
    
    // 2. Вырез (полукруг вниз)
    path.quadraticBezierTo(
      centerX - notchRadius, 0, 
      centerX - notchRadius, notchRadius / 2
    );
    path.arcToPoint(
      Offset(centerX + notchRadius, notchRadius / 2),
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );
    path.quadraticBezierTo(
      centerX + notchRadius, 0, 
      centerX + notchRadius + 10, 0
    );
    
    // 3. Правая часть
    path.lineTo(size.width - radius, 0);
    
    // 4. Правый нижний угол
    path.arcToPoint(
      Offset(size.width, radius),
      radius: Radius.circular(radius),
      clockwise: true,
    );
    
    // 5. Низ
    path.lineTo(size.width, size.height - radius);
    path.arcToPoint(
      Offset(size.width - radius, size.height),
      radius: Radius.circular(radius),
      clockwise: true,
    );
    
    // 6. Низ лево
    path.lineTo(radius, size.height);
    path.arcToPoint(
      Offset(0, size.height - radius),
      radius: Radius.circular(radius),
      clockwise: true,
    );
    
    // 7. Левая сторона
    path.lineTo(0, radius);
    path.arcToPoint(
      Offset(radius, 0),
      radius: Radius.circular(radius),
      clockwise: true,
    );

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}