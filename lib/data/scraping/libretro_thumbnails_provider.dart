import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../models/game.dart';
import 'artwork_cache.dart';
import 'scrap_provider.dart';

/// Provedor de capas sem chave, baseado no repositório libretro-thumbnails
/// (mesma fonte de imagens usada pelo RetroArch). Cobre centenas de sistemas
/// com boxart oficial, acessível por HTTPS.
class LibretroThumbnailsProvider implements ScrapProvider {
  static const _rawBase =
      'https://raw.githubusercontent.com/libretro-thumbnails/libretro-thumbnails/master';
  static const _apiBase =
      'https://api.github.com/repos/libretro-thumbnails/libretro-thumbnails/contents';

  final http.Client _client;
  final Map<String, List<Map<String, String>>> _listingCache = {};

  LibretroThumbnailsProvider({http.Client? client})
      : _client = client ?? http.Client();

  @override
  String get name => 'libretro-thumbnails';

  @override
  bool get isConfigured => true;

  @override
  bool get providesMetadata => false;

  @override
  bool get providesCover => true;

  @override
  Future<ScrapResult> scrap(ScrapContext ctx) async {
    final folder = ctx.system.libretroThumbnails;
    if (folder == null || folder.isEmpty) {
      return const ScrapResult(provider: 'libretro-thumbnails');
    }

    // Caminho rápido: tenta o nome exato da ROM.
    for (final title in _candidateTitles(ctx.gameName)) {
      final url =
          '$_rawBase/${_enc(folder)}/Named_Boxarts/${_enc(title)}.png';
      final bytes = await _download(url);
      if (bytes != null) {
        final cover = await ArtworkCache.saveCover(
          ctx.system.name,
          ctx.gameName,
          bytes,
        );
        return ScrapResult(
          provider: name,
          coverDownloaded: true,
          metadata: GameMetadata(coverPath: cover, source: name),
        );
      }
    }

    // Fallback: lista o diretório e faz match fuzzy (lida com variações de região).
    final listing = await _getListing(folder);
    if (listing.isNotEmpty) {
      final best = _fuzzyMatch(listing, ctx.gameName);
      if (best != null) {
        final bytes = await _download(
          '$_rawBase/${_enc(folder)}/Named_Boxarts/${_enc(best)}',
        );
        if (bytes != null) {
          final cover = await ArtworkCache.saveCover(
            ctx.system.name,
            ctx.gameName,
            bytes,
          );
          return ScrapResult(
            provider: name,
            coverDownloaded: true,
            metadata: GameMetadata(coverPath: cover, source: name),
          );
        }
      }
    }

    return const ScrapResult(provider: 'libretro-thumbnails');
  }

  /// Nomes candidatos de arquivo, do mais provavel ao menos provavel.
  List<String> _candidateTitles(String gameName) {
    final candidates = <String>[gameName];

    final clean = _stripRegionTags(gameName).trim();
    if (clean.isNotEmpty && clean != gameName) {
      candidates.add(clean);
      // Variação "Super Mario Bros" -> "Super Mario Bros. (USA)" não é
      // adivinhável diretamente; fica a cargo do fallback com listing.
    }
    return candidates.toSet().toList();
  }

  /// Remove tags como (USA), (Europe), (Rev 1), [!] do final do nome.
  String _stripRegionTags(String name) {
    var result = name;
    while (true) {
      final match = RegExp(r'\s*\([^)]*\)\s*$').firstMatch(result);
      if (match == null) break;
      result = result.substring(0, match.start);
    }
    result = result.replaceAll(RegExp(r'\[!\]\s*$'), '').trim();
    return result;
  }

  Future<List<Map<String, String>>> _getListing(String folder) async {
    final cached = _listingCache[folder];
    if (cached != null) return cached;

    final url = '$_apiBase/${_enc(folder)}/Named_Boxarts';
    try {
      final res = await _client.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'RetroFront/1.0',
        },
      );
      if (res.statusCode != 200) {
        _listingCache[folder] = const [];
        return const [];
      }
      final decoded = jsonDecode(res.body) as List<dynamic>;
      final files = decoded
          .map((e) => Map<String, String>.from(e as Map<String, dynamic>))
          .where((e) => (e['name'] ?? '').endsWith('.png'))
          .toList();
      _listingCache[folder] = files;
      return files;
    } catch (_) {
      _listingCache[folder] = const [];
      return const [];
    }
  }

  /// Busca a melhor correspondência no diretório (por nome normalizado).
  String? _fuzzyMatch(List<Map<String, String>> files, String gameName) {
    final target = _normalize(gameName);
    if (target.isEmpty) return null;

    final byName = <String, String>{};
    for (final f in files) {
      byName[_normalize(f['name'] ?? '')] = f['name'] ?? '';
    }

    String? exact = byName[target];
    if (exact != null) return exact;

    String? best;
    var bestScore = -1;
    for (final entry in byName.entries) {
      final score = _similarity(target, entry.key);
      if (score > bestScore) {
        bestScore = score;
        best = entry.value;
      }
    }
    if (best != null && bestScore > 0.5) return best;
    return null;
  }

  int _similarity(String a, String b) {
    if (a.length < 3 || b.length < 3) return -1;
    if (a == b) return 1000;
    if (b.startsWith(a)) return 500 - (b.length - a.length);
    if (a.startsWith(b)) return 400;
    // prefixo comum
    var i = 0;
    while (i < a.length && i < b.length && a[i] == b[i]) {
      i++;
    }
    return i >= 3 ? i : -1;
  }

  String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '');

  Future<Uint8List?> _download(String url) async {
    try {
      final res = await _client.get(
        Uri.parse(url),
        headers: {'User-Agent': 'RetroFront/1.0'},
      );
      if (res.statusCode != 200) return null;
      return res.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  String _enc(String s) => Uri.encodeComponent(s);
}
