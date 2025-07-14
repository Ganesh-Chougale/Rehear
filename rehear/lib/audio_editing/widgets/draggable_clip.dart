import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/audio_clip.dart';
import '../../models/audio_track.dart';

class DraggableClip extends StatelessWidget {
  final AudioClip clip;
  final String trackId;
  final double pixelsPerSecond;
  final VoidCallback? onDragStarted;
  final Function(Offset localPosition)? onDragUpdate;
  final Function(bool accepted)? onDragEnd;
  final Widget child;

  const DraggableClip({
    super.key,
    required this.clip,
    required this.trackId,
    required this.pixelsPerSecond,
    this.onDragStarted,
    this.onDragUpdate,
    this.onDragEnd,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<Map<String, dynamic>>(
      // Data to be transferred when the drag is completed
      data: {
        'clip': clip,
        'sourceTrackId': trackId,
      },
      // Feedback is what's shown under the user's finger during drag
      feedback: Material(
        elevation: 4.0,
        child: Opacity(
          opacity: 0.8,
          child: Container(
            width: (clip.duration.inMilliseconds / 1000.0) * pixelsPerSecond,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.7),
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(color: Colors.white24, width: 1.0),
            ),
            child: Center(
              child: Text(
                clip.name,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
      // What's shown at the original position during drag
      childWhenDragging: Container(
        decoration: BoxDecoration(
          color: Colors.grey[800]!.withOpacity(0.5),
          border: Border.all(color: Colors.grey[600]!, width: 1.0, style: BorderStyle.dashed),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Center(
          child: Text(
            clip.name,
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      // The original widget when not being dragged
      onDragStarted: () {
        onDragStarted?.call();
      },
      onDragUpdate: (details) {
        if (onDragUpdate != null) {
          final box = context.findRenderObject() as RenderBox;
          final localPosition = box.globalToLocal(details.globalPosition);
          onDragUpdate!(localPosition);
        }
      },
      onDraggableCanceled: (_, __) {
        onDragEnd?.call(false);
      },
      onDragCompleted: () {
        onDragEnd?.call(true);
      },
      child: child,
    );
  }
}

class ClipDropTarget extends StatelessWidget {
  final String trackId;
  final double trackWidth;
  final double pixelsPerSecond;
  final Widget child;
  final Function(AudioClip clip, String sourceTrackId, Duration newStartTime)? onAccept;
  final Function(AudioClip? clip, String? sourceTrackId)? onWillAccept;
  final Function(AudioClip? clip, String? sourceTrackId)? onLeave;

  const ClipDropTarget({
    super.key,
    required this.trackId,
    required this.trackWidth,
    required this.pixelsPerSecond,
    this.onAccept,
    this.onWillAccept,
    this.onLeave,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<Map<String, dynamic>>(
      onWillAccept: (data) {
        if (data == null) return false;
        final clip = data['clip'] as AudioClip;
        final sourceTrackId = data['sourceTrackId'] as String;
        
        // Don't allow dropping on the same position in the same track
        if (sourceTrackId == trackId) {
          return false;
        }
        
        onWillAccept?.call(clip, sourceTrackId);
        return true;
      },
      onAccept: (data) {
        final clip = data['clip'] as AudioClip;
        final sourceTrackId = data['sourceTrackId'] as String;
        
        // Calculate the new start time based on drop position
        final dropPosition = MediaQuery.of(context).size.width / 2; // Center of the drop target
        final newStartTime = Duration(
          milliseconds: (dropPosition / pixelsPerSecond * 1000).round(),
        );
        
        onAccept?.call(clip, sourceTrackId, newStartTime);
      },
      onLeave: (data) {
        if (data == null) return;
        final clip = data['clip'] as AudioClip;
        final sourceTrackId = data['sourceTrackId'] as String;
        onLeave?.call(clip, sourceTrackId);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty 
                ? Colors.blue.withOpacity(0.1)
                : Colors.transparent,
            border: candidateData.isNotEmpty
                ? Border.all(color: Colors.blue, width: 1.5)
                : null,
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: child,
        );
      },
    );
  }
}

class TrackDropTarget extends StatelessWidget {
  final String trackId;
  final double trackHeight;
  final Widget child;
  final Function(AudioClip clip, String sourceTrackId, String targetTrackId)? onDrop;

  const TrackDropTarget({
    super.key,
    required this.trackId,
    required this.trackHeight,
    this.onDrop,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<Map<String, dynamic>>(
      onWillAccept: (data) {
        if (data == null) return false;
        final sourceTrackId = data['sourceTrackId'] as String;
        // Don't allow dropping on the same track
        return sourceTrackId != trackId;
      },
      onAccept: (data) {
        final clip = data['clip'] as AudioClip;
        final sourceTrackId = data['sourceTrackId'] as String;
        onDrop?.call(clip, sourceTrackId, trackId);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty 
                ? Colors.blue.withOpacity(0.05)
                : Colors.transparent,
            border: candidateData.isNotEmpty
                ? Border.all(color: Colors.blue, width: 1.0, style: BorderStyle.solid)
                : null,
          ),
          height: trackHeight,
          child: child,
        );
      },
    );
  }
}
