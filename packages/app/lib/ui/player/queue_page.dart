import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/network/api.dart';
import '../../core/services/playback/audio.dart';

class QueuePage extends StatelessWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    final audioService = context.watch<AudioService>();
    final apiService = context.read<ApiService>();
    final queue = audioService.queue;
    final currentIndex = audioService.currentIndex;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue'),
        actions: [
          if (queue.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () {
                audioService.clearQueue();
                Navigator.pop(context);
              },
              tooltip: 'Clear Queue',
            ),
        ],
      ),
      body: queue.isEmpty
          ? const Center(child: Text('Queue is empty'))
          : ReorderableListView.builder(
              itemCount: queue.length,
              onReorder: (oldIndex, newIndex) {},
              itemBuilder: (context, index) {
                final track = queue[index];
                final isCurrentTrack = index == currentIndex;
                final imageUrl = apiService.getAlbumArtUrl(track.id);

                return Dismissible(
                  key: Key('${track.id}_$index'),
                  direction: isCurrentTrack
                      ? DismissDirection.none
                      : DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    audioService.removeFromQueue(index);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Removed ${track.title} from queue'),
                      ),
                    );
                  },
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        imageUrl,
                        headers: apiService.headers,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 50,
                            height: 50,
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.music_note),
                          );
                        },
                      ),
                    ),
                    title: Text(
                      track.title,
                      style: TextStyle(
                        fontWeight: isCurrentTrack
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isCurrentTrack
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    subtitle: Text(track.artist),
                    trailing: isCurrentTrack
                        ? Icon(
                            Icons.play_arrow,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_handle),
                          ),
                    onTap: () {
                      if (!isCurrentTrack) {
                        audioService.playTrack(track, queue: queue);
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
