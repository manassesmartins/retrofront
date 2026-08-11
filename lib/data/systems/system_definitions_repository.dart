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

  /// Emuladores com suporte a modificacao de textura (pastas criadas em
  /// TEXTUREPACKS para organizar os pacotes de textura por emulador).
  static const texturePackEmulators = [
    'dolphin', // GameCube/Wii
    'cemu', // Wii U
    'citra', // 3DS
    'suyu', // Switch
    'pcsx2', // PS2
    'duckstation', // PS1
    'ppsspp', // PSP
    'flycast', // Dreamcast
  ];

  /// Cria a estrutura padrao da biblioteca dentro de [baseDir]:
  ///
  ///   `baseDir/Retrofront/ROMs/sistema`
  ///   `baseDir/Retrofront/BIOS`
  ///   `baseDir/Retrofront/SAVES`
  ///   `baseDir/Retrofront/CONFIGS/{retrofront,sistema}`
  ///   `baseDir/Retrofront/COVERS/sistema`
  ///   `baseDir/Retrofront/SYSTEMART` (artes de fundo por console)
  ///   `baseDir/Retrofront/TEXTUREPACKS/emulador`
  ///
  /// Tolerante a erros de permissao (falha em silencio no Android sem
  /// "All files access"). Retorna o caminho da raiz de ROMs criada.
  Future<String> ensureDefaultFolders(String baseDir) async {
    if (baseDir.trim().isEmpty) return baseDir;
    final root = p.join(baseDir, AppDirs.libraryFolderName);
    final names = (await load())
        .map((s) => s.name.trim())
        .where((n) => n.isNotEmpty)
        .toList();

    Future<void> make(String relative) async {
      try {
        final dir = Directory(p.join(root, relative));
        if (!await dir.exists()) await dir.create(recursive: true);
      } catch (_) {
        // Sem permissao de escrita: apenas nao cria esta pasta.
      }
    }

    for (final name in names) {
      await make(p.join('ROMs', name));
      await make(p.join('CONFIGS', name));
      await make(p.join('COVERS', name));
    }
    await make('BIOS');
    await make('SAVES');
    await make('SYSTEMART');
    await make(p.join('CONFIGS', 'retrofront'));
    for (final emulator in texturePackEmulators) {
      await make(p.join('TEXTUREPACKS', emulator));
    }
    return p.join(root, 'ROMs');
  }
}
