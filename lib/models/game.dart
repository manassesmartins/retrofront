/// Metadados de um jogo (preenchidos por scraping ou manualmente).
class GameMetadata {
  final String? description;
  final String? genre;
  final String? publisher;
  final String? developer;
  final String? releaseDate;
  final double? rating;
  final String? players;
  final String? coverPath;
  final String? videoUrl;
  final String? source;

  const GameMetadata({
    this.description,
    this.genre,
    this.publisher,
    this.developer,
    this.releaseDate,
    this.rating,
    this.players,
    this.coverPath,
    this.videoUrl,
    this.source,
  });

  bool get hasData =>
      description != null ||
      genre != null ||
      publisher != null ||
      releaseDate != null ||
      rating != null;

  factory GameMetadata.fromJson(Map<String, dynamic> json) => GameMetadata(
        description: json['desc'] as String?,
        genre: json['genre'] as String?,
        publisher: json['publisher'] as String?,
        developer: json['developer'] as String?,
        releaseDate: json['releasedate'] as String?,
        rating: (json['rating'] as num?)?.toDouble(),
        players: json['players'] as String?,
        coverPath: json['cover'] as String?,
        videoUrl: json['video'] as String?,
        source: json['source'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (description != null) 'desc': description,
        if (genre != null) 'genre': genre,
        if (publisher != null) 'publisher': publisher,
        if (developer != null) 'developer': developer,
        if (releaseDate != null) 'releasedate': releaseDate,
        if (rating != null) 'rating': rating,
        if (players != null) 'players': players,
        if (coverPath != null) 'cover': coverPath,
        if (videoUrl != null) 'video': videoUrl,
        if (source != null) 'source': source,
      };

  GameMetadata copyWith({
    String? description,
    String? genre,
    String? publisher,
    String? developer,
    String? releaseDate,
    double? rating,
    String? players,
    String? coverPath,
    String? videoUrl,
    String? source,
  }) {
    return GameMetadata(
      description: description ?? this.description,
      genre: genre ?? this.genre,
      publisher: publisher ?? this.publisher,
      developer: developer ?? this.developer,
      releaseDate: releaseDate ?? this.releaseDate,
      rating: rating ?? this.rating,
      players: players ?? this.players,
      coverPath: coverPath ?? this.coverPath,
      videoUrl: videoUrl ?? this.videoUrl,
      source: source ?? this.source,
    );
  }
}
