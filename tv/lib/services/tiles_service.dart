// tv/lib/services/tiles_service.dart
//
// Редактируемые плитки лаунчера:
// - web         → сайт ВНУТРИ лаунчера (WebView2 = движок Edge)
// - webExternal → сайт в настоящем Edge (для DRM: Netflix, Кинопоиск)
// - app         → .exe, .lnk, файл или папка обычным окном
// - embed       → окно .exe ВНУТРИ лаунчера (SetParent)
//
// Хранятся в Hive, переживают перезапуск.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

enum TvTileKind { web, webExternal, app, embed }

class TvTile {
  final String id;
  String title;
  String target;
  TvTileKind kind;
  String iconKey;
  int colorIndex;
  int order;

  TvTile({
    required this.id,
    required this.title,
    required this.target,
    this.kind = TvTileKind.web,
    this.iconKey = 'auto',
    this.colorIndex = 0,
    this.order = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'target': target,
        'kind': kind.name,
        'iconKey': iconKey,
        'colorIndex': colorIndex,
        'order': order,
      };

  factory TvTile.fromJson(Map<String, dynamic> j) => TvTile(
        id: j['id']?.toString() ?? '',
        title: j['title'] as String? ?? '',
        target: j['target'] as String? ?? '',
        kind: TvTileKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => TvTileKind.web,
        ),
        iconKey: j['iconKey'] as String? ?? 'auto',
        colorIndex: (j['colorIndex'] as num?)?.toInt() ?? 0,
        order: (j['order'] as num?)?.toInt() ?? 0,
      );
}

class TilesService extends ChangeNotifier {
  static const String _boxName = 'vmeste_tv_tiles';
  static const String _keyTiles = 'tiles';

  late Box _box;
  List<TvTile> tiles = [];

  /// Градиенты плиток в стиле TV OS (индекс → два цвета).
  static const List<List<Color>> gradients = [
    [Color(0xFF6A5CFF), Color(0xFF3B2E8F)], // индиго
    [Color(0xFFE8A0B5), Color(0xFF8E3B54)], // фирменная роза
    [Color(0xFF2DD4BF), Color(0xFF0F766E)], // бирюза
    [Color(0xFFF59E0B), Color(0xFF92400E)], // янтарь
    [Color(0xFF38BDF8), Color(0xFF1D4ED8)], // синий
    [Color(0xFFF87171), Color(0xFF991B1B)], // красный
    [Color(0xFF4ADE80), Color(0xFF15803D)], // зелёный
    [Color(0xFF94A3B8), Color(0xFF334155)], // графит
  ];

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    final raw = _box.get(_keyTiles);
    if (raw is List && raw.isNotEmpty) {
      try {
        tiles = raw
            .map((e) => TvTile.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        tiles.sort((a, b) => a.order.compareTo(b.order));
        return;
      } catch (_) {}
    }
    tiles = _defaults();
    await _save();
  }

  List<TvTile> _defaults() => [
        TvTile(
          id: 'yt',
          title: 'YouTube',
          target: 'https://www.youtube.com',
          kind: TvTileKind.web,
          iconKey: 'youtube',
          colorIndex: 5,
          order: 0,
        ),
        TvTile(
          id: 'kp',
          title: 'Кинопоиск',
          target: 'https://www.kinopoisk.ru',
          kind: TvTileKind.webExternal,
          iconKey: 'movie',
          colorIndex: 3,
          order: 1,
        ),
        TvTile(
          id: 'nf',
          title: 'Netflix',
          target: 'https://www.netflix.com',
          kind: TvTileKind.webExternal,
          iconKey: 'tv',
          colorIndex: 0,
          order: 2,
        ),
        TvTile(
          id: 'web',
          title: 'Браузер',
          target: 'https://www.bing.com',
          kind: TvTileKind.web,
          iconKey: 'language',
          colorIndex: 4,
          order: 3,
        ),
        TvTile(
          id: 'pc',
          title: 'Этот компьютер',
          target: 'shell:MyComputerFolder',
          kind: TvTileKind.app,
          iconKey: 'folder',
          colorIndex: 7,
          order: 4,
        ),
      ];

  // ---------- CRUD ----------

  Future<TvTile> add({
    required String title,
    required String target,
    required TvTileKind kind,
    String iconKey = 'auto',
    int colorIndex = 0,
  }) async {
    final t = TvTile(
      id: const Uuid().v4(),
      title: title.trim(),
      target: _normalizeTarget(target, kind),
      kind: kind,
      iconKey: iconKey,
      colorIndex: colorIndex,
      order: tiles.length,
    );
    tiles.add(t);
    await _save();
    return t;
  }

  Future<void> updateTile(TvTile t) async {
    final i = tiles.indexWhere((x) => x.id == t.id);
    if (i < 0) return;
    t.target = _normalizeTarget(t.target, t.kind);
    tiles[i] = t;
    await _save();
  }

  Future<void> remove(String id) async {
    tiles.removeWhere((t) => t.id == id);
    for (var i = 0; i < tiles.length; i++) {
      tiles[i].order = i;
    }
    await _save();
  }

  /// Сдвинуть плитку влево/вправо (delta = -1 / +1).
  Future<void> move(String id, int delta) async {
    final i = tiles.indexWhere((t) => t.id == id);
    if (i < 0) return;
    final j = (i + delta).clamp(0, tiles.length - 1).toInt();
    if (i == j) return;
    final t = tiles.removeAt(i);
    tiles.insert(j, t);
    for (var k = 0; k < tiles.length; k++) {
      tiles[k].order = k;
    }
    await _save();
  }

  String _normalizeTarget(String target, TvTileKind kind) {
    var t = target.trim();
    if ((kind == TvTileKind.web || kind == TvTileKind.webExternal) &&
        t.isNotEmpty &&
        !t.contains('://')) {
      t = 'https://$t';
    }
    return t;
  }

  // ---------- ЗАПУСК ----------

  /// Запуск плитки. web и embed обрабатывает UI (открывает свои экраны).
  /// Возвращает текст ошибки или null.
  Future<String?> launch(TvTile tile) async {
    switch (tile.kind) {
      case TvTileKind.web:
      case TvTileKind.embed:
        return null;
      case TvTileKind.webExternal:
        return _openInEdge(tile.target);
      case TvTileKind.app:
        return _openPath(tile.target);
    }
  }

  Future<String?> _openInEdge(String url) async {
    const edgePaths = [
      r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
      r'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
    ];
    for (final p in edgePaths) {
      if (File(p).existsSync()) {
        try {
          await Process.start(p, [url], mode: ProcessStartMode.detached);
          return null;
        } catch (_) {}
      }
    }
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return null;
    } catch (_) {
      return 'Не удалось открыть браузер';
    }
  }

  Future<String?> _openPath(String path) async {
    try {
      await Process.start('explorer.exe', [path],
          mode: ProcessStartMode.detached);
      return null;
    } catch (_) {
      return 'Не удалось запустить: $path';
    }
  }

  Future<void> _save() async {
    await _box.put(_keyTiles, tiles.map((t) => t.toJson()).toList());
    notifyListeners();
  }
}
