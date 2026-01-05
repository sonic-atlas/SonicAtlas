import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sonic_recorder/sonic_recorder.dart';
import '/core/services/recorder/recorder_service.dart';
import 'components/device_selector.dart';
import 'components/vu_meter.dart';
import 'components/recording_status.dart';

class RecordingPage extends StatelessWidget {
  const RecordingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Recording'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.mic), text: 'Analog'),
              Tab(icon: Icon(Icons.album), text: 'CD Ripping'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AnalogTab(),
            Center(child: Text('CD Ripping (Coming Soon)')),
          ],
        ),
      ),
    );
  }
}

class _AnalogTab extends StatefulWidget {
  const _AnalogTab();

  @override
  State<_AnalogTab> createState() => _AnalogTabState();
}

class _AnalogTabState extends State<_AnalogTab> {
  AudioDevice? _selectedDevice;
  int _sampleRate = 48000;

  late final SonicRecorderService _recorderService;

  @override
  void initState() {
    super.initState();
    _recorderService = context.read<SonicRecorderService>();
  }

  @override
  void dispose() {
    _recorderService.stopMonitor();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recorderService = context.watch<SonicRecorderService>();

    if (_selectedDevice == null && recorderService.devices.isNotEmpty) {
      _selectedDevice = recorderService.devices.first;
    }

    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Opacity(
                  opacity: recorderService.isRecording ? 0.5 : 1.0,
                  child: IgnorePointer(
                    ignoring: recorderService.isRecording,
                    child: DeviceSelector(
                      selectedDevice: _selectedDevice,
                      onDeviceChanged: (d) =>
                          setState(() => _selectedDevice = d),
                      sampleRate: _sampleRate,
                      onSampleRateChanged: (sr) =>
                          setState(() => _sampleRate = sr ?? 48000),
                      bitDepth: recorderService.bitDepth,
                      onBitDepthChanged: (bd) {
                        if (bd != null) recorderService.setBitDepth(bd);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                const Spacer(),

                VUMeter(
                  stream: recorderService.volumeStream,
                ),

                const SizedBox(height: 20),

                Center(
                  child: Column(
                    children: [
                      const RecordingStatus(),

                      if (!recorderService.isRecording)
                        Padding(
                          padding: EdgeInsets.only(bottom: 24.0),
                          child: Text(
                            'Record the entire side or album as one continuous track.\nYou can stop recording when switching sides; multiple recordings will be grouped into a session.\nYou can split tracks and remove silence in the editor after recording.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ),

                      const SizedBox(height: 16),

                      ElevatedButton.icon(
                        icon: Icon(
                          recorderService.isRecording
                              ? Icons.stop
                              : Icons.fiber_manual_record,
                          color: recorderService.isRecording
                              ? Colors.grey
                              : Colors.red,
                        ),
                        label: Text(
                          recorderService.isRecording
                              ? 'STOP RECORDING'
                              : 'START RECORDING',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 24,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          backgroundColor: recorderService.isRecording
                              ? Colors.red.shade900
                              : null,
                          foregroundColor: recorderService.isRecording
                              ? Colors.white
                              : null,
                        ),
                        onPressed: () {
                          if (recorderService.isRecording) {
                            recorderService.stopRecording();
                          } else {
                            if (_selectedDevice != null) {
                              recorderService.startRecording(
                                _selectedDevice!,
                                sampleRate: _sampleRate,
                              );
                            }
                          }
                        },
                      ),

                      if (!recorderService.isRecording &&
                          recorderService.sessionFiles.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Session: ${recorderService.sessionFiles.length} file(s) recorded',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.delete_sweep),
                                    label: const Text('Clear Session'),
                                    onPressed: () {
                                      recorderService.clearSession();
                                    },
                                  ),
                                  const SizedBox(width: 16),
                                  FilledButton.icon(
                                    icon: const Icon(Icons.content_cut),
                                    label: const Text('Open Editor & Process'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.amber.shade800,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 16,
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/editor');
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
