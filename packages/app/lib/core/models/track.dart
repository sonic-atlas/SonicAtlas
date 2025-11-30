class Track {
  final String id;
  final String title;
  final String artist;
  final String? releaseId;
  final String? releaseTitle;
  final String album;
  final int duration;
  final int discNumber;
  final int? trackNumber;
  final String? transcodeStatus;
  final String? error;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    this.releaseId,
    this.releaseTitle,
    this.discNumber = 1,
    this.trackNumber,
    this.transcodeStatus,
    this.error,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] ?? {};
    return Track(
      id: json['id'],
      title: metadata['title'] ?? json['title'] ?? 'Unknown Title',
      artist: metadata['artist'] ?? json['artist'] ?? 'Unknown Artist',
      album: metadata['album'] ?? json['album'] ?? 'Unknown Album',
      duration: (json['duration'] ?? 0.0).round(),
      releaseId: json['releaseId'],
      releaseTitle: json['releaseTitle'],
      discNumber: json['discNumber'] ?? 1,
      trackNumber: json['trackNumber'],
      transcodeStatus: json['transcodeStatus'],
      error: json['error'],
    );
  }
}