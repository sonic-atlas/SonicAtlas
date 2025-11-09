import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/core/services/api.dart';
import '/core/services/audio.dart';
import '/ui/pages/fs_player.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final audioService = context.watch<AudioService>();
    final apiService = context.read<ApiService>();
    final track = audioService.currentTrack;

    if (track == null) {
      return const SizedBox.shrink();
    }

    final imageUrl = apiService.getAlbumArtUrl(track.id);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const FullScreenPlayerPage(),
            fullscreenDialog: true,
          ),
        );
      },
      child: SizedBox(
        height: 64,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Image.network(
                imageUrl,
                headers: apiService.headers,
                fit: BoxFit.cover,
                color: Colors.black.withValues(alpha: 0.4),
                colorBlendMode: BlendMode.darken,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      imageUrl,
                      headers: apiService.headers,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 48,
                          height: 48,
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.music_note),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(track.title, overflow: TextOverflow.ellipsis),
                        Text(
                          track.artist,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      audioService.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                    onPressed: () {
                      audioService.isPlaying
                          ? audioService.pause()
                          : audioService.play();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
