import 'dart:math' as math;
import 'package:flutter/material.dart';

class VUMeter extends StatelessWidget {
  final Stream<double> stream;

  const VUMeter({super.key, required this.stream});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(4),
      child: StreamBuilder<double>(
        stream: stream,
        initialData: 0.0,
        builder: (context, snapshot) {
          final rms = snapshot.data ?? 0.0;
          final db = (rms < 0.00001)
              ? -100.0
              : 20 * (math.log(rms) / math.ln10);

          double percent = (db + 60.0) / 60.0;
          if (percent < 0) percent = 0;
          if (percent > 1) percent = 1;

          return CustomPaint(
            painter: _VUPainter(percent, db, context),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _VUPainter extends CustomPainter {
  final double percent;
  final double currentDb;
  final BuildContext context;

  _VUPainter(this.percent, this.currentDb, this.context);

  @override
  void paint(Canvas canvas, Size size) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final width = size.width;
    final height = size.height;
    final barHeight = height * 0.7;

    final totalSegments = 40;
    final segmentWidth = (width / totalSegments) - 1;
    final activeSegments = (percent * totalSegments).round();

    for (var i = 0; i < totalSegments; i++) {
      final x = i * (segmentWidth + 1);
      Color color = colorScheme.outlineVariant;

      if (i < activeSegments) {
        final p = i / totalSegments;
        if (p < 0.6) {
          color = Colors.green;
        } else if (p < 0.85) {
          color = Colors.orange;
        } else {
          color = Colors.red;
        }
      }

      canvas.drawRect(
        Rect.fromLTWH(x, 0, segmentWidth, barHeight),
        Paint()..color = color,
      );
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final labels = [-40, -20, -6, 0];
    for (final dbVal in labels) {
      final p = (dbVal + 60.0) / 60.0;
      if (p < 0) continue;
      final lx = p * width;

      textPainter.text = TextSpan(
        text: '$dbVal',
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(lx - (textPainter.width / 2), barHeight + 2),
      );
    }

    final displayDb = currentDb.clamp(-100.0, 0.0);
    final validDisplay = displayDb <= -100
        ? '-∞'
        : displayDb.toStringAsFixed(1);

    textPainter.text = TextSpan(
      text: '$validDisplay dB',
      style: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(width - textPainter.width - 4, barHeight + 2),
    );
  }

  @override
  bool shouldRepaint(covariant _VUPainter oldDelegate) =>
      oldDelegate.percent != percent || 
      oldDelegate.currentDb != currentDb ||
      oldDelegate.context != context;
}
