import 'game.dart';
import 'game_name.dart';

enum GameEntryType { game, folder }

/// Entrada de uma lista de jogos: um arquivo ROM ou uma subpasta (espelha o
/// paradigma de sistema de arquivos do ES-DE).
class GameEntry {
  final String name;
  final String path;
  final String system;
  final GameEntryType type;
  final GameMetadata? metadata;

  const GameEntry({
    required this.name,
    required this.path,
    required this.system,
    this.type = GameEntryType.game,
    this.metadata,
  });

  bool get isFolder => type == GameEntryType.folder;

  /// Nome de exibicao: titulo do gamelist ou nome limpo do arquivo.
  String get displayName => GameName.clean(metadata, name);

  GameEntry copyWith({GameMetadata? metadata, String? name}) => GameEntry(
        name: name ?? this.name,
        path: path,
        system: system,
        type: type,
        metadata: metadata ?? this.metadata,
      );

  @override
  bool operator ==(Object other) =>
      other is GameEntry && other.path == path;

  @override
  int get hashCode => path.hashCode;
}
