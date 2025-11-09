/// Quality information with codec and bitrate details
class QualityInfo {
  final String label;
  final String codec;
  final String? bitrate;
  final String? sampleRate;

  const QualityInfo({
    required this.label,
    required this.codec,
    this.bitrate,
    this.sampleRate,
  });
}

/// Audio quality options for streaming
/// Matches the Quality type from @sonic-atlas/shared/types
enum Quality {
  auto('auto'),
  efficiency('efficiency'),
  high('high'),
  cd('cd'),
  hires('hires');

  const Quality(this.value);
  final String value;

  @override
  String toString() => value;

  /// Get display label for this quality
  String get label {
    switch (this) {
      case Quality.auto:
        return 'Auto (ABR)';
      case Quality.efficiency:
        return 'Efficiency';
      case Quality.high:
        return 'High';
      case Quality.cd:
        return 'CD';
      case Quality.hires:
        return 'Hi-Res';
    }
  }

  /// Get detailed quality information
  QualityInfo get info {
    switch (this) {
      case Quality.auto:
        return const QualityInfo(
          label: 'Auto (ABR)',
          codec: 'Adaptive',
          bitrate: 'Varies',
        );
      case Quality.efficiency:
        return const QualityInfo(
          label: 'Efficiency',
          codec: 'AAC',
          bitrate: '128k',
        );
      case Quality.high:
        return const QualityInfo(
          label: 'High',
          codec: 'AAC',
          bitrate: '320k',
        );
      case Quality.cd:
        return const QualityInfo(
          label: 'CD',
          codec: 'FLAC',
          sampleRate: '44.1kHz',
        );
      case Quality.hires:
        return const QualityInfo(
          label: 'Hi-Res',
          codec: 'FLAC',
          sampleRate: 'Original',
        );
    }
  }

  /// Parse quality from string value
  static Quality fromString(String value) {
    return Quality.values.firstWhere(
      (q) => q.value == value,
      orElse: () => Quality.hires,
    );
  }
}

