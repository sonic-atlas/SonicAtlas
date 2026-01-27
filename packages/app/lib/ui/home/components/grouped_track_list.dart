import 'package:flutter/material.dart';
import '/core/models/track.dart';
import '/ui/common/track_list_item.dart';

enum SortOption { year, name, artist }

class GroupedTrackList extends StatefulWidget {
  final List<Track> tracks;
  final Function(Track)? onTrackTap;

  const GroupedTrackList({
    super.key,
    required this.tracks,
    this.onTrackTap,
  });

  @override
  State<GroupedTrackList> createState() => _GroupedTrackListState();
}

class _GroupedTrackListState extends State<GroupedTrackList> {
  SortOption _sortBy = SortOption.year;

  List<dynamic> _getSortedItems() {
    final groups = <String, List<Track>>{};

    for (var track in widget.tracks) {
      final key = track.releaseId ?? 'unknown';
      groups.putIfAbsent(key, () => []).add(track);
    }

    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        if (a == 'unknown') return 1;
        if (b == 'unknown') return -1;

        final tracksA = groups[a]!;
        final tracksB = groups[b]!;
        final repA = tracksA.first;
        final repB = tracksB.first;

        switch (_sortBy) {
          case SortOption.year:
            return (repB.releaseYear ?? 0).compareTo(repA.releaseYear ?? 0);
          case SortOption.name:
            return (repA.releaseTitle ?? '').compareTo(repB.releaseTitle ?? '');
          case SortOption.artist:
            return (repA.releaseArtist ?? '').compareTo(
              repB.releaseArtist ?? '',
            );
        }
      });

    final result = [];

    for (var key in sortedKeys) {
      final groupTracks = groups[key]!;

      groupTracks.sort((a, b) {
        final discA = a.discNumber;
        final discB = b.discNumber;
        if (discA != discB) return discA.compareTo(discB);
        return (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0);
      });

      final distinctDiscs = groupTracks.map((t) => t.discNumber).toSet();
      final hasMultipleDiscs = distinctDiscs.length > 1;

      if (key != 'unknown') {
        final rep = groupTracks.first;
        result.add(
          _HeaderItem(
            title: rep.releaseTitle ?? 'Unknown Album',
            subtitle:
                '${rep.releaseArtist} • ${rep.releaseYear ?? "Unknown Year"}',
          ),
        );
      }

      int currentDisc = -1;

      for (var track in groupTracks) {
        final disc = track.discNumber;
        if (hasMultipleDiscs && disc != currentDisc) {
          currentDisc = disc;
          result.add(_DiscHeaderItem(title: 'Disc $disc'));
        }
        result.add(track);
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final displayItems = _getSortedItems();

    return Column(
      children: [
        _buildHeader(),
        if (widget.tracks.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'No tracks uploaded yet',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: displayItems.length,
              itemBuilder: (context, index) {
                final item = displayItems[index];

                if (item is _HeaderItem) {
                  return _buildGroupHeader(context, item);
                } else if (item is _DiscHeaderItem) {
                  return _buildDiscHeader(context, item);
                } else if (item is Track) {
                  return TrackListItem(
                    track: item,
                    trackNumber: item.trackNumber,
                    showAlbumInfo: false,
                    onTapOverride: widget.onTrackTap != null
                        ? () => widget.onTrackTap!(item)
                        : null,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Tracks',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          PopupMenuButton<SortOption>(
            initialValue: _sortBy,
            borderRadius: BorderRadius.circular(8),
            tooltip: 'Sort tracks',
            onSelected: (SortOption item) {
              setState(() {
                _sortBy = item;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Sort by: ${_getSortLabel(_sortBy)}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOption>>[
              const PopupMenuItem<SortOption>(
                value: SortOption.year,
                child: Text('Year'),
              ),
              const PopupMenuItem<SortOption>(
                value: SortOption.name,
                child: Text('Name'),
              ),
              const PopupMenuItem<SortOption>(
                value: SortOption.artist,
                child: Text('Artist'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getSortLabel(SortOption option) {
    switch (option) {
      case SortOption.year:
        return 'Year';
      case SortOption.name:
        return 'Name';
      case SortOption.artist:
        return 'Artist';
    }
  }

  Widget _buildGroupHeader(BuildContext context, _HeaderItem item) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscHeader(BuildContext context, _DiscHeaderItem item) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(
            Icons.album,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Text(
            item.title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderItem {
  final String title;
  final String subtitle;

  _HeaderItem({required this.title, required this.subtitle});
}

class _DiscHeaderItem {
  final String title;

  _DiscHeaderItem({required this.title});
}
