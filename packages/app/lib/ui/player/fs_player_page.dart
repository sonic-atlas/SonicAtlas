import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/core/models/quality.dart';
import '../../core/services/network/api.dart';
import '../../core/services/playback/audio.dart';
import '../../core/services/config/settings.dart';
import 'queue_page.dart';
import 'package:sonic_audio/sonic_audio.dart';
import '../theme/app_theme.dart';

class FullScreenPlayerPage extends StatefulWidget {
  const FullScreenPlayerPage({super.key});

  @override
  State<FullScreenPlayerPage> createState() => _FullScreenPlayerPageState();
}

class _FullScreenPlayerPageState extends State<FullScreenPlayerPage> {
  Quality? _sourceQuality;
  List<Quality> _availableQualities = [];
  bool _loadingQuality = true;
  String? _lastTrackId;

  @override
  void initState() {
    super.initState();
    _loadAvailableQualities();
  }

  @override
  void didUpdateWidget(FullScreenPlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final audioService = context.read<AudioService>();
    final currentTrack = audioService.currentTrack;

    if (currentTrack != null && currentTrack.id != _lastTrackId) {
      _loadAvailableQualities();
    }
  }

  Future<void> _loadAvailableQualities() async {
    final audioService = context.read<AudioService>();
    final apiService = context.read<ApiService>();
    final track = audioService.currentTrack;

    if (track == null) return;

    setState(() {
      _loadingQuality = true;
      _lastTrackId = track.id;
    });

    try {
      final response = await apiService.getTrackQuality(track.id);

      if (mounted) {
        setState(() {
          _sourceQuality = response['sourceQuality'];
          _availableQualities = response['availableQualities'];
          _loadingQuality = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading quality info: $e');
      }
      if (mounted) {
        setState(() {
          _availableQualities = Quality.values.toList();
          _loadingQuality = false;
        });
      }
    }
  }

  bool _isQualityAvailable(Quality quality) {
    if (quality == Quality.auto) {
      return _availableQualities.isNotEmpty;
    }
    return _availableQualities.contains(quality);
  }

  void _showQualitySelector() {
    final settingsService = context.read<SettingsService>();
    final audioService = context.read<AudioService>();

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final selectedQuality = settingsService.audioQuality;
            final playingQuality = audioService.currentTrackQuality;

            final qualityChanged =
                playingQuality != null && playingQuality != selectedQuality;

            return SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Playback Quality',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (playingQuality != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Currently playing: ${playingQuality.label}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    RadioGroup<Quality>(
                      groupValue: selectedQuality,
                      onChanged: (value) {
                        if (value != null && _isQualityAvailable(value)) {
                          settingsService.setAudioQuality(value);
                          setModalState(() {});
                        } else {
                          null;
                        }
                      },
                      child: Column(
                        children: [
                          ...Quality.values.map((quality) {
                            final isAvailable = _isQualityAvailable(quality);
                            final isSource =
                                quality == _sourceQuality &&
                                quality != Quality.auto;
                            final isSelected = quality == selectedQuality;
                            final info = quality.info;

                            return ListTile(
                              enabled: isAvailable,
                              leading: Radio<Quality>(value: quality),
                              title: Row(
                                children: [
                                  Text(
                                    info.label,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : null,
                                      color: isAvailable
                                          ? (isSelected
                                                ? Theme.of(
                                                    context,
                                                  ).colorScheme.primary
                                                : null)
                                          : Theme.of(context).disabledColor,
                                    ),
                                  ),
                                  if (isSource) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Source',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                info.bitrate != null
                                    ? '${info.codec} • ${info.bitrate}'
                                    : info.sampleRate != null
                                    ? '${info.codec} • ${info.sampleRate}'
                                    : info.codec,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isAvailable
                                      ? Theme.of(
                                          context,
                                        ).textTheme.bodySmall?.color
                                      : Theme.of(context).disabledColor,
                                ),
                              ),
                              onTap: isAvailable
                                  ? () {
                                      settingsService.setAudioQuality(quality);
                                      setModalState(() {});
                                    }
                                  : null,
                            );
                          }),
                        ],
                      ),
                    ),

                    if (qualityChanged) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Quality setting changed to ${selectedQuality.label}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await audioService.restartCurrentTrack();
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                              icon: const Icon(Icons.restart_alt, size: 18),
                              label: const Text('Apply Now'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Or wait for the next track',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAudioSettings() {
    final audioService = context.read<AudioService>();

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return FutureBuilder<List<AudioDevice>>(
              future: audioService.getPlaybackDevices(),
              builder: (context, snapshot) {
                final devices = snapshot.data ?? [];

                return SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Audio Settings',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'Volume',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Consumer<AudioService>(
                          builder: (context, audio, child) {
                            return Row(
                              children: [
                                const Icon(Icons.volume_down, size: 20),
                                Expanded(
                                  child: Slider(
                                    value: audio.volume.clamp(0.0, 1.0),
                                    onChanged: (value) {
                                      audio.setVolume(value);
                                    },
                                  ),
                                ),
                                const Icon(Icons.volume_up, size: 20),
                              ],
                            );
                          },
                        ),

                        const Divider(height: 32),

                        Text(
                          'Output Device',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const Center(child: CircularProgressIndicator())
                        else if (devices.isEmpty)
                          const Text('No devices found')
                        else
                          RadioGroup<int>(
                            groupValue:
                                -1, // Current device not tracked so -1 for null
                            onChanged: (value) {
                              if (value != null) {
                                final device = devices.firstWhere(
                                  (d) => d.index == value,
                                );
                                audioService.setOutputDevice(device);
                                Navigator.pop(context);
                              }
                            },
                            child: Column(
                              children: devices.map((device) {
                                return RadioListTile<int>(
                                  title: Text(device.name),
                                  subtitle: Text(device.backend),
                                  value: device.index,
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioService = context.watch<AudioService>();
    final settingsService = context.watch<SettingsService>();
    final apiService = context.read<ApiService>();
    final track = audioService.currentTrack;

    if (track == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('No track selected')),
      );
    }

    final imageUrl = apiService.getAlbumArtUrl(track.id);
    final currentQuality = settingsService.audioQuality;
    final playingQuality = audioService.currentTrackQuality;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl,
            httpHeaders: apiService.headers,
            fit: BoxFit.cover,
            fadeInDuration: Duration.zero,
            errorWidget: (context, url, error) =>
                Container(color: Colors.black),
            placeholder: (context, url) => Container(color: Colors.black),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withValues(alpha: 0.5)),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useSideBySide =
                    constraints.maxWidth > constraints.maxHeight &&
                    constraints.maxHeight < 710;

                final maxSize = constraints.maxHeight * 0.45;
                final albumArtSize = useSideBySide
                    ? constraints.maxHeight * 0.7
                    : (constraints.maxWidth * 0.7).clamp(200.0, maxSize);

                final minimizeButton = IconButton(
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                );

                final qualityAndQueueButtons = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_loadingQuality)
                      OutlinedButton.icon(
                        onPressed: _showQualitySelector,
                        icon: const Icon(Icons.high_quality, size: 18),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currentQuality.label,
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (playingQuality != null &&
                                playingQuality != currentQuality)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.pending,
                                  size: 12,
                                  color: AppTheme.secondaryColor,
                                ),
                              ),
                          ],
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.queue_music, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const QueuePage(),
                          ),
                        );
                      },
                      tooltip: 'Queue',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.volume_up, color: Colors.white),
                      onPressed: _showAudioSettings,
                      tooltip: 'Audio Settings',
                    ),
                  ],
                );

                final albumArtWidget = Container(
                  width: albumArtSize,
                  height: albumArtSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      httpHeaders: apiService.headers,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      errorWidget: (context, url, error) {
                        return Container(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.music_note, size: 64),
                        );
                      },
                      placeholder: (context, url) => Container(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                );

                final trackInfoWidget = Column(
                  children: [
                    Text(
                      track.title,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      track.artist,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.releaseTitle ?? track.album,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );

                final progressBarWidget = StreamBuilder<Duration>(
                  stream: audioService.positionStream,
                  initialData: audioService.position,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration = audioService.duration;
                    return Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            if (audioService.isBuffering)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: const LinearProgressIndicator(
                                    minHeight: 4,
                                    backgroundColor: Colors.transparent,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white54,
                                    ),
                                  ),
                                ),
                              ),
                            Slider(
                              activeColor: AppTheme.primaryColor,
                              inactiveColor: Colors.white24,
                              thumbColor: AppTheme.primaryColor,
                              value: position.inMilliseconds
                                  .clamp(0, duration.inMilliseconds)
                                  .toDouble(),
                              min: 0,
                              max: duration.inMilliseconds.toDouble(),
                              onChanged: (value) {
                                audioService.seek(
                                  Duration(milliseconds: value.round()),
                                );
                              },
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(position),
                                style: const TextStyle(color: Colors.white),
                              ),
                              GestureDetector(
                                onTap: () {
                                  settingsService.setRelativeDuration(
                                    !settingsService.relativeDuration,
                                  );
                                },
                                child: Text(
                                  settingsService.relativeDuration
                                      ? '-${_formatDuration(duration - position)}'
                                      : _formatDuration(duration),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );

                final controlsWidget = Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.skip_previous,
                        color: audioService.hasPrevious
                            ? Colors.white
                            : Colors.white38,
                      ),
                      iconSize: 40,
                      onPressed: audioService.hasPrevious
                          ? () => audioService.skipPrevious()
                          : null,
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      icon: Icon(
                        audioService.isPlaying
                            ? Icons.pause_circle
                            : Icons.play_circle,
                        color: Colors.white,
                      ),
                      iconSize: 64,
                      onPressed: audioService.isPlaying
                          ? audioService.pause
                          : audioService.play,
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      icon: Icon(
                        Icons.skip_next,
                        color: audioService.hasNext
                            ? Colors.white
                            : Colors.white38,
                      ),
                      iconSize: 40,
                      onPressed: audioService.hasNext
                          ? () => audioService.skipNext()
                          : null,
                    ),
                  ],
                );

                if (useSideBySide) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              minimizeButton,
                              Expanded(child: Center(child: albumArtWidget)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          child: Column(
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: qualityAndQueueButtons,
                              ),
                              Expanded(
                                child: Center(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        trackInfoWidget,
                                        const SizedBox(height: 24),
                                        progressBarWidget,
                                        const SizedBox(height: 16),
                                        controlsWidget,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          minimizeButton,
                          const Spacer(),
                          qualityAndQueueButtons,
                        ],
                      ),
                      const Spacer(),
                      albumArtWidget,
                      const Spacer(),
                      trackInfoWidget,
                      const SizedBox(height: 24),
                      progressBarWidget,
                      const SizedBox(height: 16),
                      controlsWidget,
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
