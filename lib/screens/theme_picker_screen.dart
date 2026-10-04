// lib/screens/theme_picker_screen.dart

import 'package:flutter/material.dart';
import '../theme/app_theme_config.dart';
import '../services/theme_service.dart';

class ThemePickerScreen extends StatelessWidget {
  final ThemeService themeService;

  const ThemePickerScreen({super.key, required this.themeService});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeConfig>(
      valueListenable: themeService.notifier,
      builder: (context, config, _) {
        final cs = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Оформление'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              // ---------- ЯРКОСТЬ ----------
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 8),
                child: Text(
                  'РЕЖИМ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _BrightnessTile(
                      label: 'Светлая',
                      icon: Icons.wb_sunny_outlined,
                      selected: config.brightness == Brightness.light,
                      onTap: () => themeService.setBrightness(Brightness.light),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BrightnessTile(
                      label: 'Тёмная',
                      icon: Icons.nightlight_outlined,
                      selected: config.brightness == Brightness.dark,
                      onTap: () => themeService.setBrightness(Brightness.dark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ---------- ПАЛИТРЫ ----------
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'ПАЛИТРА',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.35,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: AppThemeConfig.allIds.length,
                itemBuilder: (ctx, i) {
                  final id = AppThemeConfig.allIds[i];
                  final palette = AppThemeConfig.paletteById(id, config.brightness);
                  final selected = palette.id == config.palette.id;
                  return _PaletteTile(
                    palette: palette,
                    selected: selected,
                    onTap: () => themeService.setPalette(id),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// ЯРКОСТЬ
// ============================================================

class _BrightnessTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _BrightnessTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? cs.primary.withOpacity(0.12) : cs.surfaceVariant,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? cs.primary : cs.outline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: selected ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? cs.primary : cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ПЛИТКА ПАЛИТРЫ
// ============================================================

class _PaletteTile extends StatelessWidget {
  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  const _PaletteTile({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? palette.accent : cs.outline,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Превью из трёх кругов: акцент, мягкий, глубокий
              Row(
                children: [
                  _dot(palette.accent),
                  const SizedBox(width: 4),
                  _dot(palette.accentSoft),
                  const SizedBox(width: 4),
                  _dot(palette.accentDeep),
                  const Spacer(),
                  if (selected)
                    Icon(Icons.check_circle, color: palette.accent, size: 20),
                ],
              ),
              const Spacer(),
              // Имя палитры
              Text(
                palette.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              // Маленький текст как в реальной карточке
              Text(
                'Aa Бб 123',
                style: TextStyle(
                  fontSize: 10,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(Color c) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
      ),
    );
  }
}