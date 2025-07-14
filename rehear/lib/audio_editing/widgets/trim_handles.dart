import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/audio_clip.dart';
import '../../providers/editor_settings_provider.dart';

class TrimHandles extends StatelessWidget {
  final AudioClip clip;
  final double width;
  final double height;
  final double pixelsPerSecond;
  final Function(Duration, Duration) onTrim;
  final bool showLeftHandle;
  final bool showRightHandle;

  const TrimHandles({
    super.key,
    required this.clip,
    required this.width,
    required this.height,
    required this.pixelsPerSecond,
    required this.onTrim,
    this.showLeftHandle = true,
    this.showRightHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final snapToGrid = ref.watch(editorSettingsProvider).snapToGrid;
        
        return Stack(
          children: [
            if (showLeftHandle)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: _buildTrimHandle(
                  context,
                  isLeft: true,
                  snapToGrid: snapToGrid,
                ),
              ),
            if (showRightHandle)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: _buildTrimHandle(
                  context,
                  isLeft: false,
                  snapToGrid: snapToGrid,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTrimHandle(
    BuildContext context, {
    required bool isLeft,
    required bool snapToGrid,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (details) {
        // Capture initial state
      },
      onHorizontalDragUpdate: (details) {
        final delta = details.primaryDelta ?? 0;
        final deltaDuration = Duration(
          milliseconds: (delta / pixelsPerSecond * 1000).round(),
        );

        if (isLeft) {
          final newStart = clip.startTime + deltaDuration;
          if (newStart >= Duration.zero && newStart < clip.endTime) {
            onTrim(newStart, clip.endTime);
          }
        } else {
          final newEnd = clip.endTime + deltaDuration;
          if (newEnd > clip.startTime) {
            onTrim(clip.startTime, newEnd);
          }
        }
      },
      onHorizontalDragEnd: (_) {
        // Finalize trim operation
      },
      child: Container(
        width: 16,
        color: Colors.blue.withOpacity(0.3),
        child: Center(
          child: Container(
            width: 4,
            height: 24,
            color: Colors.blue,
          ),
        ),
      ),
    );
  }
}
