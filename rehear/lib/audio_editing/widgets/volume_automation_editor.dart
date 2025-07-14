import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/audio_clip.dart';

class VolumePoint {
  final Duration time;
  final double volume; // 0.0 to 1.0

  const VolumePoint({
    required this.time,
    required this.volume,
  });

  VolumePoint copyWith({
    Duration? time,
    double? volume,
  }) {
    return VolumePoint(
      time: time ?? this.time,
      volume: volume ?? this.volume,
    );
  }
}

class VolumeAutomationEditor extends StatefulWidget {
  final AudioClip clip;
  final double width;
  final double height;
  final ValueChanged<List<VolumePoint>> onPointsChanged;

  const VolumeAutomationEditor({
    super.key,
    required this.clip,
    required this.width,
    required this.height,
    required this.onPointsChanged,
  });

  @override
  State<VolumeAutomationEditor> createState() => _VolumeAutomationEditorState();
}

class _VolumeAutomationEditorState extends State<VolumeAutomationEditor> {
  List<VolumePoint> _points = [];
  VolumePoint? _activePoint;
  bool _isDragging = false;
  late double _pixelsPerSecond;

  @override
  void initState() {
    super.initState();
    _pixelsPerSecond = widget.width / widget.clip.duration.inSeconds;
    _initializePoints();
  }

  void _initializePoints() {
    // Start with default points if none exist
    _points = [
      VolumePoint(time: Duration.zero, volume: 1.0),
      VolumePoint(time: widget.clip.duration, volume: 1.0),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      onTapDown: _handleTapDown,
      onDoubleTap: _handleDoubleTap,
      child: CustomPaint(
        size: Size(widget.width, widget.height),
        painter: _VolumeAutomationPainter(
          points: _points,
          activePoint: _activePoint,
          duration: widget.clip.duration,
          pixelsPerSecond: _pixelsPerSecond,
        ),
      ),
    );
  }

  void _handlePanStart(DragStartDetails details) {
    final position = details.localPosition;
    _activePoint = _findNearestPoint(position);
    _isDragging = _activePoint != null;
    setState(() {});
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isDragging || _activePoint == null) return;

    final position = details.localPosition;
    final time = Duration(
      milliseconds: (position.dx / _pixelsPerSecond * 1000).round(),
    ).clamp(Duration.zero, widget.clip.duration);

    final volume = (1.0 - (position.dy / widget.height)).clamp(0.0, 1.0);

    setState(() {
      final index = _points.indexOf(_activePoint!);
      if (index != -1) {
        _points[index] = _activePoint!.copyWith(
          time: time,
          volume: volume,
        );
        _activePoint = _points[index];
      }
    });
  }

  void _handlePanEnd(DragEndDetails _) {
    _isDragging = false;
    widget.onPointsChanged(_points);
  }

  void _handleTapDown(TapDownDetails details) {
    final position = details.localPosition;
    final time = Duration(
      milliseconds: (position.dx / _pixelsPerSecond * 1000).round(),
    ).clamp(Duration.zero, widget.clip.duration);

    final volume = (1.0 - (position.dy / widget.height)).clamp(0.0, 1.0);

    setState(() {
      _points.add(VolumePoint(time: time, volume: volume));
      _points.sort((a, b) => a.time.compareTo(b.time));
      _activePoint = _points.firstWhere((p) => p.time == time);
    });
    
    widget.onPointsChanged(_points);
  }

  void _handleDoubleTap() {
    if (_activePoint != null && _points.length > 2) {
      setState(() {
        _points.remove(_activePoint);
        _activePoint = null;
      });
      widget.onPointsChanged(_points);
    }
  }

  VolumePoint? _findNearestPoint(Offset position) {
    if (_points.isEmpty) return null;

    const threshold = 20.0; // pixels
    VolumePoint? nearestPoint;
    double? nearestDistance;

    for (final point in _points) {
      final pointX = point.time.inMilliseconds * _pixelsPerSecond / 1000;
      final pointY = (1.0 - point.volume) * widget.height;
      
      final distance = (position - Offset(pointX, pointY)).distance;
      
      if (distance < threshold && (nearestDistance == null || distance < nearestDistance)) {
        nearestDistance = distance;
        nearestPoint = point;
      }
    }

    return nearestPoint;
  }
}

class _VolumeAutomationPainter extends CustomPainter {
  final List<VolumePoint> points;
  final VolumePoint? activePoint;
  final Duration duration;
  final double pixelsPerSecond;

  const _VolumeAutomationPainter({
    required this.points,
    required this.activePoint,
    required this.duration,
    required this.pixelsPerSecond,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = Colors.blue.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    // Sort points by time
    final sortedPoints = List<VolumePoint>.from(points)..sort((a, b) => a.time.compareTo(b.time));

    // Draw the line and fill
    for (var i = 0; i < sortedPoints.length; i++) {
      final point = sortedPoints[i];
      final x = point.time.inMilliseconds * pixelsPerSecond / 1000;
      final y = (1.0 - point.volume) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      // Draw points
      final isActive = point == activePoint;
      canvas.drawCircle(
        Offset(x, y),
        isActive ? 6.0 : 4.0,
        Paint()
          ..color = isActive ? Colors.blue : Colors.white
          ..strokeWidth = 2.0
          ..style = isActive ? PaintingStyle.fill : PaintingStyle.stroke,
      );
    }

    // Complete the fill path
    if (sortedPoints.isNotEmpty) {
      final lastPoint = sortedPoints.last;
      final lastX = lastPoint.time.inMilliseconds * pixelsPerSecond / 1000;
      fillPath.lineTo(lastX, size.height);
      fillPath.close();
    }

    // Draw the fill
    canvas.drawPath(fillPath, fillPaint);
    // Draw the line
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_VolumeAutomationPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.activePoint != activePoint;
  }
}
