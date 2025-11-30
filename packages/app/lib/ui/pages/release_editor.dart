import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '/core/models/release.dart';
import '/core/models/track.dart';
import '/core/services/api.dart';
import '/core/services/socket.dart';

class ReleaseEditorPage extends StatefulWidget {
  final String releaseId;

  const ReleaseEditorPage({super.key, required this.releaseId});

  @override
  State<ReleaseEditorPage> createState() => _ReleaseEditorPageState();
}

class _ReleaseEditorPageState extends State<ReleaseEditorPage> {
  Release? _release;
  List<Track> _tracks = [];
  final Map<String, String> _trackStatuses = {};
  bool _loading = true;
  bool _saving = false;
  io.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupSocket();
  }

  @override
  void dispose() {
    if (_socket != null) {
      _socket!.off('transcode:started');
      _socket!.off('transcode:done');
      _socket!.off('transcode:error');
    }
    super.dispose();
  }

  void _setupSocket() {
    _socket = Provider.of<SocketService>(context, listen: false).socket;
    if (_socket == null) return;

    _socket!.on('transcode:started', (data) => _handleSocketMessage(data, 'processing'));
    _socket!.on('transcode:done', (data) => _handleSocketMessage(data, 'done'));
    _socket!.on('transcode:error', (data) => _handleSocketMessage(data, 'error', error: data['error']));
  }

  void _handleSocketMessage(dynamic data, String status, {String? error}) {
    if (data == null || data is! Map || !data.containsKey('trackId')) return;
    final trackId = data['trackId'];
    
    setState(() {
      _trackStatuses[trackId] = status;
      _updateTrackInList(trackId, status, error: error);
    });
  }

  void _updateTrackInList(String trackId, String status, {String? error}) {
    final index = _tracks.indexWhere((t) => t.id == trackId);
    if (index != -1) {
      final old = _tracks[index];
      _tracks[index] = Track(
        id: old.id,
        title: old.title,
        artist: old.artist,
        album: old.album,
        duration: old.duration,
        releaseId: old.releaseId,
        releaseTitle: old.releaseTitle,
        discNumber: old.discNumber,
        trackNumber: old.trackNumber,
        transcodeStatus: status,
        error: error,
      );
    }
  }

  Future<void> _loadData() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final release = await api.getRelease(widget.releaseId);
      final tracks = await api.getReleaseTracks(widget.releaseId);
      
      if (mounted) {
        setState(() {
          _release = release;
          _tracks = tracks;
          
          for (var i = 0; i < _tracks.length; i++) {
            final track = _tracks[i];
            if (_trackStatuses.containsKey(track.id)) {
              _tracks[i] = Track(
                id: track.id,
                title: track.title,
                artist: track.artist,
                album: track.album,
                duration: track.duration,
                releaseId: track.releaseId,
                releaseTitle: track.releaseTitle,
                discNumber: track.discNumber,
                trackNumber: track.trackNumber,
                transcodeStatus: _trackStatuses[track.id],
                error: track.error,
              );
            }
          }
          
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveRelease() async {
    if (_release == null) return;
    setState(() => _saving = true);
    
    final api = Provider.of<ApiService>(context, listen: false);
    await api.updateRelease(_release!.id, {
      'title': _release!.title,
      'primaryArtist': _release!.primaryArtist,
      'year': _release!.year,
      'releaseType': _release!.releaseType,
    });
    
    setState(() => _saving = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Release saved')));
  }

  Future<void> _saveTrack(Track track) async {
    final api = Provider.of<ApiService>(context, listen: false);
    await api.updateTrackMetadata(track.id, {
      'title': track.title,
      'artist': track.artist,
      'discNumber': track.discNumber,
      'trackNumber': track.trackNumber,
      'releaseId': _release?.id,
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_release == null) return const Scaffold(body: Center(child: Text('Release not found')));

    final discs = <int, List<Track>>{};
    for (var t in _tracks) {
      discs.putIfAbsent(t.discNumber, () => []).add(t);
    }
    final sortedDiscs = discs.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Release'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saving ? null : _saveRelease,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_tracks.isNotEmpty && _tracks.any((t) => t.transcodeStatus != 'done'))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Processing: ${_tracks.where((t) => t.transcodeStatus == 'done').length}/${_tracks.length} tracks',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: _tracks.where((t) => t.transcodeStatus == 'done').length / _tracks.length,
                      backgroundColor: Theme.of(context).cardColor,
                    ),
                  ],
                ),
              ),

            Card(
              color: Colors.transparent,
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: _release!.title,
                      decoration: const InputDecoration(labelText: 'Title'),
                      onChanged: (v) => _release = Release(
                        id: _release!.id,
                        title: v,
                        primaryArtist: _release!.primaryArtist,
                        year: _release!.year,
                        releaseType: _release!.releaseType,
                        coverArtPath: _release!.coverArtPath,
                        createdAt: _release!.createdAt,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _release!.primaryArtist,
                      decoration: const InputDecoration(labelText: 'Artist'),
                      onChanged: (v) => _release = Release(
                        id: _release!.id,
                        title: _release!.title,
                        primaryArtist: v,
                        year: _release!.year,
                        releaseType: _release!.releaseType,
                        coverArtPath: _release!.coverArtPath,
                        createdAt: _release!.createdAt,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            ...sortedDiscs.map((discNum) {
              final discTracks = discs[discNum]!;
              discTracks.sort((a, b) => (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0));
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Disc $discNum', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: true,
                    itemCount: discTracks.length,
                    onReorder: (oldIndex, newIndex) {
                      if (oldIndex < newIndex) newIndex -= 1;
                      final item = discTracks.removeAt(oldIndex);
                      discTracks.insert(newIndex, item);
                      
                      for (int i = 0; i < discTracks.length; i++) {
                        final t = discTracks[i];
                        final updated = Track(
                          id: t.id,
                          title: t.title,
                          artist: t.artist,
                          album: t.album,
                          duration: t.duration,
                          releaseId: t.releaseId,
                          releaseTitle: t.releaseTitle,
                          discNumber: discNum,
                          trackNumber: i + 1,
                          transcodeStatus: t.transcodeStatus,
                          error: t.error,
                        );
                        final mainIndex = _tracks.indexWhere((tr) => tr.id == t.id);
                        _tracks[mainIndex] = updated;
                        _saveTrack(updated);
                      }
                      setState(() {});
                    },
                    itemBuilder: (context, index) {
                      final track = discTracks[index];
                      return Container(
                        key: ValueKey(track.id),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(8),
                          color: Theme.of(context).cardColor.withOpacity(0.02),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          leading: _buildStatusIcon(track),
                          title: TextFormField(
                            initialValue: track.title,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (v) {
                              final updated = Track(
                                id: track.id,
                                title: v,
                                artist: track.artist,
                                album: track.album,
                                duration: track.duration,
                                releaseId: track.releaseId,
                                releaseTitle: track.releaseTitle,
                                discNumber: track.discNumber,
                                trackNumber: track.trackNumber,
                                transcodeStatus: track.transcodeStatus,
                                error: track.error,
                              );
                              final mainIndex = _tracks.indexWhere((t) => t.id == track.id);
                              _tracks[mainIndex] = updated;
                              _saveTrack(updated);
                            },
                          ),
                          subtitle: Text('${track.artist} • Track ${track.trackNumber}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PopupMenuButton<int>(
                                icon: const Icon(Icons.album_outlined),
                                tooltip: 'Move to Disc',
                                onSelected: (newDisc) {
                                    final updated = Track(
                                      id: track.id,
                                      title: track.title,
                                      artist: track.artist,
                                      album: track.album,
                                      duration: track.duration,
                                      releaseId: track.releaseId,
                                      releaseTitle: track.releaseTitle,
                                      discNumber: newDisc,
                                      trackNumber: track.trackNumber,
                                      transcodeStatus: track.transcodeStatus,
                                      error: track.error,
                                    );
                                    final mainIndex = _tracks.indexWhere((t) => t.id == track.id);
                                    setState(() {
                                      _tracks[mainIndex] = updated;
                                    });
                                    _saveTrack(updated);
                                  },
                                  itemBuilder: (context) {
                                    final maxDisc = sortedDiscs.isEmpty ? 1 : sortedDiscs.last;
                                    return [
                                      ...sortedDiscs.map((d) => PopupMenuItem(
                                        value: d,
                                        child: Text('Disc $d'),
                                      )),
                                      PopupMenuItem(
                                        value: maxDisc + 1,
                                        child: Text('New Disc ${maxDisc + 1}'),
                                      ),
                                    ];
                                  },
                                ),
                              const Icon(Icons.drag_handle),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(Track track) {
    if (track.transcodeStatus == 'done') return const Icon(Icons.check_circle, color: Colors.green);
    if (track.transcodeStatus == 'processing') return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
    if (track.transcodeStatus == 'error') return const Icon(Icons.error, color: Colors.red);
    return const Icon(Icons.circle_outlined);
  }
}
