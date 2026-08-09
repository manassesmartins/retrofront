import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/game.dart';
import 'scrap_provider.dart';

/// Provedor de metadados via MobyGames API.
/// Requer uma chave de API válida (gratuita com cadastro).
class MobyGamesProvider implements ScrapProvider {
  static const _base = 'https://api.mobygames.com/v1/games';

  final http.Client _client;
  final String Function() apiKey;

  MobyGamesProvider({
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get name => 'mobygames';

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
      return const ScrapResult(provider: 'mobygames');
    }

    try {
      final game = await _search(ctx.gameName);
      if (game == null) {
        return const ScrapResult(provider: 'mobygames');
      }

      final id = game['id'] as int?;
      final details = id == null ? null : await _details(id);

      final metadata = GameMetadata(
        name: _asString(game['name']),
        description: details != null
            ? _asString(details['description'])
            : _asString(game['description']),
        genre: _asString(game['genres'] as List<dynamic>?),
        publisher: _asList((details ?? game)['publishers'] as List<dynamic>?),
        developer: _asList((details ?? game)['developers'] as List<dynamic>?),
        releaseDate: _asString((details ?? game)['released']),
        rating: _parseRating(details != null
            ? details[' ratings'] as Map<String, dynamic>?
            : game['ratings']),
        players: _asString(game['players']),
        source: name,
      );

      return ScrapResult(
        provider: name,
        metadata: metadata,
        coverDownloaded: false,
      );
    } catch (_) {
      return const ScrapResult(provider: 'mobygames');
    }
  }

  Future<Map<String, dynamic>?> _search(String query) async {
    final uri = Uri.parse(_base).replace(
      queryParameters: {
        'api_key': apiKey(),
        'title': query,
        'limit': '1',
      },
    );

    try {
      final res = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );

      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final games = (body['games'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .toList();
      if (games.isEmpty) return null;
      return games.first;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _details(int id) async {
    final uri = Uri.parse('$_base/$id').replace(
      queryParameters: {'api_key': apiKey()},
    );

    try {
      final res = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );

      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  String? _asString(dynamic v) {
    if (v == null) return null;
    if (v is Map) return v['name'] as String?;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  String? _asList(List<dynamic>? v) {
    if (v == null || v.isEmpty) return null;
    final names = v.map((e) => _asString(e)).whereType<String>().toList();
    return names.isNotEmpty ? names.join(', ') : null;
  }

  double? _parseRating(dynamic v) {
    final ratings = v as Map<String, dynamic>?;
    if (ratings == null) return null;
    final numeric = ratings['numeric'] as num?;
    if (numeric == null) return null;
    return (numeric / 4).clamp(0.0, 5.0).toDouble();
  }
}