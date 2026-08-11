import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolucao de diretorios por plataforma.
///
/// Biblioteca padrao (criada onde o usuario escolher, ou no diretorio base):
///   `base/Retrofront/`
///     `ROMs/sistema`            ROMs organizadas por console
///     `BIOS/`                   arquivos de BIOS dos emuladores (manual)
///     `SAVES/`                  dados de salvamento (manual/organizado)
///     `CONFIGS/retrofront`      dados internos do app (gamelists, custom_systems)
///     `CONFIGS/sistema`         configuracoes por emulador (manual)
///     `COVERS/sistema`          capas baixadas pelo app
///     `SYSTEMART/sistema.png`    artes de fundo por console (manual)
///     `TEXTUREPACKS/emulador`   pacotes de textura por emulador (manual)
///
/// No Android, sem "All files access" a pasta publica nao e gravavel; nesse
/// caso os dados internos caem no diretorio privado do app
/// (getApplicationSupportDirectory/RetroFront) sem quebrar o aplicativo.
class AppDirs {
  AppDirs._();

  /// Nome da pasta principal da biblioteca criada onde o usuario escolher.
  static const libraryFolderName = 'Retrofront';

  static bool get isAndroid => Platform.isAndroid;
  static bool get isDesktop => Platform.isLinux;

  static String? _romsOverride;

  /// Registra a pasta de ROMs escolhida pelo usuario (vinda das configuracoes),
  /// usada para derivar a pasta principal da biblioteca (CONFIGS/COVERS...).
  static void useRomsOverride(String? path) {
    _romsOverride = path;
  }

  /// Diretorio base (pai da pasta "Retrofront"): /storage/emulated/0 no
  /// Android ou a home no desktop.
  static Future<Directory> defaultBaseDir() async {
    if (isAndroid) return Directory('/storage/emulated/0');
    final home = Platform.environment['HOME'] ?? '';
    return Directory(home);
  }

  /// Diretorio raiz de ROMs. O override explicito (scan/views) tem prioridade;
  /// depois o override registrado (pasta escolhida nas configuracoes); depois
  /// a variavel de ambiente `RETROFRONT_ROMS_ROOT`.
  static Future<Directory> romsRoot({String? override}) async {
    final envRoms = Platform.environment['RETROFRONT_ROMS_ROOT'];
    final custom = (override ?? _romsOverride ?? envRoms ?? '').trim();
    if (custom.isNotEmpty) {
      final d = Directory(custom);
      if (!await d.exists()) await _tryCreate(d);
      return d;
    }

    final base = await defaultBaseDir();
    final retro = Directory(p.join(base.path, libraryFolderName, 'ROMs'));
    final legacy = Directory(p.join(base.path, 'ROMs'));
    // Migracao: bibliotecas antigas criadas direto em <base>/ROMs continuam
    // funcionando enquanto a estrutura "Retrofront" ainda nao existir.
    if (!await retro.exists() && await legacy.exists()) return legacy;
    if (!await retro.exists()) await _tryCreate(retro);
    return retro;
  }

  /// Pasta principal da biblioteca (`base/Retrofront`). Retorna null quando a
  /// raiz de ROMs nao esta dentro de uma pasta "Retrofront" (biblioteca legada
  /// ou caminho customizado fora do padrao); nesse caso os dados internos
  /// ficam no diretorio privado do app.
  static Future<Directory?> libraryRoot() async {
    final roms = (await romsRoot()).path;
    final sep = p.separator;
    if (roms.toLowerCase().endsWith('${sep}retrofront${sep}roms')) {
      return Directory(p.dirname(roms));
    }
    return null;
  }

  /// Retorna a pasta principal da biblioteca apenas se estiver gravavel
  /// (tenta criar); null quando a permissao e negada.
  static Future<Directory?> _writableLibraryRoot() async {
    final lib = await libraryRoot();
    if (lib == null) return null;
    try {
      if (!await lib.exists()) await lib.create(recursive: true);
      return lib;
    } catch (_) {
      return null;
    }
  }

  static Future<Directory> _privateAppDataDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'RetroFront'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Dados internos do app (gamelists, custom_systems, retroachievements):
  /// em `biblioteca/CONFIGS/retrofront` quando a pasta publica e acessivel;
  /// senao no diretorio privado do app.
  static Future<Directory> appDataDir() async {
    final lib = await _writableLibraryRoot();
    if (lib != null) {
      final dir = Directory(p.join(lib.path, 'CONFIGS', 'retrofront'));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    return _privateAppDataDir();
  }

  static Future<Directory> gamelistsDir() async =>
      Directory(p.join((await appDataDir()).path, 'gamelists'));

  /// Capas baixadas organizadas por sistema: `biblioteca/COVERS/sistema`.
  static Future<Directory> mediaDir(String system) async {
    final lib = await _writableLibraryRoot();
    if (lib != null) {
      final d = Directory(p.join(lib.path, 'COVERS', system));
      if (!await d.exists()) await d.create(recursive: true);
      return d;
    }
    return Directory(
      p.join((await _privateAppDataDir()).path, 'downloaded_media', system),
    );
  }

  static Future<Directory> mediaTypeDir(String system, String type) async {
    final d = Directory(p.join((await mediaDir(system)).path, type));
    await d.create(recursive: true);
    return d;
  }

  static Future<Directory> customSystemsDir() async =>
      Directory(p.join((await appDataDir()).path, 'custom_systems'));

  static Future<String> gamelistPathFor(String system) async =>
      p.join((await gamelistsDir()).path, '$system.json');

  /// Subpasta da biblioteca (ex.: BIOS, SAVES, `CONFIGS/sistema`,
  /// `TEXTUREPACKS/emulador`). Com fallback para o appData privado quando a
  /// biblioteca publica nao e acessivel.
  static Future<Directory> librarySubDir(String relativePath) async {
    final lib = await _writableLibraryRoot();
    if (lib != null) {
      final d = Directory(p.join(lib.path, relativePath));
      if (!await d.exists()) await d.create(recursive: true);
      return d;
    }
    return Directory(
      p.join((await _privateAppDataDir()).path, relativePath),
    );
  }

  static Future<Directory> biosDir() => librarySubDir('BIOS');

  static Future<Directory> savesDir() => librarySubDir('SAVES');

  static Future<Directory> configsDir([String? system]) =>
      librarySubDir(system == null ? 'CONFIGS' : p.join('CONFIGS', system));

  static Future<Directory> texturePacksDir(String emulator) =>
      librarySubDir(p.join('TEXTUREPACKS', emulator));

  /// Pasta das artes de fundo por console (`biblioteca/SYSTEMART`), com
  /// fallback para o diretorio privado quando a biblioteca nao e acessivel.
  static Future<Directory> systemArtDir() => librarySubDir('SYSTEMART');

  /// Possiveis raizes da biblioteca para leitura sincrona da pasta SYSTEMART.
  /// O override de ROMs (pasta escolhida nas configuracoes ou variavel de
  /// ambiente) deriva a biblioteca; sem override usa `base/Retrofront`.
  static List<String> _libraryRootCandidates() {
    final custom = (_romsOverride ??
            Platform.environment['RETROFRONT_ROMS_ROOT'] ??
            '')
        .trim();
    if (custom.isNotEmpty) {
      final sep = p.separator;
      if (custom.toLowerCase().endsWith('${sep}retrofront${sep}roms')) {
        return [p.dirname(custom)];
      }
      // Caminho fora do padrao: considera a propria pasta e a raiz comum.
      return [custom, p.dirname(p.dirname(custom))];
    }
    final base = isAndroid
        ? '/storage/emulated/0'
        : (Platform.environment['HOME'] ?? '');
    return [p.join(base, libraryFolderName)];
  }

  static const _artExtensions = ['png', 'jpg', 'jpeg', 'webp'];

  /// Caminho da arte de fundo de um sistema em `SYSTEMART/<nome>.png` (ou
  /// jpg/jpeg/webp) dentro da biblioteca, ou null se nao existir. Sincrono
  /// para leitura durante o build; sem arte o gradiente do console e usado.
  static String? systemArtPath(String name) {
    final safe = name.trim();
    if (safe.isEmpty) return null;
    for (final root in _libraryRootCandidates()) {
      for (final ext in _artExtensions) {
        final f = File(p.join(root, 'SYSTEMART', '$safe.$ext'));
        if (f.existsSync()) return f.path;
      }
    }
    return null;
  }

  /// Cria o diretorio sem propagar erro de permissao: sem "All files access"
  /// no Android a criacao da pasta publica falha com EACCES, mas o caminho
  /// ainda e valido para a interface mostrar/gerenciar o acesso.
  static Future<void> _tryCreate(Directory dir) async {
    try {
      await dir.create(recursive: true);
    } catch (_) {
      // Ignora: o caminho e retornado mesmo sem a pasta existir.
    }
  }
}
