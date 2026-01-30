class Track {
  final String id;
  final String title;
  final String artist;
  final String? releaseId;
  final String? releaseTitle;
  final String? releaseArtist;
  final int? releaseYear;
  final String? releaseType;
  final String album;
  final int duration;
  final int discNumber;
  final int? trackNumber;
  final String? transcodeStatus;
  final String? error;

  final String? codec;
  final int? bitrate;
  final int? sampleRate;
  final int? bitDepth;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    this.releaseId,
    this.releaseTitle,
    this.releaseType,
    this.releaseArtist,
    this.releaseYear,
    this.discNumber = 1,
    this.trackNumber,
    this.transcodeStatus,
    this.error,
    this.codec,
    this.bitrate,
    this.sampleRate,
    this.bitDepth,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] ?? {};
    return Track(
      id: json['id'],
      title: metadata['title'] ?? json['title'] ?? 'Unknown Title',
      artist: metadata['artist'] ?? json['artist'] ?? 'Unknown Artist',
      album:
          json['releaseTitle'] ??
          json['album'] ??
          metadata['album'] ??
          'Unknown Album',
      duration: (json['duration'] ?? 0.0).round(),
      releaseId: json['releaseId'],
      releaseTitle: json['releaseTitle'],
      releaseArtist: json['releaseArtist'],
      releaseYear: json['releaseYear'],
      releaseType: json['releaseType'],
      discNumber: json['discNumber'] ?? 1,
      trackNumber: json['trackNumber'],
      transcodeStatus: json['transcodeStatus'],
      error: json['error'],
      codec: metadata['codec'],
      bitrate: metadata['bitrate'],
      sampleRate: metadata['sampleRate'],
      bitDepth: metadata['bitDepth'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'artist': artist,
      'duration': duration
    };
  }

  @override
  String toString() {
    return 'Track(id: $id, title: $title, artist: $artist, album: $album)';
  }
}
