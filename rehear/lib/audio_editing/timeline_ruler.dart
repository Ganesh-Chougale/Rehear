// lib/audio_editing/time_ruler.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_playback_provider.dart';

class TimeRuler extends ConsumerWidget {
  static const double rulerHeight = 30.0; // Make height a constant

  final double waveformWidth;
  final Duration totalDuration;

  const TimeRuler({
    super.key,
    required this.waveformWidth,
    required this.totalDuration,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: rulerHeight, // Use the constant
      width: waveformWidth,
      color: Colors.grey[900],
      child: CustomPaint(
        painter: _TimeRulerPainter(
          totalDuration: totalDuration,
          waveformWidth: waveformWidth,
          context: context,
        ),
      ),
    );
  }
}

class _TimeRulerPainter extends CustomPainter {
  final Duration totalDuration;
  final double waveformWidth;
  final BuildContext context;

  _TimeRulerPainter({
    required this.totalDuration,
    required this.waveformWidth,
    required this.context,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0;

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    const double markerHeightLong = 10.0;
    const double markerHeightShort = 5.0;
    // const double textOffset = 15.0; // This was not used, can remove or use if needed

    final int totalSeconds = totalDuration.inSeconds;
    final double pixelsPerSecond = waveformWidth / (totalSeconds > 0 ? totalSeconds : 1); // Avoid division by zero

    int intervalSeconds = 10;
    if (totalSeconds > 300) { // 5 minutes
      intervalSeconds = 60;
    } else if (totalSeconds > 120) { // 2 minutes
      intervalSeconds = 30;
    } else if (totalSeconds > 60) { // 1 minute
      intervalSeconds = 15;
    } else if (totalSeconds < 30) {
      intervalSeconds = 5;
    }

    // Draw markers and text
    for (int i = 0; i <= totalSeconds; i++) {
      final double x = i * pixelsPerSecond;

      if (i % intervalSeconds == 0) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, markerHeightLong),
          linePaint,
        );

        final String timeText = _formatDuration(Duration(seconds: i));
        textPainter.text = TextSpan(
          text: timeText,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white, fontSize: 10),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, markerHeightLong + 2),
        );
      } else if (i % (intervalSeconds ~/ 2) == 0 && intervalSeconds > 5) { // Half-interval markers for larger intervals
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, markerHeightShort),
          linePaint,
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  bool shouldRepaint(covariant _TimeRulerPainter oldDelegate) {
    return oldDelegate.totalDuration != totalDuration ||
           oldDelegate.waveformWidth != waveformWidth;
  }
}