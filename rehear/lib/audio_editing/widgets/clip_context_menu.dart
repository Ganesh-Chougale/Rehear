import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/audio_clip.dart';
import '../../providers/editor_settings_provider.dart';
import '../../services/audio_edit_service.dart';

class ClipContextMenu extends StatelessWidget {
  final AudioClip clip;
  final String trackId;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final Function(Duration, Duration) onTrim;
  final Function(String, String, Duration) onSplit;

  const ClipContextMenu({
    super.key,
    required this.clip,
    required this.trackId,
    required this.onDelete,
    required this.onDuplicate,
    required this.onTrim,
    required this.onSplit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.content_cut),
          title: const Text('Cut'),
          onTap: () {
            Navigator.pop(context);
            _handleCut();
          },
        ),
        ListTile(
          leading: const Icon(Icons.copy),
          title: const Text('Copy'),
          onTap: () {
            Navigator.pop(context);
            _handleCopy();
          },
        ),
        ListTile(
          leading: const Icon(Icons.content_paste),
          title: const Text('Paste'),
          onTap: () {
            Navigator.pop(context);
            _handlePaste();
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.content_cut, color: Colors.orange),
          title: const Text('Split at Playhead'),
          onTap: () {
            Navigator.pop(context);
            _handleSplitAtPlayhead();
          },
        ),
        ListTile(
          leading: const Icon(Icons.content_copy),
          title: const Text('Duplicate'),
          onTap: () {
            Navigator.pop(context);
            onDuplicate();
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.delete, color: Colors.red),
          title: const Text('Delete', style: TextStyle(color: Colors.red)),
          onTap: () {
            Navigator.pop(context);
            onDelete();
          },
        ),
      ],
    );
  }

  void _handleCut() {
    // TODO: Implement cut to clipboard
    // This would involve copying the clip and then deleting it
  }

  void _handleCopy() {
    // TODO: Implement copy to clipboard
  }

  void _handlePaste() {
    // TODO: Implement paste from clipboard
  }

  void _handleSplitAtPlayhead() {
    // Get current playhead position from provider or state
    final playheadPosition = Duration.zero; // TODO: Get actual playhead position
    
    if (playheadPosition > clip.startTime && playheadPosition < clip.endTime) {
      onSplit(trackId, clip.id, playheadPosition);
    }
  }
}
