import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/app_dirs.dart';
import '../../models/game_entry.dart';
import '../../models/system.dart';
import '../gamelist/gamelist_repository.dart';
import '../systems/system_definitions_repository.dart';

/// Scanner do diretorio de ROMs. Espelha o paradigma de sistema de arquivos
/// do ES-DE: um subdiretorio por sistema, e dentro dele arquivos + pastas.
class RomScanner {
  final SystemDefinitionsRepository definitions;
  final GamelistRepository gamelist;

  RomScanner({required this.definitions, required this.gamelist});

  static const skipFiles = {
    'systeminfo.txt',
    'noload.txt',
    'gameinfo.dat',
    '.ds_store',
    'thumbs.db',
    'desktop.ini',
  };

  /// Descobre os sistemas presentes no diretorio de ROMs.
  Future<List<SystemEntry>> scanSystems({String? romsOverride}) async {
    final root = await AppDirs.romsRoot(override: romsOverride);
    if (!await root.exists()) return [];

    final defs = await definitions.load();
    final entries = <SystemEntry>[];

    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final folderName = p.basename(entity.path);
      if (folderName.startsWith('.')) continue;

      final definition = _matchDefinition(defs, folderName);
      if (definition == null) continue;

      final noload = File(p.join(entity.path, 'noload.txt'));
      if (await noload.exists()) continue;

      final (gameCount, hasMedia) = await _statSystem(entity.path, definition);
      entries.add(SystemEntry(
        definition: definition,
        path: entity.path,
        gameCount: gameCount,
        hasMedia: hasMedia,
      ));
    }

    entries.sort((a, b) => a.fullName.compareTo(b.fullName));
    return entries;
  }

  SystemDefinition? _matchDefinition(List<SystemDefinition> defs, String folder) {
    for (final d in defs) {
      if (d.name.toLowerCase() == folder.toLowerCase()) return d;
    }
    return null;
  }

  Future<(int, bool)> _statSystem(String dir, SystemDefinition def) async {
    var count = 0;
    var hasMedia = false;
    final stack = <String>[dir];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      final files = Directory(current).list(followLinks: false);
      await for (final e in files) {
        if (e is Directory) {
          stack.add(e.path);
        } else if (_isRomFile(e.path, def)) {
          count++;
        } else if (_isMediaFile(e.path)) {
          hasMedia = true;
        }
      }
    }
    return (count, hasMedia);
  }

  /// Lista os jogos/pastas de um sistema (ou de uma subpasta dele).
  Future<List<GameEntry>> listGames(
    SystemEntry system, {
    String? subPath,
  }) async {
    final base = subPath ?? system.path;
    final dir = Directory(base);
    if (!await dir.exists()) return [];

    final metadata = await gamelist.loadFor(system.name);
    final def = system.definition;
    final result = <GameEntry>[];

    await for (final entity in dir.list(followLinks: false)) {
      final baseName = p.basename(entity.path);
      if (baseName.startsWith('.') || skipFiles.contains(baseName.toLowerCase())) {
        continue;
      }

      final rel = p.relative(entity.path, from: system.path);

      if (entity is Directory) {
        result.add(GameEntry(
          name: baseName,
          path: entity.path,
          system: system.name,
          type: GameEntryType.folder,
          metadata: metadata[rel],
        ));
      } else if (_isRomFile(entity.path, def) || metadata.containsKey(rel)) {
        result.add(GameEntry(
          name: baseName,
          path: entity.path,
          system: system.name,
          type: GameEntryType.game,
          metadata: metadata[rel],
        ));
      }
    }

    result.sort((a, b) {
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return result;
  }

  bool _isRomFile(String path, SystemDefinition def) {
    final base = p.basename(path);
    if (skipFiles.contains(base.toLowerCase())) return false;
    final ext = p.extension(path);
    return def.matchesExtension(ext);
  }

  bool _isMediaFile(String path) {
    final base = p.basename(path).toLowerCase();
    return base.endsWith('.png') || base.endsWith('.jpg') || base.endsWith('.jpeg');
  }
}
