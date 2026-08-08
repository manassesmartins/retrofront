import 'dart:async';

import '../../data/settings/settings_service.dart';
import '../../models/game.dart';
import '../../models/game_entry.dart';
import '../../models/system.dart';
import '../gamelist/gamelist_repository.dart';
import '../roms/rom_scanner.dart';
import 'libretro_thumbnails_provider.dart';
import 'scrap_provider.dart';
import 'thegamesdb_provider.dart';

/// Orquestra os provedores de scraping para enriquecer os jogos com
/// metadados e capas, persistindo tudo no gamelist do sistema.
class ScrapeService {
  final TheGamesDbProvider theGamesDb;
  final LibretroThumbnailsProvider libretro;
  final GamelistRepository gamelist;
  final RomScanner scanner;
  final SettingsService settings;

  ScrapeService({
    required this.theGamesDb,
    required this.libretro,
    required this.gamelist,
    required this.scanner,
    required this.settings,
  });

  /// Provedores em ordem de prioridade, respeitando a preferencia do usuario.
  List<ScrapProvider> get providers {
    final pref = settings.getScrapeProvider();
    return switch (pref) {
      'thegamesdb' => [if (theGamesDb.isConfigured) theGamesDb, libretro],
      'libretro' => [libretro, if (theGamesDb.isConfigured) theGamesDb],
      _ => [
          if (theGamesDb.isConfigured) theGamesDb,
          libretro,
        ],
    };
  }

  /// Enriquecimento de um unico jogo.
  Future<GameMetadata?> scrapGame(SystemDefinition system, String gameName) async {
    GameMetadata? merged;
    final ctx = ScrapContext(system: system, gameName: gameName);
    for (final p in providers) {
      if (!p.isConfigured) continue;
      final result = await p.scrap(ctx);
      if (!result.hasResult) continue;
      merged = merged == null
          ? result.metadata
          : mergeMetadata(merged, result.metadata!);
    }
    return merged;
  }

  /// Scraping em lote para todos os jogos de um sistema, salvando no gamelist.
  Future<({int total, int success, int failed})> scrapSystem(
    SystemEntry system, {
    void Function(int done, int total, String current)? onProgress,
    bool onlyMissing = true,
  }) async {
    final games = await scanner.listGames(system);
    final targets = games
        .where((g) =>
            !g.isFolder &&
            (!onlyMissing || g.metadata?.coverPath == null || !g.metadata!.hasData))
        .toList();

    var done = 0;
    var success = 0;
    final errors = <String>[];

    for (final game in targets) {
      final name = _displayName(game);
      onProgress?.call(done, targets.length, name);
      try {
        final meta = await scrapGame(system.definition, name);
        if (meta != null) {
          final existing = game.metadata ?? const GameMetadata();
          final merged = mergeMetadata(existing, meta);
          final rel = _relativePath(system, game.path);
          await gamelist.upsert(system.name, rel, merged);
          success++;
        } else {
          errors.add(name);
        }
      } catch (_) {
        errors.add(name);
      }
      done++;
      onProgress?.call(done, targets.length, name);
    }

    return (total: targets.length, success: success, failed: errors.length);
  }

  String _relativePath(SystemEntry system, String path) {
    final root = system.path;
    if (path.startsWith(root)) {
      return path.substring(root.length).replaceFirst(RegExp(r'^[/\\]'), '');
    }
    return path;
  }

  /// Mescla dois metadados preenchendo apenas campos vazios.
  GameMetadata mergeMetadata(GameMetadata current, GameMetadata incoming) {
    return GameMetadata(
      name: current.name ?? incoming.name,
      description: current.description ?? incoming.description,
      genre: current.genre ?? incoming.genre,
      publisher: current.publisher ?? incoming.publisher,
      developer: current.developer ?? incoming.developer,
      releaseDate: current.releaseDate ?? incoming.releaseDate,
      rating: current.rating ?? incoming.rating,
      players: current.players ?? incoming.players,
      coverPath: current.coverPath ?? incoming.coverPath,
      videoUrl: current.videoUrl ?? incoming.videoUrl,
      source: incoming.source ?? current.source,
    );
  }

  String _displayName(GameEntry game) {
    final withExt = game.name;
    final dot = withExt.lastIndexOf('.');
    if (dot <= 0) return withExt;
    return withExt.substring(0, dot);
  }
}
