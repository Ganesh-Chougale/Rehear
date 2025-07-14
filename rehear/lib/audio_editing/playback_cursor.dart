import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_playback_service.dart';
import '../providers/audio_playback_provider.dart'; // Import the provider itself

class PlaybackCursor extends ConsumerStatefulWidget {
  final double waveformWidth;
  final double waveformHeight; // Total height of the waveform area (tracks + ruler)
  final double visualScale; // Pixels per second
  final Function(Duration) onSeek;

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
  Duration _currentPlaybackPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Corrected: Access via ref.read
    ref.read(audioPlaybackServiceProvider).positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _currentPlaybackPosition = position;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calculate cursor's X position based on current playback position and visual scale
    final double cursorX = _currentPlaybackPosition.inMilliseconds / 1000.0 * widget.visualScale;

    // Clamp cursorX to ensure it stays within the waveform bounds
    final double clampedCursorX = cursorX.clamp(0.0, widget.waveformWidth);

    return Positioned(
      left: clampedCursorX,
      top: 0,
      bottom: 0,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          final double newX = clampedCursorX + details.primaryDelta!;
          final double newPositionSeconds = newX / widget.visualScale;
          final newDuration = Duration(milliseconds: (newPositionSeconds * 1000).round());
          widget.onSeek(newDuration);
        },
        child: Container(
          width: 2.0, // Cursor line thickness
          height: widget.waveformHeight, // Cursor spans the entire height
          color: Colors.red, // Cursor color
        ),
      ),
    );
  }
}