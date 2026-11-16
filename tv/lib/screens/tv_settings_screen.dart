// tv/lib/screens/tv_settings_screen.dart
//
// Настройки: плитки, группа, погода (город), обои, звук, управление, система.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../main.dart' show sync, tiles, showExitDialog;
import '../services/hints_service.dart';
import '../services/input_service.dart';
import '../services/sound_service.dart';
import '../services/tiles_service.dart';
import '../services/wallpaper_service.dart';
import '../services/weather_service.dart';
import '../theme/tv_theme.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/tv_tile.dart';

class TvSettingsScreen extends StatefulWidget {
  const TvSettingsScreen({super.key});

  @override
  State<TvSettingsScreen> createState() => _TvSettingsScreenState();
}

class _TvSettingsScreenState extends State<TvSettingsScreen> {
  final TextEditingController _cityC = TextEditingController();
  List<Map<String, dynamic>> _cityResults = [];
  bool _cityBusy = false;

  String get _startupBat =>
      '${Platform.environment['APPDATA']}\\Microsoft\\Windows\\Start Menu\\Programs\\Startup\\VmesteTV.bat';

  bool _autostart = false;

  @override
  void initState() {
    super.initState();
    _autostart = File(_startupBat).existsSync();
    HintsService.instance.base([
      'Крестовина — выбор, A — изменить',
      'B — назад на главный',
    ]);
  }

  @override
  void dispose() {
    _cityC.dispose();
    super.dispose();
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
      _snack('Не удалось изменить автозапуск');
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: TvColors.cardHi, content: Text(text, style: TvText.body)),
    );
  }

  Future<void> _searchCity() async {
    setState(() => _cityBusy = true);
    try {
      final res = await WeatherService.instance.search(_cityC.text);
      if (mounted) setState(() => _cityResults = res);
      if (res.isEmpty) _snack('Ничего не найдено');
    } catch (_) {
      _snack('Не удалось искать город (нет сети?)');
    }
    if (mounted) setState(() => _cityBusy = false);
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
                      _kindChip(setD, 'Внутри лаунчера', TvTileKind.web, kind, (k) => kind = k),
                      _kindChip(setD, 'В настоящем Edge', TvTileKind.webExternal, kind, (k) => kind = k),
                      _kindChip(setD, 'Программа / файл', TvTileKind.app, kind, (k) => kind = k),
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

  Widget _kindChip(void Function(void Function()) setD, String label,
      TvTileKind value, TvTileKind current, void Function(TvTileKind) set) {
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

  Widget _stepper({
    required String label,
    required double value,
    required double min,
    required double max,
    required double step,
    required ValueChanged<double> onChanged,
    String Function(double)? fmt,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TvText.body)),
          TvIconButton(
            icon: Icons.remove_rounded,
            onTap: () => onChanged((value - step).clamp(min, max).toDouble()),
          ),
          SizedBox(
            width: 84,
            child: Text(
              fmt == null ? value.toStringAsFixed(2) : fmt(value),
              textAlign: TextAlign.center,
              style: TvText.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          TvIconButton(
            icon: Icons.add_rounded,
            onTap: () => onChanged((value + step).clamp(min, max).toDouble()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wp = WallpaperService.instance;
    final snd = SoundService.instance;
    final weather = WeatherService.instance;
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
                      children: [for (final t in tiles.tiles) _tileRow(t)],
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

                  const TvSectionTitle('Погода'),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: TvDecor.card(radius: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Сейчас: ${weather.city}', style: TvText.body),
                        const SizedBox(height: 12),
                        TvTextField(controller: _cityC, label: 'Найти город', hint: 'Казань'),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TvDialogButton(
                            label: _cityBusy ? 'Ищу…' : 'Найти',
                            onTap: _cityBusy ? () {} : _searchCity,
                          ),
                        ),
                        if (_cityResults.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          for (final r in _cityResults)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: TvDialogButton(
                                  label: '${r['name']}${r['admin1'] != null ? ', ${r['admin1']}' : ''} (${r['country'] ?? ''})',
                                  onTap: () async {
                                    await weather.setCity(
                                      r['name'] as String,
                                      (r['latitude'] as num).toDouble(),
                                      (r['longitude'] as num).toDouble(),
                                    );
                                    if (mounted) setState(() => _cityResults = []);
                                    _snack('Город обновлён');
                                  },
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  const TvSectionTitle('Обои'),
                  AnimatedBuilder(
                    animation: wp,
                    builder: (_, __) => Container(
                      padding: const EdgeInsets.all(18),
                      decoration: TvDecor.card(radius: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (var i = 0; i < WallpaperService.presets.length; i++)
                                TvFocusable(
                                  onTap: () => wp.setPreset(i),
                                  scale: 1.06,
                                  radius: 14,
                                  child: Container(
                                    width: 132,
                                    height: 76,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: WallpaperService.presets[i].colors,
                                      ),
                                      border: Border.all(
                                        color: wp.mode == 'preset' && wp.index == i
                                            ? TvColors.focus
                                            : TvColors.outline,
                                        width: wp.mode == 'preset' && wp.index == i ? 3 : 1,
                                      ),
                                    ),
                                    child: Align(
                                      alignment: Alignment.bottomLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text(
                                          WallpaperService.presets[i].name,
                                          style: TvText.caption.copyWith(color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              TvDialogButton(
                                label: 'Своя картинка…',
                                primary: wp.mode == 'image',
                                onTap: () async {
                                  final err = await wp.pickImage();
                                  if (err != null) _snack(err);
                                },
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  wp.mode == 'image' ? 'Сейчас: своя картинка' : 'Сейчас: пресет',
                                  style: TvText.caption,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _stepper(
                            label: 'Затемнение',
                            value: wp.dim,
                            min: 0,
                            max: 0.85,
                            step: 0.05,
                            fmt: (v) => '${(v * 100).round()}%',
                            onChanged: wp.setDim,
                          ),
                          SwitchListTile(
                            value: wp.blur,
                            onChanged: wp.setBlur,
                            activeColor: TvColors.accent,
                            contentPadding: EdgeInsets.zero,
                            title: Text('Размытие обоев', style: TvText.body),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  const TvSectionTitle('Звук и управление'),
                  AnimatedBuilder(
                    animation: snd,
                    builder: (_, __) => Container(
                      padding: const EdgeInsets.all(18),
                      decoration: TvDecor.card(radius: 14),
                      child: Column(
                        children: [
                          SwitchListTile(
                            value: snd.enabled,
                            onChanged: snd.setEnabled,
                            activeColor: TvColors.accent,
                            contentPadding: EdgeInsets.zero,
                            title: Text('Звуки интерфейса', style: TvText.body),
                            subtitle: Text('Мягкие отклики как на консоли', style: TvText.caption),
                          ),
                          _stepper(
                            label: 'Громкость',
                            value: snd.volume,
                            min: 0,
                            max: 1,
                            step: 0.1,
                            fmt: (v) => '${(v * 100).round()}%',
                            onChanged: snd.setVolume,
                          ),
                          _stepper(
                            label: 'Скорость курсора геймпада',
                            value: InputService.instance.sensitivity,
                            min: 0.5,
                            max: 3,
                            step: 0.25,
                            fmt: (v) => '×${v.toStringAsFixed(2)}',
                            onChanged: (v) async {
                              InputService.instance.sensitivity = v;
                              await Hive.box('vmeste_tv_prefs').put('pointer_speed', v);
                              if (mounted) setState(() {});
                            },
                          ),
                          SwitchListTile(
                            value: HintsService.instance.enabled,
                            onChanged: (v) {
                              HintsService.instance.setEnabled(v);
                              setState(() {});
                            },
                            activeColor: TvColors.accent,
                            contentPadding: EdgeInsets.zero,
                            title: Text('Подсказки управления в углу', style: TvText.body),
                          ),
                        ],
                      ),
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
                            _snack('Данные обновлены');
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
                  Text('Вместе ТВ • 1.1 • синк только чтение', style: TvText.caption),
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
