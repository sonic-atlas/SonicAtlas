class Release {
  final String id;
  final String title;
  final String? primaryArtist;
  final int? year;
  final String? releaseType;
  final String? coverArtPath;
  final String? genre;
  final DateTime? createdAt;

  Release({
    required this.id,
    required this.title,
    this.primaryArtist,
    this.year,
    this.releaseType,
    this.coverArtPath,
    this.genre,
    this.createdAt,
  });

  factory Release.fromJson(Map<String, dynamic> json) {
    return Release(
      id: json['id'],
      title: json['title'],
      primaryArtist: json['primaryArtist'],
      year: json['year'],
      releaseType: json['releaseType'],
      coverArtPath: json['coverArtPath'],
      genre: json['genre'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'primaryArtist': primaryArtist,
      'year': year,
      'releaseType': releaseType,
      'coverArtPath': coverArtPath,
      'genre': genre,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
