import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/audio_clip.dart';
import 'volume_automation_editor.dart';

class VolumeAutomationDialog extends StatefulWidget {
  final AudioClip clip;
  final Function(AudioClip) onSave;

  const VolumeAutomationDialog({
    super.key,
    required this.clip,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    required AudioClip clip,
    required Function(AudioClip) onSave,
  }) async {
    return showDialog(
      context: context,
      builder: (context) => VolumeAutomationDialog(
        clip: clip,
        onSave: onSave,
      ),
    );
  }

  @override
  State<VolumeAutomationDialog> createState() => _VolumeAutomationDialogState();
}

class _VolumeAutomationDialogState extends State<VolumeAutomationDialog> {
  late AudioClip _editedClip;
  final _editorKey = GlobalKey();
  final _editorWidth = 600.0;
  final _editorHeight = 200.0;

  @override
  void initState() {
    super.initState();
    _editedClip = widget.clip;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Volume Automation'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: _editorWidth,
          maxWidth: _editorWidth,
          minHeight: _editorHeight + 100,
          maxHeight: _editorHeight + 100,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Volume scale on the left
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Volume scale (0-100%)
                  SizedBox(
                    width: 40,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('100%', style: _scaleTextStyle),
                        const Spacer(),
                        Text('50%', style: _scaleTextStyle),
                        const Spacer(),
                        Text('0%', style: _scaleTextStyle),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Editor area
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: VolumeAutomationEditor(
                          key: _editorKey,
                          clip: _editedClip,
                          width: _editorWidth - 48,
                          height: _editorHeight,
                          onPointsChanged: (points) {
                            // Update the clip with new automation points
                            var updatedClip = _editedClip;
                            for (final point in points) {
                              updatedClip = updatedClip.withVolumePoint(point);
                            }
                            setState(() {
                              _editedClip = updatedClip;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Time scale at the bottom
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0:00', style: _scaleTextStyle),
                  Text(
                    '${_editedClip.duration.inSeconds ~/ 60}:${(_editedClip.duration.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: _scaleTextStyle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSave(_editedClip);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  TextStyle get _scaleTextStyle => const TextStyle(
        fontSize: 12,
        color: Colors.grey,
      );
}
