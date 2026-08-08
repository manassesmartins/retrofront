import 'dart:convert';
import 'dart:io';

import '../../core/app_dirs.dart';
import '../../models/game.dart';

/// Leitura/escrita dos gamelists (metadados por sistema), no estilo
/// gamelist.xml do ES-DE, porém em JSON.
class GamelistRepository {
  Future<Map<String, GameMetadata>> loadFor(String system) async {
    final file = File(await AppDirs.gamelistPathFor(system));
    if (!await file.exists()) return {};
    try {
      final decoded =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final games = decoded['games'] as List<dynamic>? ?? const [];
      final map = <String, GameMetadata>{};
      for (final g in games) {
        final m = g as Map<String, dynamic>;
        final path = m['path'] as String?;
        if (path == null) continue;
        map[path] = GameMetadata.fromJson(m);
      }
      return map;
    } catch (_) {
      return {};
    }
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
}
