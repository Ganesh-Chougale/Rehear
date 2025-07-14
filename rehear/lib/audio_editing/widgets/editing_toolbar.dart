import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/audio_editor_provider.dart';

class EditingToolbar extends ConsumerWidget {
  final String? selectedClipId;
  final String? selectedTrackId;
  final Duration? playheadPosition;
  final Function(Duration, Duration) onSelectionChanged;
  final ValueNotifier<DurationRange?> selectionRange;
  final Function(String)? onMergeClips;
  final List<String>? selectedClipIds;

  const EditingToolbar({
    super.key,
    this.selectedClipId,
    this.selectedTrackId,
    this.playheadPosition,
    required this.onSelectionChanged,
    required this.selectionRange,
    this.onMergeClips,
    this.selectedClipIds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canUndo = ref.watch(audioEditorProvider.select((state) => state.tracks.isNotEmpty));
    final canRedo = false; // This would need to be tracked in the state

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          // Undo/Redo buttons
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
            onPressed: canUndo ? () => ref.read(audioEditorProvider.notifier).undo() : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            tooltip: 'Redo',
            onPressed: canRedo ? () => ref.read(audioEditorProvider.notifier).redo() : null,
          ),
          const VerticalDivider(),
          
          // Cut button
          IconButton(
            icon: const Icon(Icons.content_cut),
            tooltip: 'Cut',
            onPressed: _canEdit() ? () => _onCut(ref) : null,
          ),
          
          // Trim button
          IconButton(
            icon: const Icon(Icons.content_cut_rounded),
            tooltip: 'Trim to selection',
            onPressed: _canEdit() && selectionRange.value != null
                ? () => _onTrim(ref)
                : null,
          ),
          
          // Split button
          IconButton(
            icon: const Icon(Icons.cut_outlined),
            tooltip: 'Split at playhead',
            onPressed: _canEdit() && playheadPosition != null
                ? () => _onSplit(ref)
                : null,
          ),
          
          // Merge button
          _buildMergeButton(context, ref),
          
          // Selection indicators
          if (selectionRange.value != null) ...[
            const SizedBox(width: 16),
            Text(
              'Selection: ${_formatDuration(selectionRange.value!.start)} - ${_formatDuration(selectionRange.value!.end)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  bool _canEdit() {
    return selectedClipId != null && selectedTrackId != null;
  }

  void _onCut(WidgetRef ref) {
    if (selectedTrackId == null || selectedClipId == null || selectionRange.value == null) return;
    
    ref.read(audioEditorProvider.notifier).cutClip(
      trackId: selectedTrackId!,
      clipId: selectedClipId!,
      startCut: selectionRange.value!.start,
      endCut: selectionRange.value!.end,
      keepCutPortion: false,
    );
    
    // Clear selection after cut
    selectionRange.value = null;
  }

  void _onTrim(WidgetRef ref) {
    if (selectedTrackId == null || selectedClipId == null || selectionRange.value == null) return;
    
    ref.read(audioEditorProvider.notifier).trimClip(
      trackId: selectedTrackId!,
      clipId: selectedClipId!,
      start: selectionRange.value!.start,
      end: selectionRange.value!.end,
    );
    
    // Clear selection after trim
    selectionRange.value = null;
  }

  void _onSplit(WidgetRef ref) {
    if (selectedTrackId == null || selectedClipId == null || playheadPosition == null) return;
    
    ref.read(audioEditorProvider.notifier).splitClip(
      trackId: selectedTrackId!,
      clipId: selectedClipId!,
      position: playheadPosition!,
    );
  }

  Widget _buildMergeButton(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: 'Merge Selected Clips (${selectedClipIds?.length ?? 0} selected)',
      child: IconButton(
        icon: const Icon(Icons.merge_type),
        color: selectedClipIds?.length ?? 0 >= 2 
            ? Theme.of(context).primaryColor 
            : Colors.grey,
        onPressed: selectedClipIds?.length ?? 0 >= 2
            ? () async {
                if (onMergeClips != null) {
                  final newName = await _showMergeDialog(context);
                  if (newName != null) {
                    onMergeClips!(newName);
                  }
                }
              }
            : null,
      ),
    );
  }

  Future<String?> _showMergeDialog(BuildContext context) async {
    final controller = TextEditingController(text: 'Merged Clip');
    return showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Merge Clips'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a name for the merged clip:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Clip Name',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Merge'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final milliseconds = twoDigits(duration.inMilliseconds.remainder(1000) ~/ 10);
    return '$minutes:$seconds.$milliseconds';
  }
}

class DurationRange {
  final Duration start;
  final Duration end;

  DurationRange(this.start, this.end);

  Duration get duration => end - start;

  bool contains(Duration position) {
    return position >= start && position <= end;
  }

  @override
  String toString() => 'DurationRange($start, $end)';
}
