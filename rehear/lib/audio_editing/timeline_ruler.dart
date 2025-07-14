// lib/audio_editing/time_ruler.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_playback_provider.dart';

class TimeRuler extends ConsumerWidget {
  static const double rulerHeight = 30.0;
  final double waveformWidth;
  final Duration totalDuration;
  final double pixelsPerSecond;

  const TimeRuler({
    super.key,
    required this.waveformWidth,
    required this.totalDuration,
    this.pixelsPerSecond = 200.0, // Default scale: 200 pixels per second
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalSeconds = totalDuration.inSeconds.toDouble();
    final visibleDuration = (MediaQuery.of(context).size.width / pixelsPerSecond).ceil();
    
    // Calculate major and minor tick intervals based on zoom level
    final double secondsPerScreen = waveformWidth / pixelsPerSecond;
    double majorTickInterval = _calculateMajorTickInterval(secondsPerScreen);
    double minorTickInterval = majorTickInterval / 5;

    // Generate tick positions
    final ticks = <double>[];
    final majorTicks = <double, String>{};
    
    for (double i = 0; i <= totalSeconds; i += minorTickInterval) {
      final position = i * pixelsPerSecond;
      if (position > waveformWidth) break;
      
      ticks.add(position);
      
      // Add label for major ticks
      if (i % majorTickInterval == 0) {
        majorTicks[position] = _formatTime(Duration(seconds: i.toInt()));
      }
    }

    return Container(
      height: rulerHeight,
      width: waveformWidth,
      color: Colors.grey[900],
      child: CustomPaint(
        size: Size(waveformWidth, rulerHeight),
        painter: _TimeRulerPainter(
          ticks: ticks,
          majorTicks: majorTicks,
          pixelsPerSecond: pixelsPerSecond,
        ),
      ),
    );
  }

  // Calculate appropriate major tick interval based on zoom level
  double _calculateMajorTickInterval(double secondsPerScreen) {
    if (secondsPerScreen <= 5) return 1.0;      // 1 second intervals
    if (secondsPerScreen <= 15) return 2.0;     // 2 seconds
    if (secondsPerScreen <= 30) return 5.0;     // 5 seconds
    if (secondsPerScreen <= 60) return 10.0;    // 10 seconds
    if (secondsPerScreen <= 180) return 30.0;   // 30 seconds
    if (secondsPerScreen <= 300) return 60.0;   // 1 minute
    if (secondsPerScreen <= 600) return 120.0;  // 2 minutes
    return 300.0; // 5 minutes
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '$minutes:${twoDigits(seconds)}';
    }
  }
}

class _TimeRulerPainter extends CustomPainter {
  final List<double> ticks;
  final Map<double, String> majorTicks;
  final double pixelsPerSecond;

  _TimeRulerPainter({
    required this.ticks,
    required this.majorTicks,
    required this.pixelsPerSecond,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[600]!
      ..strokeWidth = 1.0;

    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 10.0,
    );

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Draw minor ticks
    for (final position in ticks) {
      final isMajorTick = majorTicks.containsKey(position);
      final tickHeight = isMajorTick ? 15.0 : 8.0;
      
      canvas.drawLine(
        Offset(position, TimeRuler.rulerHeight - tickHeight),
        Offset(position, TimeRuler.rulerHeight),
        paint..strokeWidth = isMajorTick ? 1.5 : 1.0,
      );

      // Draw time labels for major ticks
      if (isMajorTick) {
        final textSpan = TextSpan(
          text: majorTicks[position],
          style: textStyle,
        );
        
        textPainter.text = textSpan;
        textPainter.layout(
          minWidth: 0,
          maxWidth: 100,
        );

        final textX = position - (textPainter.width / 2);
        final textY = TimeRuler.rulerHeight - tickHeight - textPainter.height - 2;
        
        textPainter.paint(
          canvas,
          Offset(
            textX.clamp(0, size.width - textPainter.width),
            textY,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TimeRulerPainter oldDelegate) {
    return oldDelegate.ticks != ticks || 
           oldDelegate.majorTicks != majorTicks ||
           oldDelegate.pixelsPerSecond != pixelsPerSecond;
  }
}