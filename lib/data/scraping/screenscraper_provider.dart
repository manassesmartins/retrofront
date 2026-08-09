import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../models/game.dart';
import '../../models/system.dart';
import 'artwork_cache.dart';
import 'scrap_provider.dart';

/// Provedor de scraping alternativo inspirado no ScreenScraper DBT.
/// Funciona apenas com capas quando o TheGamesDB não está configurado.
/// Nota: Requer acesso à internet e pode ter limitações de taxa.
class ScreenScraperDbProvider implements ScrapProvider {
  static const _base = 'https://www.screenscraper.fr';

  final http.Client _client;
  final String Function() username;

  ScreenScraperDbProvider({
    required this.username,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get name => 'screenscraper';

  @override
  bool get isConfigured => true;

  @override
  bool get providesMetadata => true;

  @override
  bool get providesCover => true;

  String _userAgent() => 'RetroFront scrcraper/${username()}';

  @override
  Future<ScrapResult> scrap(ScrapContext ctx) async {
    try {
      final game = await _searchGame(ctx.system, ctx.gameName);
      if (game == null) {
        return const ScrapResult(provider: 'screenscraper');
      }

      final metadata = _extractMetadata(game, ctx);

      String? coverPath;
      final coverUrl = game['boxart'] as String?;
      if (coverUrl != null && coverUrl.isNotEmpty) {
        final bytes = await _downloadImage(coverUrl);
        if (bytes != null) {
          coverPath = await ArtworkCache.saveCover(
            ctx.system.name,
            ctx.gameName,
            bytes,
            extension: _extFromUrl(coverUrl),
          );
        }
      }

      final finalMeta = coverPath != null
          ? metadata.copyWith(coverPath: coverPath)
          : metadata;

      return ScrapResult(
        provider: name,
        coverDownloaded: coverPath != null,
        metadata: finalMeta,
      );
    } catch (_) {
      return const ScrapResult(provider: 'screenscraper');
    }
  }

  Future<Map<String, dynamic>?> _searchGame(
      SystemDefinition system, String gameName) async {
    final systemId = system.libretroThumbnails;
    if (systemId == null || systemId.isEmpty) return null;

    final slug = _toSlug(gameName);
    final uri = Uri.parse('$_base/api2/game/get/$systemId/$slug/info.json');

    try {
      final res = await _client.get(
        uri,
        headers: {
          'User-Agent': _userAgent(),
        },
      );

      if (res.statusCode == 404) {
        final searchUri = Uri.parse('$_base/api2/game/get/$systemId/$slug/metadata.json');
        final searchRes = await _client.get(
          searchUri,
          headers: {'User-Agent': _userAgent()},
        );
        if (searchRes.statusCode == 200) {
          final body = jsonDecode(searchRes.body) as Map<String, dynamic>;
          if (body.containsKey('result') && body['result'] == 'success') {
            return body;
          }
        }
        return null;
      }

      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  GameMetadata _extractMetadata(
      Map<String, dynamic> game, ScrapContext ctx) {
    return GameMetadata(
      name: _asString(game['name']),
      description: _asString(game['description']),
      genre: _asString(game['genre']),
      publisher: _asString(game['publisher']),
      developer: _asString(game['developer']),
      releaseDate: _asString(game['date']),
      rating: _parseRating(game['globalScore']),
      players: _asString(game['nbplayers']),
      videoUrl: _asString(game['youtube'] ?? game['youtubeId'])?.replaceFirst(
          'https://www.youtube.com/watch?v=', 'https://youtu.be/'),
      source: name,
    );
  }

  double? _parseRating(dynamic value) {
    if (value is num) return value.toDouble().clamp(0.0, 10.0);
    if (value is String) return double.tryParse(value);
    return null;
  }

  String? _asString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  Future<Uint8List?> _downloadImage(String url) async {
    try {
      final res = await _client.get(Uri.parse(url));
      if (res.statusCode == 200) return res.bodyBytes;
    } catch (_) {}
    return null;
  }

  String _toSlug(String name) => name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '-');

  String _extFromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'jpg';
    if (lower.endsWith('.gif')) return 'gif';
    return 'png';
  }
}