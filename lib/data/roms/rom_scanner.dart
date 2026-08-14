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
    // Uma mesma definicao nunca pode gerar duas entradas: pastas cujo nome
    // varia apenas na caixa (ex.: `nes` e `NES`) casam com o mesmo sistema e
    // apareceriam como cartoes identicos. Prefere-se a pasta com o nome
    // canonico exato; sem nome exato, mantem-se a primeira pasta encontrada.
    final byName = <String, SystemEntry>{};

    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final folderName = p.basename(entity.path);
      if (folderName.startsWith('.')) continue;

      final definition = _matchDefinition(defs, folderName);
      if (definition == null) continue;

      final noload = File(p.join(entity.path, 'noload.txt'));
      if (await noload.exists()) continue;

      final existing = byName[definition.name];
      final isExact = folderName == definition.name;
      if (existing != null) {
        final existingExact = p.basename(existing.path) == definition.name;
        if (existingExact || !isExact) continue;
      }

      final (gameCount, hasMedia) = await _statSystem(entity.path, definition);
      byName[definition.name] = SystemEntry(
        definition: definition,
        path: entity.path,
        gameCount: gameCount,
        hasMedia: hasMedia,
      );
    }

    // Apenas sistemas com jogos sao carregados: pastas vazias (criadas
    // automaticamente ou ainda sem ROMs) ficam fora do carrossel.
    final entries = byName.values.where((e) => e.gameCount > 0).toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
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
    // A contagem considera apenas arquivos diretos (as subpastas sao
    // ocultadas na listagem); midia (capas) pode estar em subpastas.
    final files = Directory(dir).list(followLinks: false);
    await for (final e in files) {
      if (e is Directory) {
        if (!hasMedia) hasMedia = await _hasMediaRecursive(e.path);
      } else if (_isRomFile(e.path, def)) {
        count++;
      } else if (_isMediaFile(e.path)) {
        hasMedia = true;
      }
    }
    return (count, hasMedia);
  }

  Future<bool> _hasMediaRecursive(String dir) async {
    final stack = <String>[dir];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      final entries = Directory(current).list(followLinks: false);
      await for (final e in entries) {
        if (e is Directory) {
          stack.add(e.path);
        } else if (_isMediaFile(e.path)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Lista os jogos de um sistema (ou de uma subpasta dele).
  /// Subpastas sao ocultadas, como no EmulationStation; apenas ROMs (e
  /// arquivos com metadados no gamelist) aparecem na lista.
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
      if (entity is Directory) continue;

      final baseName = p.basename(entity.path);
      if (baseName.startsWith('.') || skipFiles.contains(baseName.toLowerCase())) {
        continue;
      }

      final rel = p.relative(entity.path, from: system.path);

      if (_isRomFile(entity.path, def) || metadata.containsKey(rel)) {
        result.add(GameEntry(
          name: baseName,
          path: entity.path,
          system: system.name,
          type: GameEntryType.game,
          metadata: metadata[rel],
        ));
      }
    }

    result.sort((a, b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
