// lib/audio_editing/time_ruler.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_playback_provider.dart'; // To get total duration if not already passed

class TimeRuler extends ConsumerWidget {
  final double waveformWidth; // The total width of the waveform (e.g., MediaQuery.of(context).size.width * 2)
  final Duration totalDuration; // The total duration of the audio file

  const TimeRuler({
    super.key,
    required this.waveformWidth,
    required this.totalDuration,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // You might get the total duration from your AudioPlaybackService if it's dynamic
    // For now, we're assuming it's passed as a required parameter.
    // final totalDuration = ref.watch(audioPlaybackServiceProvider.select((service) => service.totalDuration)) ?? Duration.zero;

    return Container(
      height: 30, // Fixed height for the ruler
      width: waveformWidth, // Match the width of the waveform
      color: Colors.grey[900], // Dark background for contrast
      child: CustomPaint(
        painter: _TimeRulerPainter(
          totalDuration: totalDuration,
          waveformWidth: waveformWidth,
          context: context, // Pass context for text styles
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
    const double textOffset = 15.0; // Offset for text below the ruler line

    // Calculate major interval (e.g., every 10 seconds)
    final int totalSeconds = totalDuration.inSeconds;
    final double pixelsPerSecond = waveformWidth / totalSeconds;

    // We'll draw markers at a fixed interval (e.g., every 5 or 10 seconds)
    // Adjust `intervalSeconds` based on the overall duration for better readability.
    int intervalSeconds = 10;
    if (totalSeconds > 120) { // If audio is longer than 2 minutes, use 30s intervals
      intervalSeconds = 30;
    } else if (totalSeconds > 60) { // If audio is longer than 1 minute, use 15s intervals
      intervalSeconds = 15;
    } else if (totalSeconds < 30) { // For very short audios, use 5s intervals
      intervalSeconds = 5;
    }

    for (int i = 0; i <= totalSeconds; i++) {
      final double x = i * pixelsPerSecond;

      if (i % intervalSeconds == 0) {
        // Major markers with text
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
          Offset(x - textPainter.width / 2, markerHeightLong + 2), // Position text below marker
        );
      } else if (i % (intervalSeconds ~/ 2) == 0 && intervalSeconds > 5) {
        // Minor markers (half of major interval, if major is large enough)
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
    // Include hours only if necessary
    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  bool shouldRepaint(covariant _TimeRulerPainter oldDelegate) {
    // Repaint only if total duration or waveform width changes
    return oldDelegate.totalDuration != totalDuration ||
        oldDelegate.waveformWidth != waveformWidth;
  }
}