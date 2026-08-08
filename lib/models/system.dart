/// Definicao de um sistema/console, equivalente a um `<system>` do es_systems.xml do ES-DE.
class SystemDefinition {
  final String name;
  final String fullName;
  final String manufacturer;
  final int? releaseYear;
  final List<String> extensions;
  final String? platform;
  final String? theGamesDbPlatform;
  final String? libretroThumbnails;
  final String? command;
  final String? theme;

  const SystemDefinition({
    required this.name,
    required this.fullName,
    this.manufacturer = '',
    this.releaseYear,
    this.extensions = const [],
    this.platform,
    this.theGamesDbPlatform,
    this.libretroThumbnails,
    this.command,
    this.theme,
  });

  factory SystemDefinition.fromJson(Map<String, dynamic> json) {
    return SystemDefinition(
      name: json['name'] as String,
      fullName: json['fullName'] as String? ?? json['name'] as String,
      manufacturer: json['manufacturer'] as String? ?? '',
      releaseYear: (json['releaseYear'] as num?)?.toInt(),
      extensions: (json['extension'] as String? ?? '')
          .split(RegExp(r'\s+'))
          .where((e) => e.isNotEmpty)
          .toList(),
      platform: json['platform'] as String?,
      theGamesDbPlatform: json['theGamesDbPlatform'] as String?,
      libretroThumbnails: json['libretroThumbnails'] as String?,
      command: json['command'] as String?,
      theme: json['theme'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'fullName': fullName,
        'manufacturer': manufacturer,
        if (releaseYear != null) 'releaseYear': releaseYear,
        'extension': extensions.join(' '),
        'platform': platform,
        'theGamesDbPlatform': theGamesDbPlatform,
        'libretroThumbnails': libretroThumbnails,
        'command': command,
        'theme': theme,
      };

  /// Verifica se uma extensao de arquivo (com ponto, ex: ".nes") e suportada.
  bool matchesExtension(String ext) {
    final e = ext.trim().toLowerCase();
    if (e.isEmpty) return false;
    return extensions.any((x) => x.toLowerCase() == e);
  }
}

/// Sistema descoberto no disco: definicao + pasta + estatisticas.
class SystemEntry {
  final SystemDefinition definition;
  final String path;
  int gameCount;
  bool hasMedia;

  SystemEntry({
    required this.definition,
    required this.path,
    this.gameCount = 0,
    this.hasMedia = false,
  });

  String get name => definition.name;
  String get fullName => definition.fullName;
}
