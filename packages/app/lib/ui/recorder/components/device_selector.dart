/*import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sonic_recorder/sonic_recorder.dart';
import '../../../../core/services/recorder/recorder_service.dart';

class DeviceSelector extends StatelessWidget {
  final AudioDevice? selectedDevice;
  final ValueChanged<AudioDevice?> onDeviceChanged;
  final int sampleRate;
  final ValueChanged<int?> onSampleRateChanged;
  final RecordingBitDepth bitDepth;
  final ValueChanged<RecordingBitDepth?> onBitDepthChanged;

  const DeviceSelector({
    super.key,
    required this.selectedDevice,
    required this.onDeviceChanged,
    required this.sampleRate,
    required this.onSampleRateChanged,
    required this.bitDepth,
    required this.onBitDepthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final recorderService = context.watch<SonicRecorderService>();
    final sampleRates = [44100, 48000, 88200, 96000, 176400, 192000];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Input Device',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<AudioDevice>(
                    isExpanded: true,
                    items: recorderService.devices.map((d) {
                      return DropdownMenuItem(
                        value: d,
                        child: Text(
                          d.toString(),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: recorderService.isRecording
                        ? null
                        : onDeviceChanged,
                    hint: const Text('Select a device'),
                    value: selectedDevice,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: recorderService.isRecording
                  ? null
                  : () => recorderService.refreshDevices(),
              tooltip: 'Refresh Devices',
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              icon: Icon(
                recorderService.isMonitoring
                    ? Icons.volume_up
                    : Icons.volume_off,
              ),
              onPressed: () =>
                  recorderService.toggleMonitor(sampleRate: sampleRate),
              tooltip: 'Monitor Output',
              style: IconButton.styleFrom(
                backgroundColor: recorderService.isMonitoring
                    ? Theme.of(context).colorScheme.primary
                    : null,
                foregroundColor: recorderService.isMonitoring
                    ? Theme.of(context).colorScheme.onPrimary
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sample Rate',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        items: sampleRates.map((sr) {
                          return DropdownMenuItem(
                            value: sr,
                            child: Text('${sr}Hz'),
                          );
                        }).toList(),
                        onChanged: recorderService.isRecording
                            ? null
                            : onSampleRateChanged,
                        value: sampleRate,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bit Depth',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<RecordingBitDepth>(
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: RecordingBitDepth.int16,
                            child: Text('16-bit (CD)'),
                          ),
                          DropdownMenuItem(
                            value: RecordingBitDepth.int24,
                            child: Text('24-bit (Hi-Res)'),
                          ),
                          DropdownMenuItem(
                            value: RecordingBitDepth.int32,
                            child: Text('32-bit (Studio)'),
                          ),
                        ],
                        onChanged: recorderService.isRecording
                            ? null
                            : onBitDepthChanged,
                        value: bitDepth,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
*/