import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../models/game.dart';
import 'artwork_cache.dart';
import 'scrap_provider.dart';

/// Provedor completo de metadados + capas via TheGamesDB.
/// Requer uma chave de API gratuita (https://api.thegamesdb.net) configurada
/// nas configuracoes do app.
class TheGamesDbProvider implements ScrapProvider {
  static const _base = 'https://api.thegamesdb.net/v1';

  final http.Client _client;
  final String Function() apiKey;

  Map<String, int>? _platformIds;

  TheGamesDbProvider({
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get name => 'thegamesdb';

  @override
  bool get isConfigured => apiKey().trim().isNotEmpty;

  @override
  bool get providesMetadata => true;

  @override
  bool get providesCover => true;

  @override
  Future<ScrapResult> scrap(ScrapContext ctx) async {
    final key = apiKey().trim();
    if (key.isEmpty) {
      return const ScrapResult(provider: 'thegamesdb');
    }

    try {
      final platformName =
          ctx.system.theGamesDbPlatform ?? ctx.system.platform;
      final platformId = await _platformId(key, platformName);
      if (platformId == null) {
        return const ScrapResult(provider: 'thegamesdb');
      }

      final game = await _search(key, platformId, ctx.gameName);
      if (game == null) {
        return const ScrapResult(provider: 'thegamesdb');
      }

      final gameId = game['id'] as int?;
      final rawRating = game['rating'];
      final rating = rawRating is num
          ? (rawRating.toDouble() / 20).clamp(0.0, 5.0).toDouble()
          : null;

      final genres = _asList(game['genres']);
      final publishers = _asList(game['publishers']);
      final developers = _asList(game['developers']);

      final metadata = GameMetadata(
        name: _asString(game['game_title']),
        description: _asString(game['overview']),
        genre: genres.isNotEmpty ? genres.join(', ') : null,
        publisher: publishers.isNotEmpty ? publishers.join(', ') : null,
        developer: developers.isNotEmpty ? developers.join(', ') : null,
        releaseDate: _asString(game['release_date']),
        rating: rating,
        players: _asString(game['players']),
        videoUrl: _asString(game['youtube']) != null
            ? 'https://www.youtube.com/watch?v=${_asString(game['youtube'])}'
            : null,
        source: name,
      );

      String? coverPath;
      if (gameId != null) {
        final boxart = await _boxartUrl(key, gameId);
        if (boxart != null) {
          final bytes = await _download(boxart);
          if (bytes != null) {
            coverPath = await ArtworkCache.saveCover(
              ctx.system.name,
              ctx.gameName,
              bytes,
              extension: _extFromUrl(boxart),
            );
          }
        }
      }

      final finalMetadata = coverPath != null
          ? metadata.copyWith(coverPath: coverPath)
          : metadata;

      return ScrapResult(
        provider: name,
        coverDownloaded: coverPath != null,
        metadata: finalMetadata,
      );
    } catch (_) {
      return const ScrapResult(provider: 'thegamesdb');
    }
  }

  Future<int?> _platformId(String key, String? platformName) async {
    if (platformName == null) return null;
    _platformIds ??= await _loadPlatforms(key);
    return _platformIds![platformName];
  }

  Future<Map<String, int>> _loadPlatforms(String key) async {
    try {
      final res = await _client.get(
        Uri.parse('$_base/Platforms?apikey=$key'),
        headers: {'Accept': 'application/json'},
      );
      if (res.statusCode != 200) return {};
      final data = (jsonDecode(res.body)['data'] as Map<String, dynamic>);
      final platforms = data['platforms'] as List<dynamic>? ?? const [];
      return {
        for (final p in platforms)
          ((p as Map<String, dynamic>)['name'] as String?)!:
              (p['id'] as num).toInt(),
      };
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>?> _search(
      String key, int platformId, String name) async {
    final uri = Uri.parse('$_base/Games/ByGameName').replace(
      queryParameters: {
        'apikey': key,
        'name': name,
        'filter[platform]': '$platformId',
      },
    );
    final res = await _client.get(
      uri,
      headers: {'Accept': 'application/json'},
    );
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final games = (body['data']?['games'] ?? body['data'] ?? const [])
        as List<dynamic>?;
    if (games == null || games.isEmpty) return null;

    // Prefere correspondencia exata (ignorando acentos/caixa).
    final target = _normalize(name);
    for (final g in games) {
      final t = _normalize(g['game_title'] as String? ?? '');
      if (t == target) {
        return Map<String, dynamic>.from(g as Map<String, dynamic>);
      }
    }
    return Map<String, dynamic>.from(games.first as Map<String, dynamic>);
  }

  Future<String?> _boxartUrl(String key, int gameId) async {
    final res = await _client.get(
      Uri.parse('$_base/Boxart?apikey=$key&games_id=$gameId'),
      headers: {'Accept': 'application/json'},
    );
    if (res.statusCode != 200) return null;
    final data = (jsonDecode(res.body)['data'] as Map<String, dynamic>);
    final baseUrl = data['base_url']?['original'] as String?;
    final boxarts = data['boxart'] as List<dynamic>? ?? const [];
    for (final b in boxarts) {
      final map = b as Map<String, dynamic>;
      if (map['side'] == 'front' &&
          map['type'] == 'boxart' &&
          map['filename'] != null) {
        return '$baseUrl/${map['filename']}';
      }
    }
    return null;
  }

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

  String? _asString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  List<String> _asList(dynamic v) {
    if (v is List) {
      return v.map((e) {
        if (e is Map) return (e['name'] ?? '').toString();
        return e.toString();
      }).where((s) => s.isNotEmpty).toList();
    }
    if (v is String && v.trim().isNotEmpty) return [v.trim()];
    return const [];
  }

  String _extFromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'jpg';
    return 'png';
  }

  String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}
