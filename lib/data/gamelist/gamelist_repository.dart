import 'dart:convert';
import 'dart:io';

import '../../core/app_dirs.dart';
import '../../models/game.dart';

/// Leitura/escrita dos gamelists (metadados por sistema), no estilo
/// gamelist.xml do ES-DE, porém em JSON.
class GamelistRepository {
  final _cache = <String, Map<String, GameMetadata>>{};

  Future<Map<String, GameMetadata>> loadFor(String system) async {
    final cached = _cache[system];
    if (cached != null) return cached;

    final file = File(await AppDirs.gamelistPathFor(system));
    Map<String, GameMetadata> map = {};
    if (await file.exists()) {
      try {
        final decoded =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final games = decoded['games'] as List<dynamic>? ?? const [];
        map = {};
        for (final g in games) {
          final m = g as Map<String, dynamic>;
          final path = m['path'] as String?;
          if (path == null) continue;
          map[path] = GameMetadata.fromJson(m);
        }
      } catch (_) {
        map = {};
      }
    }
    _cache[system] = map;
    return map;
  }

  /// Carrega (e cacheia) os gamelists de todos os sistemas de uma vez.
  /// Usado na inicializacao para que capas/descricoes ja salvas estejam
  /// disponiveis imediatamente ao abrir um sistema.
  Future<void> preload(List<String> systems) async {
    await Future.wait(
      systems.map((s) => loadFor(s)),
      eagerError: false,
    );
  }

  Future<void> save(String system, Map<String, GameMetadata> entries) async {
    final file = File(await AppDirs.gamelistPathFor(system));
    await file.parent.create(recursive: true);
    final games = entries.entries.map((e) {
      final m = e.value.toJson();
      m['path'] = e.key;
      return m;
    }).toList();
    await file.writeAsString(jsonEncode({'system': system, 'games': games}));
    _cache[system] = Map<String, GameMetadata>.from(entries);
  }

  Future<void> upsert(String system, String path, GameMetadata metadata) async {
    final entries = await loadFor(system);
    entries[path] = metadata;
    await save(system, entries);
  }

  Future<void> remove(String system, String path) async {
    final entries = await loadFor(system);
    if (entries.remove(path) != null) {
      await save(system, entries);
    }
  }

  void invalidate(String system) {
    _cache.remove(system);
  }

  void invalidateAll() {
    _cache.clear();
  }
}
