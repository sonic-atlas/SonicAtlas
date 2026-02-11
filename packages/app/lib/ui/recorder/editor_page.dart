/*import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import '../../../../core/services/recorder/recorder_service.dart';
import '../../../../core/services/recorder/processing_service.dart';
import '../../../../core/models/release.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage>
    with SingleTickerProviderStateMixin {
  late final Player _player;
  late final TabController _tabController;

  final Map<String, List<TrackSplit>> _fileSplits = {};
  final Map<String, String> _waveforms = {};

  List<String> _files = [];
  bool _isLoading = true;

  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = Player();

    _player.stream.position.listen((pos) {
      if (mounted) setState(() => _currentPosition = pos);
    });

    _player.stream.duration.listen((dur) {
      if (mounted) setState(() => _totalDuration = dur);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTracks();
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTracks() async {
    final recorder = context.read<SonicRecorderService>();

    _files = List.from(recorder.sessionFiles);

    _tabController = TabController(length: _files.length, vsync: this);
    _tabController.addListener(_onTabChanged);

    if (_files.isNotEmpty) {
      try {
        for (var path in _files) {
          await _generateWaveform(path);

          _fileSplits[path] = [
            TrackSplit(
              number: 1,
              start: Duration.zero,
              end: null,
              title: 'Track 1',
            ),
          ];
        }

        await _loadFile(_files.first);

        setState(() {
          _isLoading = false;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error loading: $e')));
        }
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onTabChanged() async {
    if (_tabController.indexIsChanging) return;
    final index = _tabController.index;
    if (index >= 0 && index < _files.length) {
      await _loadFile(_files[index]);
    }
  }

  Future<void> _loadFile(String path) async {
    await _player.open(Media(path));
    setState(() {});
  }

  Future<void> _generateWaveform(String wavPath) async {
    final dir = path.dirname(wavPath);
    final waveformPath = path.join(
      dir,
      '${path.basenameWithoutExtension(wavPath)}_waveform.png',
    );
    final file = File(waveformPath);

    if (!await file.exists()) {
      try {
        await Process.run('ffmpeg', [
          '-y',
          '-i',
          wavPath,
          '-filter_complex',
          'showwavespic=s=1024x120:colors=green',
          '-frames:v',
          '1',
          waveformPath,
        ]);
      } catch (e) {
        debugPrint('Waveform generation failed: $e');
      }
    }

    if (await file.exists()) {
      _waveforms[wavPath] = waveformPath;
    }
  }

  Future<void> _process(Release metadata, bool treatSidesAsDiscs) async {
    if (_files.isEmpty) return;
    final processor = context.read<ProcessingService>();
    try {
      final allPaths = <String>[];

      for (var i = 0; i < _files.length; i++) {
        final path = _files[i];
        final splits = _fileSplits[path]!;

        final discNo = treatSidesAsDiscs ? (i + 1) : 1;

        final paths = await processor.splitAndTranscode(
          path,
          splits,
          metadata,
          discNumber: discNo,
          upload: false,
        );
        allPaths.addAll(paths);
      }

      await processor.uploadAll(allPaths, metadata);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Processing Complete!')));
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Processing Failed: $e')));
      }
    }
  }

  Future<void> _showMetadataDialog() async {
    final artistController = TextEditingController();
    final albumController = TextEditingController();
    final yearController = TextEditingController();
    final genreController = TextEditingController();
    String releaseType = 'album';
    String? coverPath;
    bool treatSidesAsDiscs = _files.length > 1;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Album Metadata'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: artistController,
                  decoration: const InputDecoration(
                    labelText: 'Artist',
                    hintText: 'Required',
                  ),
                ),
                TextField(
                  controller: albumController,
                  decoration: const InputDecoration(
                    labelText: 'Album',
                    hintText: 'Required',
                  ),
                ),
                TextField(
                  controller: yearController,
                  decoration: const InputDecoration(labelText: 'Year'),
                ),
                TextField(
                  controller: genreController,
                  decoration: const InputDecoration(labelText: 'Genre'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: releaseType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: ['album', 'ep', 'single', 'compilation']
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.toUpperCase()),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => releaseType = v!),
                ),
                if (_files.length > 1)
                  CheckboxListTile(
                    title: const Text(
                      'Treat each recording as a separate disc',
                    ),
                    value: treatSidesAsDiscs,
                    onChanged: (v) => setState(() => treatSidesAsDiscs = v!),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        coverPath != null
                            ? path.basename(coverPath!)
                            : 'No Cover Selected',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.image),
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                        );
                        if (result != null) {
                          setState(() => coverPath = result.files.single.path);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (artistController.text.isEmpty ||
                    albumController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Artist and Album are required'),
                    ),
                  );
                  return;
                }
                final release = Release(
                  id: const Uuid().v4(),
                  title: albumController.text,
                  primaryArtist: artistController.text,
                  year: int.tryParse(yearController.text),
                  genre: genreController.text.isEmpty
                      ? null
                      : genreController.text,
                  releaseType: releaseType,
                  coverArtPath: coverPath,
                  createdAt: DateTime.now(),
                );
                Navigator.pop(context, {
                  'release': release,
                  'treatSidesAsDiscs': treatSidesAsDiscs,
                });
              },
              child: const Text('Process'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      _process(result['release'], result['treatSidesAsDiscs']);
    }
  }

  void _setStart(int index) {
    final currentPath = _files[_tabController.index];
    final splits = _fileSplits[currentPath];
    if (splits == null) return;

    setState(() {
      final t = splits[index];
      splits[index] = TrackSplit(
        number: t.number,
        start: _currentPosition,
        end: t.end,
        title: t.title,
      );
      _sortAndRenumber(splits);
    });
  }

  void _setEnd(int index) {
    final currentPath = _files[_tabController.index];
    final splits = _fileSplits[currentPath];
    if (splits == null) return;

    setState(() {
      final t = splits[index];
      if (_currentPosition > t.start) {
        splits[index] = TrackSplit(
          number: t.number,
          start: t.start,
          end: _currentPosition,
          title: t.title,
        );
      }
    });
  }

  void _addRegion() {
    final currentPath = _files[_tabController.index];
    final splits = _fileSplits[currentPath];
    if (splits == null) return;

    setState(() {
      final start = _currentPosition;
      final end = start + const Duration(seconds: 30);

      splits.add(TrackSplit(number: 0, start: start, end: end, title: ''));
      _sortAndRenumber(splits);
    });
  }

  void _sortAndRenumber(List<TrackSplit> splits) {
    splits.sort((a, b) => a.start.compareTo(b.start));
    for (var i = 0; i < splits.length; i++) {
      final s = splits[i];
      splits[i] = TrackSplit(
        number: i + 1,
        start: s.start,
        end: s.end,
        title: s.title,
      );
    }
  }

  void _deleteTrack(int index) {
    final currentPath = _files[_tabController.index];
    final splits = _fileSplits[currentPath];
    if (splits == null) return;

    setState(() {
      splits.removeAt(index);
      _sortAndRenumber(splits);
    });
  }

  void _updateTrackTitle(int index, String newTitle) {
    final currentPath = _files[_tabController.index];
    final splits = _fileSplits[currentPath];
    if (splits == null) return;

    final t = splits[index];
    splits[index] = TrackSplit(
      number: t.number,
      start: t.start,
      end: t.end,
      title: newTitle,
      artist: t.artist,
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String millis = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds.remainder(60))}.$millis';
  }

  @override
  Widget build(BuildContext context) {
    final processor = context.watch<ProcessingService>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentPath = _files.isNotEmpty ? _files[_tabController.index] : null;
    final splits = currentPath != null ? _fileSplits[currentPath] : null;
    final waveformPath = currentPath != null ? _waveforms[currentPath] : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor'),
        bottom: _files.length > 1
            ? TabBar(
                controller: _tabController,
                tabs: _files
                    .asMap()
                    .entries
                    .map(
                      (e) =>
                          Tab(text: 'Side ${String.fromCharCode(65 + e.key)}'),
                    )
                    .toList(),
              )
            : null,
      ),
      body: Column(
        children: [
          Container(
            height: 200,
            color: Colors.black,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_currentPosition),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      _formatDuration(_totalDuration),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => Stack(
                      alignment: Alignment.center,
                      children: [
                        if (waveformPath != null)
                          Positioned.fill(
                            child: Image.file(
                              File(waveformPath),
                              fit: BoxFit.fill,
                              color: colorScheme.primary.withValues(alpha: 0.5),
                              colorBlendMode: BlendMode.srcATop,
                            ),
                          ),
                        if (splits != null && _totalDuration.inMilliseconds > 0)
                          ...splits.map((track) {
                            final startPct =
                                track.start.inMilliseconds /
                                _totalDuration.inMilliseconds;
                            final endMs =
                                track.end?.inMilliseconds ??
                                _totalDuration.inMilliseconds;
                            final endPct =
                                endMs / _totalDuration.inMilliseconds;

                            return Positioned(
                              left: constraints.maxWidth * startPct,
                              width: constraints.maxWidth * (endPct - startPct),
                              top: 0,
                              bottom: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.secondary.withValues(
                                    alpha: 0.2,
                                  ),
                                  border: Border.all(
                                    color: colorScheme.secondary.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            trackShape: CustomTrackShape(),
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14,
                            ),
                            activeTrackColor: Colors.transparent,
                            inactiveTrackColor: Colors.transparent,
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: _currentPosition.inMilliseconds
                                .toDouble()
                                .clamp(
                                  0,
                                  _totalDuration.inMilliseconds.toDouble(),
                                ),
                            max: _totalDuration.inMilliseconds.toDouble(),
                            onChanged: (val) {
                              _player.seek(Duration(milliseconds: val.toInt()));
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.replay_5, color: Colors.white),
                      onPressed: () => _player.seek(
                        _currentPosition - const Duration(seconds: 5),
                      ),
                    ),
                    StreamBuilder<bool>(
                      stream: _player.stream.playing,
                      builder: (context, snapshot) {
                        final playing = snapshot.data ?? false;
                        return IconButton.filled(
                          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                          onPressed: () => _player.playOrPause(),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.forward_5, color: Colors.white),
                      onPressed: () => _player.seek(
                        _currentPosition + const Duration(seconds: 5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (processor.isProcessing)
            LinearProgressIndicator(value: processor.progress),
          Expanded(
            child: splits != null
                ? ListView.builder(
                    itemCount: splits.length,
                    itemBuilder: (context, index) {
                      final track = splits[index];
                      final isSelected =
                          (_currentPosition >= track.start) &&
                          (track.end == null || _currentPosition < track.end!);

                      return Card(
                        color: isSelected
                            ? colorScheme.primary.withValues(alpha: 0.1)
                            : null,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(child: Text('${track.number}')),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: track.title.isNotEmpty
                                          ? track.title
                                          : 'Track ${track.number}',
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      onChanged: (val) =>
                                          _updateTrackTitle(index, val),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete,
                                      color: colorScheme.error,
                                    ),
                                    onPressed: () => _deleteTrack(index),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _setStart(index),
                                      child: Text(
                                        'Start: ${_formatDuration(track.start)}',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _setEnd(index),
                                      child: Text(
                                        track.end == null
                                            ? 'End: (File End)'
                                            : 'End: ${_formatDuration(track.end!)}',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : const Center(child: Text('No tracks')),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: colorScheme.surfaceContainerHighest,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Region at Playhead'),
                  onPressed: _addRegion,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: processor.isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save_as),
                label: Text(
                  processor.isProcessing
                      ? 'Processing (Splitting WAV to FLAC)...'
                      : 'Confirm Regions & Process',
                ),
                onPressed: processor.isProcessing ? null : _showMetadataDialog,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight!;
    final double trackLeft = offset.dx;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
*/