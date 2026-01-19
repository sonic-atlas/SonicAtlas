import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/core/models/track.dart';
import '/core/services/network/api.dart';
import '/ui/library/album_page.dart';

class AlbumGrid extends StatelessWidget {
  final List<Track> tracks;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const AlbumGrid({
    super.key,
    required this.tracks,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Track>> albumsMatch = {};
    for (var track in tracks) {
      if (track.releaseId == null) continue;
      final key = track.releaseId!;
      if (!albumsMatch.containsKey(key)) {
        albumsMatch[key] = [];
      }
      albumsMatch[key]!.add(track);
    }

    final albums = albumsMatch.entries.toList();
    albums.sort((a, b) => a.value.first.album.compareTo(b.value.first.album));

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      shrinkWrap: shrinkWrap,
      physics: physics,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final albumTracks = albums[index].value;
        final representative = albumTracks.first;
        final title = representative.releaseTitle ?? representative.album;
        final artist = representative.artist;
        final releaseId = representative.releaseId!;

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AlbumPage(
                  releaseId: releaseId,
                  releaseTitle: title,
                  releaseArtist: artist,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: context.read<ApiService>().getReleaseCoverUrl(
                      releaseId,
                    ),
                    memCacheWidth: 400,
                    memCacheHeight: 400,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[900],
                      child: const Icon(Icons.album, size: 48),
                    ),
                    placeholder: (context, url) => Container(
                      color: Colors.grey[900],
                      child: const Icon(Icons.album, size: 48),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}
