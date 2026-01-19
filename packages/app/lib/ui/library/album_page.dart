import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/core/models/track.dart';
import '/core/services/network/api.dart';
import '/core/services/playback/audio.dart';
import '/ui/common/track_list_item.dart';
import '/ui/common/layout.dart';

class AlbumPage extends StatefulWidget {
  final String releaseId;
  final String releaseTitle;
  final String? releaseCover;
  final String? releaseArtist;
  final int? releaseYear;

  const AlbumPage({
    super.key,
    required this.releaseId,
    required this.releaseTitle,
    this.releaseCover,
    this.releaseArtist,
    this.releaseYear,
  });

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  late Future<List<Track>> _tracksFuture;

  @override
  void initState() {
    super.initState();
    _tracksFuture = context.read<ApiService>().getReleaseTracks(
      widget.releaseId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      child: Scaffold(
        appBar: AppBar(title: Text(widget.releaseTitle)),
        body: FutureBuilder<List<Track>>(
          future: _tracksFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final tracks = snapshot.data ?? [];
            if (tracks.isEmpty) {
              return const Center(child: Text('No tracks found'));
            }

            tracks.sort((a, b) {
              final discCompare = a.discNumber.compareTo(b.discNumber);
              if (discCompare != 0) return discCompare;
              return (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0);
            });

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: context
                                .read<ApiService>()
                                .getReleaseCoverUrl(widget.releaseId),
                            memCacheWidth: 320,
                            memCacheHeight: 320,
                            width: 160,
                            height: 160,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(
                              width: 160,
                              height: 160,
                              color: Colors.grey[900],
                              child: const Icon(Icons.album, size: 64),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.releaseTitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.releaseArtist ?? 'Unknown Artist',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                              if (widget.releaseYear != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  widget.releaseYear.toString(),
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.icon(
                                    onPressed: () {
                                      context.read<AudioService>().playTrack(
                                        tracks.first,
                                        queue: tracks,
                                      );
                                    },
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('Play'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      context
                                          .read<AudioService>()
                                          .addAllToQueue(tracks);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Album added to queue'),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.queue_music),
                                    label: const Text('Add to Queue'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = tracks[index];
                      return TrackListItem(
                        track: track,
                        trackNumber: track.trackNumber ?? (index + 1),
                        onTapOverride: () {
                          context.read<AudioService>().playTrack(
                            track,
                            queue: tracks,
                          );
                        },
                      );
                    },
                    childCount: tracks.length,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
