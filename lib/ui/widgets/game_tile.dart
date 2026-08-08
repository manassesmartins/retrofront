import 'package:flutter/material.dart';

import '../../models/game_entry.dart';
import '../theme.dart';
import 'cover_image.dart';
import 'star_rating.dart';

/// Tile de jogo com capa, nome e nota. Suporta destaque por selecao (gamepad).
class GameTile extends StatelessWidget {
  final GameEntry game;
  final bool selected;
  final VoidCallback onTap;

  const GameTile({
    super.key,
    required this.game,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meta = game.metadata;
    final year = _yearFrom(meta?.releaseDate);
    final hasCover = meta?.coverPath != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? AppTheme.accent
              : hasCover
                  ? Colors.white10
                  : Colors.white12,
          width: selected ? 2.5 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CoverImage(
                      path: meta?.coverPath,
                      fallbackLabel: game.isFolder ? 'Pasta' : game.name,
                      width: double.infinity,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: game.isFolder
                          ? const _Badge(
                              label: 'Pasta',
                              color: Color(0xFFF59E0B),
                              icon: Icons.folder,
                            )
                          : _GameTypeBadge(game: game),
                    ),
                    if (year != null && !game.isFolder)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: _Badge(
                          label: year,
                          color: Colors.black.withValues(alpha: 0.55),
                          icon: null,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (meta?.rating != null && !game.isFolder) ...[
                      const SizedBox(height: 4),
                      StarRating(
                        rating: meta!.rating!,
                        size: 11,
                        color: const Color(0xFFFBBF24),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _yearFrom(String? releaseDate) {
    if (releaseDate == null) return null;
    final match = RegExp(r'^(\d{4})').firstMatch(releaseDate);
    return match?.group(1);
  }
}

class _GameTypeBadge extends StatelessWidget {
  final GameEntry game;

  const _GameTypeBadge({required this.game});

  @override
  Widget build(BuildContext context) {
    final meta = game.metadata;
    final hasMeta = meta?.hasData ?? false;
    if (meta?.rating == null && !hasMeta) {
      return _Badge(
        label: 'Sem dados',
        color: Colors.black.withValues(alpha: 0.55),
        icon: Icons.cloud_download_outlined,
      );
    }
    return _Badge(
      label: 'OK',
      color: Colors.black.withValues(alpha: 0.55),
      icon: Icons.check_circle_outline,
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Badge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: Colors.white),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
