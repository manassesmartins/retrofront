import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import '../../core/app_dirs.dart';
import '../../models/system.dart';

/// Carrega as definicoes de sistemas (bundled + override em custom_systems,
/// espelhando o conceito de custom_systems do ES-DE).
class SystemDefinitionsRepository {
  static const _bundledAsset = 'assets/systems/es_systems.json';

  List<SystemDefinition>? _cache;

  Future<List<SystemDefinition>> load() async {
    if (_cache != null) return _cache!;

    final bundled = await _parse(rootBundle.loadString(_bundledAsset));

    final customFile = File(
      p.join((await AppDirs.customSystemsDir()).path, 'es_systems.json'),
    );
    if (await customFile.exists()) {
      final custom = await _parse(customFile.readAsString());
      final byName = {for (final s in bundled) s.name: s};
      for (final s in custom) {
        byName[s.name] = s;
      }
      _cache = byName.values.toList();
    } else {
      _cache = bundled;
    }
    return _cache!;
  }

  Future<List<SystemDefinition>> _parse(Future<String> source) async {
    final raw = await source;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = decoded['systems'] as List<dynamic>;
    return list
        .map((e) => SystemDefinition.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  SystemDefinition? byName(List<SystemDefinition> systems, String name) {
    for (final s in systems) {
      if (s.name.toLowerCase() == name.toLowerCase()) return s;
    }
    return null;
  }
}
