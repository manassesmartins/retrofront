import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/app_dirs.dart';

/// Um pacote baixável do buildbot libretro (o mesmo conteúdo que o
/// "Online Updater" do RetroArch oferece), extraído dentro da biblioteca do
/// RetroFront em `DOWNLOADS/<destFolder>`.
class LibretroBundle {
  final String id;
  final String label;
  final String description;
  final String url;
  final String destFolder;

  const LibretroBundle({
    required this.id,
    required this.label,
    required this.description,
    required this.url,
    required this.destFolder,
  });
}

/// Baixa o conteúdo do libretro usado pelo RetroArch (assets, perfis de
/// controle, cheats, banco de dados, core info, overlays e shaders) direto do
/// buildbot, extraindo os pacotes em `biblioteca/DOWNLOADS/...`.
///
/// Os núcleos (cores) são baixados por console, pois o buildbot publica um
/// arquivo por core (`<core>_libretro[_android].so.zip`); os demais itens são
/// bundles únicos (assets.zip, cheats.zip, shaders_glsl.zip, ...).
class LibretroDownloader {
  static const String bundleBase = 'http://buildbot.libretro.com/assets/frontend';
  static const String nightlyBase = 'http://buildbot.libretro.com/nightly';

  /// Pacotes do "Online Updater" (exceto cores, que são por sistema).
  static const List<LibretroBundle> bundles = [
    LibretroBundle(
      id: 'assets',
      label: 'Recursos da interface (assets)',
      description:
          'Ícones, fontes e arte da interface usados pelo RetroArch. '
          'Pacote grande (~75 MB).',
      url: '$bundleBase/assets.zip',
      destFolder: 'assets',
    ),
    LibretroBundle(
      id: 'autoconfig',
      label: 'Perfis de controle (autoconfig)',
      description:
          'Detecção e mapeamento automático de controles do RetroArch.',
      url: '$bundleBase/autoconfig.zip',
      destFolder: 'autoconfig',
    ),
    LibretroBundle(
      id: 'cheats',
      label: 'Trapaças (cheats)',
      description: 'Base de cheats por jogo usada pelo RetroArch.',
      url: '$bundleBase/cheats.zip',
      destFolder: 'cheats',
    ),
    LibretroBundle(
      id: 'databases',
      label: 'Banco de dados',
      description:
          'Banco de dados de jogos (.rdb) usado para gerar playlists.',
      url: '$bundleBase/database-rdb.zip',
      destFolder: 'databases',
    ),
    LibretroBundle(
      id: 'info',
      label: 'Informações dos núcleos (core info)',
      description:
          'Arquivos .info com o nome/descrição de cada núcleo, exibidos '
          'pelo "Core Updater" do RetroArch.',
      url: '$bundleBase/info.zip',
      destFolder: 'info',
    ),
    LibretroBundle(
      id: 'overlays',
      label: 'Overlays',
      description: 'Sobreposições de tela (bordas de CRT, botões, etc.).',
      url: '$bundleBase/overlays.zip',
      destFolder: 'overlays',
    ),
    LibretroBundle(
      id: 'shaders_glsl',
      label: 'Sombreamento GLSL',
      description: 'Pacote de shaders GLSL do libretro/glsl-shaders.',
      url: '$bundleBase/shaders_glsl.zip',
      destFolder: 'shaders_glsl',
    ),
    LibretroBundle(
      id: 'shaders_slang',
      label: 'Sombreamento Slang',
      description: 'Pacote de shaders Slang (libretro/slang-shaders).',
      url: '$bundleBase/shaders_slang.zip',
      destFolder: 'shaders_slang',
    ),
  ];

  /// Arquiteturas de cores disponíveis por plataforma.
  static const Map<String, List<String>> coreArchs = {
    'android': ['arm64-v8a', 'armeabi-v7a', 'x86_64'],
    'linux': ['x86_64', 'aarch64'],
  };

  /// Plataforma atual usada no download de cores ("android" ou "linux").
  static String get platform =>
      Platform.isAndroid ? 'android' : (Platform.isLinux ? 'linux' : 'linux');

  /// Arquitetura padrão de cores para a plataforma atual.
  static String get defaultArch => platform == 'android' ? 'arm64-v8a' : 'x86_64';

  /// Arquiteturas de cores disponíveis na plataforma atual.
  static List<String> get availableArchs =>
      coreArchs[platform] ?? const ['x86_64'];

  final http.Client _client;
  final Future<Directory> Function() _cacheDir;
  final Future<Directory> Function() _destRoot;

  LibretroDownloader({
    http.Client? client,
    Future<Directory> Function()? cacheDir,
    Future<Directory> Function()? destRoot,
  })  : _client = client ?? http.Client(),
        _cacheDir = cacheDir ?? _defaultCacheDir,
        _destRoot = destRoot ?? _defaultDestRoot;

  static Future<Directory> _defaultCacheDir() async {
    try {
      return await getApplicationCacheDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  /// Raiz dos downloads: `biblioteca/DOWNLOADS` (com fallback para o diretório
  /// privado do app quando a biblioteca pública não é acessível no Android).
  static Future<Directory> _defaultDestRoot() async =>
      AppDirs.librarySubDir('DOWNLOADS');

  /// Nome base do core a partir do comando do sistema (ex.:
  /// "%EMULATOR_RETROARCH% -L %CORE_RETROARCH%/genesis_plus_gx_libretro.so"
  /// devolve "genesis_plus_gx"). null quando o comando não define um core.
  static String? coreBaseName(String? command) {
    if (command == null || command.trim().isEmpty) return null;
    final m = RegExp(r'-L\s+(\S+)', caseSensitive: false).firstMatch(command);
    final core = m?.group(1);
    if (core == null || core.isEmpty) return null;
    final file = p.basename(core).replaceAll('"', '');
    final base = file.replaceFirst(RegExp(r'_libretro(_android)?\.so$'), '');
    if (base.isEmpty || base == file) return null;
    return base;
  }

  /// Nome do arquivo no buildbot para um core base e plataforma.
  static String coreFileName({
    required String coreBase,
    required String platform,
  }) =>
      platform == 'android'
          ? '${coreBase}_libretro_android.so.zip'
          : '${coreBase}_libretro.so.zip';

  /// URL do core no buildbot. [platform] é "android" ou "linux"; [arch] é a
  /// ABI/arquitetura (ex.: "arm64-v8a", "x86_64").
  static String coreUrl({
    required String coreBase,
    required String platform,
    required String arch,
  }) {
    final dir = platform == 'android' ? 'android/latest/$arch' : 'linux/$arch/latest';
    return '$nightlyBase/$dir/${coreFileName(coreBase: coreBase, platform: platform)}';
  }

  /// Baixa e extrai um pacote do buildbot em `DOWNLOADS/<destFolder>`.
  /// Devolve null em caso de sucesso, ou a mensagem de erro.
  Future<String?> downloadBundle(
    LibretroBundle bundle, {
    void Function(double progress)? onProgress,
  }) =>
      downloadAndExtract(
        url: bundle.url,
        destFolder: bundle.destFolder,
        onProgress: onProgress,
      );

  /// Baixa e extrai o núcleo de um sistema em `DOWNLOADS/cores`.
  Future<String?> downloadCore({
    required String coreBase,
    required String platform,
    required String arch,
    void Function(double progress)? onProgress,
  }) =>
      downloadAndExtract(
        url: coreUrl(coreBase: coreBase, platform: platform, arch: arch),
        destFolder: 'cores',
        onProgress: onProgress,
      );

  /// Baixa o zip para o cache e extrai na pasta de destino.
  Future<String?> downloadAndExtract({
    required String url,
    required String destFolder,
    void Function(double progress)? onProgress,
  }) async {
    final dest = Directory(p.join((await _destRoot()).path, destFolder));
    await dest.create(recursive: true);
    final cache = await _cacheDir();
    final zip = File(p.join(cache.path, 'libretro-download.zip'));

    try {
      onProgress?.call(0.05);
      final res = await _client.send(http.Request('GET', Uri.parse(url)));
      if (res.statusCode != 200) {
        return 'Falha ao baixar (HTTP ${res.statusCode}).';
      }

      final total = res.contentLength;
      final sink = zip.openSync(mode: FileMode.write);
      var received = 0;
      try {
        await for (final chunk in res.stream) {
          sink.writeFromSync(chunk);
          received += chunk.length;
          if (total != null && total > 0) {
            onProgress?.call((0.10 + 0.75 * (received / total)).clamp(0.0, 0.85));
          }
        }
      } finally {
        await sink.close();
      }

      onProgress?.call(0.87);
      final bytes = await zip.readAsBytes();
      await _extract(bytes, dest, onProgress);
      onProgress?.call(1.0);
      return null;
    } catch (e) {
      return 'Erro ao baixar: $e';
    } finally {
      try {
        if (await zip.exists()) await zip.delete();
      } catch (_) {}
    }
  }

  /// Extrai o zip em [dest], ignorando entradas que tentariam escapar da
  /// pasta (path traversal). O progresso vai de 0.87 a 1.0 conforme os
  /// arquivos são escritos.
  Future<void> _extract(
    Uint8List bytes,
    Directory dest,
    void Function(double progress)? onProgress,
  ) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    var done = 0;
    final total = archive.length;
    for (final file in archive) {
      if (file.isFile) {
        final rel = p.normalize(file.name).replaceFirst(RegExp(r'^[/\\]+'), '');
        if (rel.isEmpty ||
            rel == '..' ||
            rel.startsWith('../') ||
            rel.startsWith(r'..\')) {
          done++;
          continue;
        }
        final out = File(p.join(dest.path, rel));
        await out.create(recursive: true);
        await out.writeAsBytes(file.content, flush: true);
      }
      done++;
      if (total > 0) {
        onProgress?.call((0.88 + 0.12 * (done / total)).clamp(0.0, 1.0));
      }
    }
  }
}
