import 'game.dart';

/// Normalizacao do nome de jogo para exibicao (estilo EmulationStation):
/// usa o titulo salvo no gamelist quando existir; caso contrario, limpa o nome
/// do arquivo (remove extensao, tags de regiao/rom e separadores).
class GameName {
  GameName._();

  static String clean(GameMetadata? metadata, String fileName) {
    final custom = metadata?.name;
    if (custom != null && custom.trim().isNotEmpty) return custom.trim();
    return cleanFileName(fileName);
  }

  /// Limpa o nome de arquivo (ex.: "Super Mario Bros. (USA).nes" ->
  /// "Super Mario Bros").
  static String cleanFileName(String fileName) {
    var name = fileName.trim();
    if (name.isEmpty) return name;

    final dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);

    // Remove tags de regiao/rom, ex.: (USA), (Europe), (Rev 1), [!], [b1], ...
    var changed = true;
    while (changed) {
      changed = false;
      final stripped = name
          .replaceAll(RegExp(r'\s*\([^()]*\)'), '')
          .replaceAll(RegExp(r'\s*\[[^\[\]]*\]'), '');
      if (stripped != name) {
        name = stripped;
        changed = true;
      }
    }

    // Separadores de nome -> espacos.
    name = name.replaceAll('_', ' ').replaceAll('.', ' ');

    // Colapsa espacos e remove pontuacao final ("-", ",").
    name = name
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^\s*[,·:\-—]+\s*'), '')
        .replaceAll(RegExp(r'\s*[,·:\-—]+\s*$'), '')
        .trim();

    return name;
  }
}
