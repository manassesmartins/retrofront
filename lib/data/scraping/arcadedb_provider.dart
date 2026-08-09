import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/game.dart';
import 'scrap_provider.dart';

/// Provedor especializado em jogos de arcade (ArcadeDB).
/// Fornece metadados para emuladores MAME, FinalBurn Alpha, etc.
class ArcadeDbProvider implements ScrapProvider {
  static const _base = 'https://arcade-db.com';

  final http.Client _client;
  final String Function() apikey;

  ArcadeDbProvider({
    required this.apikey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get name => 'arcadedb';

  @override
  bool get isConfigured => apikey().trim().isNotEmpty;

  @override
  bool get providesMetadata => true;

  @override
  bool get providesCover => true;

  @override
  Future<ScrapResult> scrap(ScrapContext ctx) async {
    final key = apikey().trim();
    if (key.isEmpty) {
      return const ScrapResult(provider: 'arcadedb');
    }

    try {
      final game = await _searchByMameId(ctx.gameName);
      if (game == null) {
        return const ScrapResult(provider: 'arcadedb');
      }

      final metadata = GameMetadata(
        name: _asString(game['description']),
        description: _asString(game['playfield']),
        genre: _asString(game['genre']),
        publisher: _asString(game['manufacturer']),
        releaseDate: _asString(game['release']),
        rating: null,
        players: _asString(game['players']),
        source: name,
      );

      return ScrapResult(
        provider: name,
        metadata: metadata,
        coverDownloaded: false,
      );
    } catch (_) {
      return const ScrapResult(provider: 'arcadedb');
    }
  }

  Future<Map<String, dynamic>?> _searchByMameId(String mameId) async {
    final uri = Uri.parse('$_base/api/roms/$mameId').replace(
      queryParameters: {'apikey': apikey()},
    );

    try {
      final res = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );

      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['status'] == 'failure') return null;
      return body['game'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  String? _asString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}