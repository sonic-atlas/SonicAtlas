import '../playback/audio.dart';
import '../network/api.dart';

void handleCLA(
  List<String> args, {
  required AudioService audioService,
  required ApiService apiService,
}) async {
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--play' && i + 1 < args.length) {
      final track = await apiService.getTrack(args[i + 1]);
      if (track == null) {
        return;
      }
      await audioService.playTrack(track);
    }
  }
}
