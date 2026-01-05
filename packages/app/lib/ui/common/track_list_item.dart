import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/core/models/track.dart';
import '../../core/services/network/api.dart';
import '../../core/services/playback/audio.dart';
import '/ui/library/album_page.dart';

class TrackListItem extends StatelessWidget {
  final Track track;
  final VoidCallback? onTapOverride;
  final int? trackNumber;
  final bool showCover;

  const TrackListItem({
    super.key,
    required this.track,
    this.onTapOverride,
    this.trackNumber,
    this.showCover = true,
  });

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
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trackNumber != null) ...[
              SizedBox(
                width: 30,
                child: Center(
                  child: Text(
                    trackNumber.toString(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isPlaying
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (showCover)
              CachedNetworkImage(
                imageUrl: apiService.getAlbumArtUrl(track.id, size: 'small'),
                httpHeaders: context.read<ApiService>().headers,
                memCacheWidth: 80,
                memCacheHeight: 80,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 0),
                errorWidget: (context, url, error) => const Icon(Icons.album),
                placeholder: (context, url) =>
                    Container(width: 40, height: 40, color: Colors.grey[900]),
              ),
          ],
        ),
        title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${track.artist} • ${track.releaseTitle ?? track.album}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onTapOverride ?? () {
          context.read<AudioService>().playTrack(track);
        },
        onLongPress: () {
          _showTrackMenu(context, track);
        },
        trailing: trailingWidget,
        selected: isPlaying,
        selectedTileColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      ),
    );
  }

  void _showTrackMenu(BuildContext context, Track track) {
    final audioService = context.read<AudioService>();
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: <Widget>[
          if (track.releaseId != null)
            ListTile(
              leading: const Icon(Icons.album),
              title: const Text('View Album'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AlbumPage(
                      releaseId: track.releaseId!,
                      releaseTitle: track.releaseTitle ?? track.album,
                      releaseArtist: track.artist,
                    ),
                  ),
                );
              },
            ),
          const Divider(),
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
