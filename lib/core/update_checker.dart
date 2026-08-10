import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'device_info.dart';

/// Informacoes de uma release do GitHub (RetroFront).
class UpdateInfo {
  /// Versao da release sem prefixo "v" (ex.: "1.0.10").
  final String version;
  final String tag;
  final String name;
  final String body;

  /// Se e uma pre-release (Nightly/Beta).
  final bool isPrerelease;

  /// URL de download do APK (primeiro asset .apk da release).
  final String? apkUrl;

  /// Pagina web da release no GitHub.
  final String htmlUrl;

  const UpdateInfo({
    required this.version,
    required this.tag,
    required this.name,
    required this.body,
    required this.isPrerelease,
    required this.apkUrl,
    required this.htmlUrl,
  });
}

/// Resultado da verificacao de atualizacao.
class UpdateResult {
  final String currentVersion;
  final UpdateInfo? latest;
  final bool hasUpdate;

  /// null se a verificacao ocorreu sem erros.
  final String? error;

  const UpdateResult({
    required this.currentVersion,
    required this.hasUpdate,
    this.latest,
    this.error,
  });
}

/// Servico de auto-update: consulta as releases do GitHub (api.github.com),
/// compara com a versao instalada e, no Android, baixa e instala o APK.
class UpdateService {
  static const String owner = 'manassesmartins';
  static const String repo = 'retrofront';

  final http.Client _client;

  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  String get _api => 'https://api.github.com/repos/$owner/$repo/releases';
  String get releasesPage => 'https://github.com/$owner/$repo/releases';

  /// Versao atual instalada (ex.: "1.0.0"). Cai para a constante local se o
  /// pacote nativo nao estiver disponivel.
  Future<String> currentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final v = info.version.trim();
      if (v.isNotEmpty) return v;
    } catch (_) {}
    return kAppVersion;
  }

  /// Busca a release mais recente do GitHub.
  ///
  /// Com [includePrerelease] = true considera tambem pre-releases (Nightly/Beta).
  Future<UpdateInfo?> fetchLatest({bool includePrerelease = false}) async {
    final uri = includePrerelease
        ? Uri.parse('$_api?per_page=1')
        : Uri.parse('$_api/latest');
    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': '$owner/$repo',
      },
    );
    if (res.statusCode != 200) return null;
    final json = jsonDecode(res.body);
    final list = json is List ? json : [json];
    if (list.isEmpty) return null;
    return _parseRelease(list.first as Map<String, dynamic>);
  }

  /// Verifica se ha atualizacao disponivel.
  Future<UpdateResult> check({bool includePrerelease = false}) async {
    final current = await currentVersion();
    try {
      final latest = await fetchLatest(includePrerelease: includePrerelease);
      if (latest == null) {
        return UpdateResult(
          currentVersion: current,
          hasUpdate: false,
          error: 'Nenhuma release encontrada.',
        );
      }
      return UpdateResult(
        currentVersion: current,
        hasUpdate: isNewer(latest.version, current),
        latest: latest,
      );
    } catch (e) {
      return UpdateResult(
        currentVersion: current,
        hasUpdate: false,
        error: e.toString(),
      );
    }
  }

  /// Compara versoes numericas "major.minor.patch". Pre-releases com o mesmo
  /// tripleto numerico NAO contam como mais recentes.
  static bool isNewer(String candidate, String current) {
    final a = _triple(candidate);
    final b = _triple(current);
    if (a == null || b == null) return false;
    if (a[0] != b[0]) return a[0] > b[0];
    if (a[1] != b[1]) return a[1] > b[1];
    return a[2] > b[2];
  }

  static List<int>? _triple(String version) {
    final m = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(version);
    if (m == null) return null;
    return [
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    ];
  }

  UpdateInfo? _parseRelease(Map<String, dynamic> json) {
    final tag = (json['tag_name'] as String? ?? '').replaceFirst('v', '');
    if (tag.isEmpty) return null;
    final assets = (json['assets'] as List? ?? []).cast<Map<String, dynamic>>();
    String? apkUrl;
    for (final a in assets) {
      final name = a['name'] as String? ?? '';
      final url = a['browser_download_url'] as String?;
      if (name.toLowerCase().endsWith('.apk') && url != null) {
        apkUrl = url;
        break;
      }
    }
    return UpdateInfo(
      version: tag,
      tag: json['tag_name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isPrerelease: json['prerelease'] == true,
      apkUrl: apkUrl,
      htmlUrl: json['html_url'] as String? ?? releasesPage,
    );
  }

  /// Baixa o APK da URL para o diretorio de cache do app e devolve o caminho.
  Future<String?> downloadApk(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getApplicationCacheDirectory();
    final dest = p.join(dir.path, 'retrofront-update.apk');
    final res = await _client.send(http.Request('GET', Uri.parse(url)));
    if (res.statusCode != 200) return null;
    final total = res.contentLength;
    final bytes = <int>[];
    await res.stream.forEach((chunk) {
      bytes.addAll(chunk);
      if (total != null && total > 0) {
        onProgress?.call((bytes.length / total).clamp(0.0, 1.0));
      }
    });
    await File(dest).writeAsBytes(bytes, flush: true);
    return dest;
  }

  /// Instala um APK baixado (apenas Android; usa FileProvider + ACTION_VIEW).
  Future<bool> installApk(String path) async {
    if (!Platform.isAndroid) return false;
    try {
      const channel = MethodChannel('retrofront/update');
      final ok = await channel.invokeMethod<bool>('installApk', path) ?? false;
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Abre a pagina de releases no navegador (Android) ou no app do sistema (Linux).
  Future<bool> openReleasesPage() async {
    if (Platform.isAndroid) {
      try {
        const channel = MethodChannel('retrofront/update');
        final ok =
            await channel.invokeMethod<bool>('openUrl', releasesPage) ?? false;
        return ok;
      } catch (_) {
        return false;
      }
    }
    try {
      final result = await Process.run('xdg-open', [releasesPage]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
