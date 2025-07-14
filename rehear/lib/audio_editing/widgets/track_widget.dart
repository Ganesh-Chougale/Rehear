import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/audio_clip.dart';
import '../../models/audio_track.dart';
import 'draggable_clip.dart';

class TrackWidget extends ConsumerWidget {
  final AudioTrack track;
  final double pixelsPerSecond;
  final double trackHeight;
  final Function(AudioClip)? onClipTap;
  final Function(AudioClip, String, Duration)? onClipMoved;
  final Function(AudioClip, String, String)? onClipDroppedOnTrack;

  const TrackWidget({
    super.key,
    required this.track,
    required this.pixelsPerSecond,
    this.trackHeight = 100.0,
    this.onClipTap,
    this.onClipMoved,
    this.onClipDroppedOnTrack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: trackHeight,
      child: TrackDropTarget(
        trackId: track.id,
        trackHeight: trackHeight,
        onDrop: onClipDroppedOnTrack,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Track controls
            Container(
              width: 80,
              color: Colors.grey[800],
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    track.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Mute button
                      IconButton(
                        icon: Icon(
                          track.isMuted ? Icons.volume_off : Icons.volume_up,
                          size: 16,
                          color: track.isMuted ? Colors.red : Colors.white70,
                        ),
                        onPressed: () {
                          // Toggle mute state
                          // You'll need to implement this in your state management
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: track.isMuted ? 'Unmute track' : 'Mute track',
                      ),
                      // Solo button
                      IconButton(
                        icon: Icon(
                          Icons.hearing,
                          size: 16,
                          color: track.isSoloed ? Colors.blue : Colors.white70,
                        ),
                        onPressed: () {
                          // Toggle solo state
                          // You'll need to implement this in your state management
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: track.isSoloed ? 'Unsolo track' : 'Solo track',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Track content (clips)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[700]!),
                  ),
                ),
                child: Stack(
                  children: [
                    // Background
                    Container(color: Colors.grey[900]),
                    // Clips
                    ...track.clips.map((clip) {
                      return _buildClipWidget(context, clip);
                    }).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClipWidget(BuildContext context, AudioClip clip) {
    final clipWidth = (clip.duration.inMilliseconds / 1000.0) * pixelsPerSecond;
    final clipLeft = (clip.startTime.inMilliseconds / 1000.0) * pixelsPerSecond;

    return Positioned(
      left: clipLeft,
      top: 2,
      bottom: 2,
      width: clipWidth,
      child: DraggableClip(
        clip: clip,
        trackId: track.id,
        pixelsPerSecond: pixelsPerSecond,
        onDragStarted: () {
          // Handle drag start if needed
        },
        onDragUpdate: (localPosition) {
          // Handle drag update if needed
        },
        onDragEnd: (accepted) {
          // Handle drag end if needed
        },
        child: GestureDetector(
          onTap: () => onClipTap?.call(clip),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4.0),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
              decoration: BoxDecoration(
                color: _getClipColor(clip.name),
                borderRadius: BorderRadius.circular(4.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 2.0,
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Clip content (waveform, name, etc.)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(
                        clip.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  // Mute indicator
                  if (clip.isMuted)
                    const Positioned(
                      top: 2,
                      right: 2,
                      child: Icon(
                        Icons.volume_off,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to generate a consistent color based on clip name
  Color _getClipColor(String name) {
    final colors = [
      Colors.blue[700]!,
      Colors.green[700]!,
      Colors.orange[700]!,
      Colors.purple[700]!,
      Colors.teal[700]!,
      Colors.pink[700]!,
      Colors.indigo[700]!,
      Colors.cyan[700]!,
      Colors.amber[700]!,
      Colors.deepPurple[700]!,
    ];
    
    // Simple hash to get a consistent color for the same name
    final hash = name.codeUnits.fold(0, (int prev, int curr) => prev + curr);
    return colors[hash % colors.length];
  }
}
