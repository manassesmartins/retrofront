import '../../models/game.dart';
import '../../models/system.dart';

/// Contexto de uma operacao de scraping para um jogo.
class ScrapContext {
  final SystemDefinition system;
  final String gameName;
  final String? existingCoverPath;

  const ScrapContext({
    required this.system,
    required this.gameName,
    this.existingCoverPath,
  });
}

/// Resultado de um provedor de scraping.
class ScrapResult {
  final String provider;
  final GameMetadata? metadata;
  final bool coverDownloaded;

  const ScrapResult({
    required this.provider,
    this.metadata,
    this.coverDownloaded = false,
  });

  bool get hasResult => metadata != null;
}

/// Contrato de um provedor de scraping (capa e/ou metadados).
abstract class ScrapProvider {
  String get name;

  /// Provedor esta pronto para uso (ex.: chave de API configurada).
  bool get isConfigured;

  bool get providesMetadata;
  bool get providesCover;

  Future<ScrapResult> scrap(ScrapContext ctx);
}
