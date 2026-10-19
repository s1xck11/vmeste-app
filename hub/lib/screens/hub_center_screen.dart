void _showLauncherHint() {
  final updateService = UpdateService();
  
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => GlassContainer(
      radius: 32,
      showAllBorder: true,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Настройки', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.system_update_alt),
            title: const Text('Проверить обновления'),
            subtitle: Text('Версия ${UpdateService.currentFull}'),
            onTap: () async {
              Navigator.pop(ctx);
              final info = await updateService.checkForUpdate();
              if (!mounted) return;
              if (info == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Обновлений нет')));
              } else {
                _showUpdateDialog(info, updateService);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Как сделать хаб домашним'),
            onTap: () {
              Navigator.pop(ctx);
              _showHomeHint();
            },
          ),
        ],
      ),
    ),
  );
}

void _showHomeHint() {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Домашний экран'),
      content: const Text(
        '1. Нажми кнопку «Домой» на планшете\n'
        '2. В списке выбери «Вместе Хаб»\n'
        '3. Поставь галочку «Всегда»\n\n'
        'Теперь кнопка «Домой» будет возвращать в хаб.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Понятно')),
      ],
    ),
  );
}

void _showUpdateDialog(UpdateInfo info, UpdateService service) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Доступно обновление ${info.version}'),
      content: Text(info.body.isNotEmpty ? info.body : 'Новая версия хаба'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Позже')),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            // Простейшая установка без прогресс-бара для краткости
            final file = await service.downloadApk(info);
            if (file != null) await service.installApk(file);
          },
          child: const Text('Скачать'),
        ),
      ],
    ),
  );
}