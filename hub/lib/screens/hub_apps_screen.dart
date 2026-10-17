import 'package:flutter/material.dart';
import '../services/apps_service.dart';
import '../services/storage_service.dart';
import '../widgets/glass_container.dart';

/// Экран «Меню приложений» (слева от центра).
/// 
/// Сетка приложений по категориям. Избранные — сверху.
class HubAppsScreen extends StatefulWidget {
  final StorageService storage;
  final AppsService appsService;
  final Future<void> Function(String packageName) onLaunchApp;

  const HubAppsScreen({
    super.key,
    required this.storage,
    required this.appsService,
    required this.onLaunchApp,
  });

  @override
  State<HubAppsScreen> createState() => _HubAppsScreenState();
}

class _HubAppsScreenState extends State<HubAppsScreen> {
  @override
  void initState() {
    super.initState();
    widget.appsService.addListener(_reload);
  }

  @override
  void dispose() {
    widget.appsService.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final service = widget.appsService;

    // Если приложения ещё не загрузились — заглушка
    if (service.apps.isEmpty) {
      return _buildEmptyState(cs);
    }

    final favorites = service.favorites;
    final categories = service.categories;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.apps, color: cs.primary, size: 28),
              const SizedBox(width: 10),
              Text(
                'Приложения',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.add_box_outlined, color: cs.primary, size: 26),
                tooltip: 'Новая категория',
                onPressed: () => _showAddCategoryDialog(cs),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                // Избранные
                if (favorites.isNotEmpty) ...[
                  _sectionTitle('Избранное', cs),
                  const SizedBox(height: 10),
                  _appsGrid(favorites, cs),
                  const SizedBox(height: 20),
                ],
                // Категории
                ...categories.map((cat) {
                  final apps = service.appsInCategory(cat.id);
                  if (apps.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('${cat.emoji} ${cat.name}', cs),
                      const SizedBox(height: 10),
                      _appsGrid(apps, cs),
                      const SizedBox(height: 20),
                    ],
                  );
                }),
                // Без категории
                if (service.uncategorized.isNotEmpty) ...[
                  _sectionTitle('📦 Без категории', cs),
                  const SizedBox(height: 10),
                  _appsGrid(service.uncategorized, cs),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.apps, color: cs.primary, size: 28),
              const SizedBox(width: 10),
              Text(
                'Приложения',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GlassContainer(
              radius: 28,
              showAllBorder: true,
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.apps, size: 64, color: cs.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text(
                      'Список приложений пуст',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Плагин flutter_device_apps будет подключён на следующем шаге',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
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

  Widget _sectionTitle(String text, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: cs.onSurfaceVariant,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _appsGrid(List<AppInfo> apps, ColorScheme cs) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: apps.length,
      itemBuilder: (ctx, i) {
        return _appTile(apps[i], cs);
      },
    );
  }

  Widget _appTile(AppInfo app, ColorScheme cs) {
    return GestureDetector(
      onTap: () => widget.onLaunchApp(app.packageName),
      onLongPress: () => _showAppMenu(app, cs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outline),
            ),
            padding: const EdgeInsets.all(8),
            child: app.icon != null
                ? Image.memory(app.icon!, fit: BoxFit.contain)
                : Icon(Icons.apps, color: cs.onSurfaceVariant, size: 32),
          ),
          const SizedBox(height: 6),
          Text(
            app.appName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAppMenu(AppInfo app, ColorScheme cs) async {
    final service = widget.appsService;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassContainer(
        radius: 28,
        showAllBorder: true,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(app.appName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface)),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                app.isFavorite ? Icons.star : Icons.star_border,
                color: cs.secondary,
              ),
              title: Text(app.isFavorite ? 'Убрать из избранного' : 'В избранное'),
              onTap: () {
                service.toggleFavorite(app.packageName);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.category, color: cs.primary),
              title: const Text('Переместить в категорию'),
              onTap: () {
                Navigator.pop(ctx);
                _showMoveToCategory(app, cs);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMoveToCategory(AppInfo app, ColorScheme cs) async {
    final service = widget.appsService;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Категория'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...service.categories.map((c) => RadioListTile<String?>(
              value: c.id,
              groupValue: app.categoryId,
              onChanged: (v) {
                service.setCategoryForApp(app.packageName, v);
                Navigator.pop(ctx);
              },
              title: Text('${c.emoji} ${c.name}'),
            )),
            RadioListTile<String?>(
              value: null,
              groupValue: app.categoryId,
              onChanged: (v) {
                service.setCategoryForApp(app.packageName, null);
                Navigator.pop(ctx);
              },
              title: const Text('📦 Без категории'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddCategoryDialog(ColorScheme cs) async {
    final nameCtrl = TextEditingController();
    final emojiCtrl = TextEditingController(text: '📱');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая категория'),
        content: Row(
          children: [
            SizedBox(
              width: 70,
              child: TextField(
                controller: emojiCtrl,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24),
                decoration: const InputDecoration(labelText: 'Эмодзи'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Название'),
                autofocus: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final emoji = emojiCtrl.text.trim();
              if (name.isEmpty) return;
              await widget.appsService.addCategory(name, emoji.isEmpty ? '📱' : emoji);
              Navigator.pop(ctx, true);
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );

    if (ok == true) setState(() {});
  }
}