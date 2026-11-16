// tv/lib/widgets/tv_tile.dart
//
// Плитка приложения в стиле TV OS: градиент, крупная иконка, тайтл.

import 'package:flutter/material.dart';

import '../services/tiles_service.dart';
import '../theme/tv_theme.dart';
import 'tv_focusable.dart';

IconData tvTileIcon(TvTile tile) {
  switch (tile.iconKey) {
    case 'youtube':
      return Icons.smart_display_rounded;
    case 'movie':
      return Icons.movie_rounded;
    case 'tv':
      return Icons.tv_rounded;
    case 'language':
      return Icons.language_rounded;
    case 'folder':
      return Icons.folder_rounded;
    case 'music':
      return Icons.music_note_rounded;
    case 'photo':
      return Icons.photo_rounded;
    case 'game':
      return Icons.sports_esports_rounded;
    case 'shop':
      return Icons.shopping_bag_rounded;
    case 'news':
      return Icons.newspaper_rounded;
    case 'sport':
      return Icons.fitness_center_rounded;
    case 'file':
      return Icons.insert_drive_file_rounded;
    default:
      return tile.kind == TvTileKind.app
          ? Icons.desktop_windows_rounded
          : Icons.public_rounded;
  }
}

class TvTileWidget extends StatelessWidget {
  final TvTile tile;
  final VoidCallback onTap;
  final bool autofocus;

  const TvTileWidget({
    super.key,
    required this.tile,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final g = TilesService.gradients[tile.colorIndex % TilesService.gradients.length];
    return TvFocusable(
      onTap: onTap,
      autofocus: autofocus,
      radius: TvSpace.tileRadius,
      child: Container(
        width: 300,
        height: 169,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TvSpace.tileRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: g,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -24,
              top: -24,
              child: Icon(tvTileIcon(tile), size: 150, color: Colors.white.withOpacity(0.12)),
            ),
            Positioned(
              left: 18,
              top: 16,
              child: Icon(tvTileIcon(tile), size: 42, color: Colors.white),
            ),
            if (tile.kind != TvTileKind.web)
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tile.kind == TvTileKind.webExternal ? 'Edge' : 'Windows',
                    style: TvText.caption.copyWith(color: Colors.white),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.55), Colors.transparent],
                  ),
                ),
                child: Text(
                  tile.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TvText.tileTitle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TvTileAdd extends StatelessWidget {
  final VoidCallback onTap;

  const TvTileAdd({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onTap: onTap,
      radius: TvSpace.tileRadius,
      child: Container(
        width: 300,
        height: 169,
        decoration: BoxDecoration(
          color: TvColors.card,
          borderRadius: BorderRadius.circular(TvSpace.tileRadius),
          border: Border.all(color: TvColors.outline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_outline_rounded, size: 42, color: TvColors.textDim),
            const SizedBox(height: 10),
            Text('Добавить', style: TvText.bodyDim),
          ],
        ),
      ),
    );
  }
}
