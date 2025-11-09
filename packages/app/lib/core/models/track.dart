class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final int duration;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
  });

  // Based on packages/backend/db/schema.ts (tracks table)
  factory Track.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] ?? {};
    return Track(
      id: json['id'],
      title: metadata['title'] ?? 'Unknown Title',
      artist: metadata['artist'] ?? 'Unknown Artist',
      album: metadata['album'] ?? 'Unknown Album',
      duration: (json['duration'] ?? 0.0).round(),
    );
  }
}