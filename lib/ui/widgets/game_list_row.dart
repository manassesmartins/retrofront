import 'package:flutter/material.dart';

import '../../models/game_entry.dart';
import '../theme.dart';
import 'cover_image.dart';

/// Linha da lista de jogos: miniatura, titulo e detalhes. Estado [selected]
/// destaca com barra de acento — como um menu de console.
class GameListRow extends StatelessWidget {
  final GameEntry game;
  final bool selected;
  final VoidCallback onTap;

  const GameListRow({
    super.key,
    required this.game,
    required this.selected,
    required this.onTap,
  });

  String get _subtitle {
    if (game.isFolder) return 'Pasta de jogos';
    final meta = game.metadata;
    final year = meta?.releaseDate != null && meta!.releaseDate!.length >= 4
        ? meta.releaseDate!.substring(0, 4)
        : null;
    final genre = meta?.genre;
    return [genre, year].whereType<String>().join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    final meta = game.metadata;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: radius,
          color: selected
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // Barra de selecao.
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? AppTheme.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            // Miniatura (capa ou pasta).
            SizedBox(
              width: 40,
              height: 40,
              child: game.isFolder
                  ? _folderBox()
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CoverImage(
                        path: meta?.coverPath,
                        width: 40,
                        height: 40,
                        borderRadius: BorderRadius.zero,
                        fallbackLabel: '',
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                      fontSize: 15,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (_subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? Colors.white54
                            : AppTheme.textFaint,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _folderBox() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF2A3142),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.folder, color: Colors.white60, size: 22),
    );
  }
}
