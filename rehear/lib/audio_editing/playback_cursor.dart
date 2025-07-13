// lib/audio_editing/playback_cursor.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_playback_service.dart'; // To get playback position

class PlaybackCursor extends ConsumerStatefulWidget {
  final double waveformWidth; // The total width of the waveform/ruler
  final double waveformHeight; // The height of the waveform area
  final double visualScale; // Pixels per second
  final Function(Duration) onSeek; // Callback when the cursor is dragged to a new position

  const PlaybackCursor({
    super.key,
    required this.waveformWidth,
    required this.waveformHeight,
    required this.visualScale,
    required this.onSeek,
  });

  @override
  ConsumerState<PlaybackCursor> createState() => _PlaybackCursorState();
}

class _PlaybackCursorState extends ConsumerState<PlaybackCursor> {
  double _currentCursorX = 0.0; // Current X position of the cursor in pixels
  bool _isDragging = false; // To prevent auto-updates while dragging

  @override
  void initState() {
    super.initState();
    // Listen to the playback position from the audio service
    ref.read(audioPlaybackServiceProvider).positionStream.listen((position) {
      if (!_isDragging) {
        _updateCursorPosition(position);
      }
    });
  }

  void _updateCursorPosition(Duration position) {
    // Convert duration to pixel position
    final double newX = (position.inMilliseconds / 1000.0) * widget.visualScale;
    // Ensure the cursor doesn't go beyond the bounds
    final clampedX = newX.clamp(0.0, widget.waveformWidth);
    if (_currentCursorX != clampedX) {
      setState(() {
        _currentCursorX = clampedX;
      });
    }
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _isDragging = true;
      // Update cursor position based on drag delta
      _currentCursorX = (_currentCursorX + details.delta.dx)
          .clamp(0.0, widget.waveformWidth); // Clamp within bounds
    });
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    _isDragging = false;
    // Convert pixel position back to duration and notify parent
    final double positionInSeconds = _currentCursorX / widget.visualScale;
    widget.onSeek(Duration(milliseconds: (positionInSeconds * 1000).round()));
    print('PlaybackCursor: Drag ended, seeking to ${Duration(milliseconds: (positionInSeconds * 1000).round())}');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _handleHorizontalDragUpdate,
      onHorizontalDragEnd: _handleHorizontalDragEnd,
      child: Container(
        width: widget.waveformWidth,
        height: widget.waveformHeight,
        color: Colors.transparent, // Make container invisible but tappable
        child: CustomPaint(
          painter: _CursorPainter(_currentCursorX),
        ),
      ),
    );
  }
}

class _CursorPainter extends CustomPainter {
  final double cursorX;

  _CursorPainter(this.cursorX);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.red // Red color for the cursor
      ..strokeWidth = 2.0; // Thicker line

    // Draw a vertical line from top to bottom of the available size
    canvas.drawLine(
      Offset(cursorX, 0),
      Offset(cursorX, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CursorPainter oldDelegate) {
    // Only repaint if the cursor's X position changes
    return oldDelegate.cursorX != cursorX;
  }
}