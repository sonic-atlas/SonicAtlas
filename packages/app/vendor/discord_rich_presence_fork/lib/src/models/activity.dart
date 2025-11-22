enum ActivityType {
  playing(0),
  streaming(1),
  listening(2),
  watching(3),
  custom(4),
  competing(5);

  const ActivityType(this.id);
  final int id;
}

class Activity {
  Activity({required this.name, this.details, this.state, this.type = ActivityType.playing, this.url, this.timestamps, this.assets});

  final String name;
  final String? details;
  final String? state;
  final ActivityType type;
  final String? url;

  final ActivityTimestamps? timestamps;
  final ActivityAssets? assets;

  Map<String, dynamic> toJson() {
    final Map<String, Object?> _timestamps = timestamps?.toJson() ?? {};
    final Map<String, String?> _assets = assets?.toJson() ?? {};

    _timestamps.removeWhere((_, Object? value) => value == null);
    _assets.removeWhere((_, Object? value) => value == null);

    final Map<String, Object?> activity = {
      'name': name,
      'details': details,
      'state': state,
      'type': type.id,
      'url': url,

      'timestamps': _timestamps,
      'assets': _assets,
    };

    activity.removeWhere((_, Object? value) => value == null);

    return activity;
  }
}

enum ActivityAssetsImageSize {
  small,
  large
}

class ActivityAssets {
  const ActivityAssets({this.largeImage, this.largeText, this.smallImage, this.smallText});

  factory ActivityAssets.fromExternalLink(String url, {String? text, ActivityAssetsImageSize size = ActivityAssetsImageSize.large}) {
    if (size == ActivityAssetsImageSize.large) {
      return ActivityAssets(
        largeImage: url,
        largeText: text,
      );
    }

    return ActivityAssets(
      smallImage: url,
      smallText: text,
    );
  }

  final String? largeImage;
  final String? largeText;

  final String? smallImage;
  final String? smallText;

  Map<String, String?> toJson() {
    return <String, String?>{
      'large_image': largeImage,
      'large_text': largeText,

      'small_image': smallImage,
      'small_text': smallText,
    };
  }
}

class ActivityTimestamps {
  const ActivityTimestamps({this.start, this.end});

  final DateTime? start;
  final DateTime? end;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'start': start?.millisecondsSinceEpoch,
      'end': end?.millisecondsSinceEpoch,
    };
  }
}
