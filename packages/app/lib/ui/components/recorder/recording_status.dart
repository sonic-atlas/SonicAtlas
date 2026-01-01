import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/recorder/recorder_service.dart';

class RecordingStatus extends StatelessWidget {
  const RecordingStatus({super.key});

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '${twoDigits(d.inHours)}:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final recorderService = context.watch<SonicRecorderService>();

    if (!recorderService.isRecording) return const SizedBox.shrink();

    return Column(
      children: [
        Text(
          _formatDuration(recorderService.recordDuration),
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Recording in progress...',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        const Text(
          'You can edit tracks and remove silence after recording is finished.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
        const Text(
          'You should stop recording when switching sides/tracks.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
