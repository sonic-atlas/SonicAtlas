import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/core/models/track.dart';
import '/core/services/api.dart';
import '/core/services/audio.dart';

class TrackListItem extends StatelessWidget {
  final Track track;

  const TrackListItem({super.key, required this.track});

  @override
  Widget build(BuildContext context) {
    final audioService = context.watch<AudioService>();
    final apiService = context.read<ApiService>();
    final bool isPlaying = audioService.currentTrack?.id == track.id;

    final duration = Duration(seconds: track.duration);
    final durationText =
        '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

    void handlePointerDown(PointerDownEvent event) {
      if (event.kind == PointerDeviceKind.mouse &&
          event.buttons == kSecondaryMouseButton) {
        _showTrackMenu(context, track);
      }
    }

    Widget trailingWidget = isPlaying
        ? Icon(Icons.volume_up, color: Theme.of(context).colorScheme.primary)
        : Text(durationText);

    trailingWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        trailingWidget,
        IconButton(
          icon: const Icon(Icons.more_horiz),
          tooltip: 'More',
          onPressed: () => _showTrackMenu(context, track),
        ),
      ],
    );

    return Listener(
      onPointerDown: handlePointerDown,
      child: ListTile(
        leading: Image.network(
          apiService.getAlbumArtUrl(track.id),
          headers: context.read<ApiService>().headers,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.album),
        ),
        title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${track.artist} • ${track.album}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () {
          context.read<AudioService>().playTrack(track);
        },
        onLongPress: () {
          _showTrackMenu(context, track);
        },
        trailing: trailingWidget,
      ),
    );
  }

  void _showTrackMenu(BuildContext context, Track track) {
    final audioService = context.read<AudioService>();
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.playlist_play),
            title: const Text('Play next'),
            onTap: () {
              audioService.addNextToQueue(track);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Added "${track.title}" to play next')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.queue),
            title: const Text('Add to queue'),
            onTap: () {
              audioService.addToQueue(track);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Added "${track.title}" to queue')),
              );
            },
          ),
        ],
      ),
    );
  }
}
