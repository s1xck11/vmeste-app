// tv/lib/screens/tv_settings_screen.dart
//
// Настройки: плитки (CRUD + порядок), группа, система (автозапуск, выход).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../main.dart' show sync, tiles, showExitDialog;
import '../services/tiles_service.dart';
import '../theme/tv_theme.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/tv_tile.dart';

class TvSettingsScreen extends StatefulWidget {
  const TvSettingsScreen({super.key});

  @override
  State<TvSettingsScreen> createState() => _TvSettingsScreenState();
}

class _TvSettingsScreenState extends State<TvSettingsScreen> {
  String get _startupBat =>
      '${Platform.environment['APPDATA']}\\Microsoft\\Windows\\Start Menu\\Programs\\Startup\\VmesteTV.bat';

  bool _autostart = false;

  @override
  void initState() {
    super.initState();
    _autostart = File(_startupBat).existsSync();
  }

  Future<void> _setAutostart(bool v) async {
    try {
      final f = File(_startupBat);
      if (v) {
        await f.writeAsString(
          '@echo off\r\nstart "" "${Platform.resolvedExecutable}"\r\n',
        );
      } else if (f.existsSync()) {
        await f.delete();
      }
      if (mounted) setState(() => _autostart = v);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: TvColors.cardHi,
            content: Text('Не удалось изменить автозапуск', style: TvText.body),
          ),
        );
      }
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: TvColors.cardHi, content: Text(text, style: TvText.body)),
    );
  }

  // ---------- редактор плитки ----------

  Future<void> _editor(TvTile? t) async {
    final titleC = TextEditingController(text: t?.title ?? '');
    final targetC = TextEditingController(text: t?.target ?? '');
    var kind = t?.kind ?? TvTileKind.web;
    var colorIndex = t?.colorIndex ?? 0;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: TvColors.cardHi,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(t == null ? 'Новая плитка' : 'Редактировать плитку', style: TvText.cardTitle),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TvTextField(controller: titleC, label: 'Название', hint: 'YouTube', autofocus: t == null),
                  const SizedBox(height: 14),
                  TvTextField(
                    controller: targetC,
                    label: 'Ссылка или путь',
                    hint: kind == TvTileKind.app ? 'C:\\Games\\game.exe' : 'https://youtube.com',
                  ),
                  const SizedBox(height: 16),
                  Text('Тип', style: TvText.caption),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _kindChip(ctx, setD, 'Внутри лаунчера', TvTileKind.web, kind, (k) => kind = k),
                      _kindChip(ctx, setD, 'В настоящем Edge', TvTileKind.webExternal, kind, (k) => kind = k),
                      _kindChip(ctx, setD, 'Программа / файл', TvTileKind.app, kind, (k) => kind = k),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Цвет', style: TvText.caption),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (var i = 0; i < TilesService.gradients.length; i++)
                        TvFocusable(
                          onTap: () => setD(() => colorIndex = i),
                          scale: 1.1,
                          radius: 12,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: TilesService.gradients[i],
                              ),
                            ),
                            child: colorIndex == i
                                ? const Icon(Icons.check_rounded, color: Colors.white)
                                : null,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TvDialogButton(label: 'Отмена', onTap: () => Navigator.pop(ctx)),
            TvDialogButton(
              label: 'Сохранить',
              primary: true,
              onTap: () async {
                if (titleC.text.trim().isEmpty || targetC.text.trim().isEmpty) {
                  _snack('Заполни название и ссылку/путь');
                  return;
                }
                if (t == null) {
                  await tiles.add(
                    title: titleC.text,
                    target: targetC.text,
                    kind: kind,
                    colorIndex: colorIndex,
                  );
                } else {
                  t.title = titleC.text.trim();
                  t.target = targetC.text;
                  t.kind = kind;
                  t.colorIndex = colorIndex;
                  await tiles.updateTile(t);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
    titleC.dispose();
    targetC.dispose();
  }

  Widget _kindChip(BuildContext ctx, void Function(void Function()) setD,
      String label, TvTileKind value, TvTileKind current, void Function(TvTileKind) set) {
    final selected = value == current;
    return TvFocusable(
      onTap: () => setD(() => set(value)),
      scale: 1.05,
      radius: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? TvColors.accent.withOpacity(0.25) : TvColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? TvColors.accent : TvColors.outline),
        ),
        child: Text(label, style: TvText.caption.copyWith(color: TvColors.text)),
      ),
    );
  }

  Future<void> _confirmDelete(TvTile t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TvColors.cardHi,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Удалить плитку?', style: TvText.cardTitle),
        content: Text('«${t.title}» исчезнет с главного экрана.', style: TvText.bodyDim),
        actions: [
          TvDialogButton(label: 'Отмена', onTap: () => Navigator.pop(ctx, false)),
          TvDialogButton(label: 'Удалить', danger: true, onTap: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (ok == true) await tiles.remove(t.id);
  }

  Future<void> _changeGroup() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TvColors.cardHi,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Сменить группу?', style: TvText.cardTitle),
        content: Text('ТВ отключится от текущей группы и покажет экран ввода кода.', style: TvText.bodyDim),
        actions: [
          TvDialogButton(label: 'Отмена', onTap: () => Navigator.pop(ctx, false)),
          TvDialogButton(label: 'Сменить', primary: true, onTap: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (ok == true) await sync.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(TvSpace.screenH, 20, TvSpace.screenH, 0),
        child: Column(
          children: [
            Row(
              children: [
                TvIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Назад (B)',
                  autofocus: true,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 16),
                Text('Настройки', style: TvText.rowTitle),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ListView(
                children: [
                  const TvSectionTitle('Плитки'),
                  AnimatedBuilder(
                    animation: tiles,
                    builder: (_, __) => Column(
                      children: [
                        for (final t in tiles.tiles) _tileRow(t),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TvDialogButton(
                      label: '＋ Добавить плитку',
                      primary: true,
                      onTap: () => _editor(null),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const TvSectionTitle('Группа'),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: TvDecor.card(radius: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Код группы', style: TvText.caption),
                              const SizedBox(height: 4),
                              Text(sync.groupCode ?? '—', style: TvText.heroNumber.copyWith(fontSize: 32)),
                            ],
                          ),
                        ),
                        TvDialogButton(
                          label: 'Обновить сейчас',
                          onTap: () async {
                            await sync.pullNow();
                            if (mounted) _snack('Данные обновлены');
                          },
                        ),
                        const SizedBox(width: 10),
                        TvDialogButton(label: 'Сменить группу', onTap: _changeGroup),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const TvSectionTitle('Система'),
                  Container(
                    decoration: TvDecor.card(radius: 14),
                    child: SwitchListTile(
                      value: _autostart,
                      onChanged: _setAutostart,
                      activeColor: TvColors.accent,
                      title: Text('Запускать вместе с Windows', style: TvText.body),
                      subtitle: Text('Ярлык в папке автозагрузки', style: TvText.caption),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TvDialogButton(
                        label: 'Свернуть лаунчер',
                        onTap: () async {
                          await windowManager.setFullScreen(false);
                          await windowManager.minimize();
                        },
                      ),
                      const SizedBox(width: 10),
                      TvDialogButton(
                        label: 'Выйти в Windows',
                        danger: true,
                        onTap: () => showExitDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Вместе ТВ • 1.0 • синк только чтение', style: TvText.caption),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tileRow(TvTile t) {
    final g = TilesService.gradients[t.colorIndex % TilesService.gradients.length];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: TvDecor.card(radius: 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: g),
            ),
            child: Icon(tvTileIcon(t), color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title, style: TvText.body.copyWith(fontWeight: FontWeight.w600)),
                Text(t.target, style: TvText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: TvColors.cardHi, borderRadius: BorderRadius.circular(8)),
            child: Text(
              t.kind == TvTileKind.web ? 'внутри' : t.kind == TvTileKind.webExternal ? 'Edge' : 'exe',
              style: TvText.caption,
            ),
          ),
          const SizedBox(width: 10),
          TvIconButton(icon: Icons.chevron_left_rounded, tooltip: 'Левее', onTap: () => tiles.move(t.id, -1)),
          const SizedBox(width: 6),
          TvIconButton(icon: Icons.chevron_right_rounded, tooltip: 'Правее', onTap: () => tiles.move(t.id, 1)),
          const SizedBox(width: 6),
          TvIconButton(icon: Icons.edit_rounded, tooltip: 'Изменить', onTap: () => _editor(t)),
          const SizedBox(width: 6),
          TvIconButton(icon: Icons.delete_outline_rounded, tooltip: 'Удалить', color: TvColors.danger, onTap: () => _confirmDelete(t)),
        ],
      ),
    );
  }
}
