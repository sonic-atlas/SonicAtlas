enum RecordingBitDepth { int16, int24, int32 }

class TrackSplit {
  final int number;
  final Duration start;
  final Duration? end;
  final String title;
  final String? artist;

  TrackSplit({
    required this.number,
    required this.start,
    this.end,
    this.title = '',
    this.artist,
  });
}
