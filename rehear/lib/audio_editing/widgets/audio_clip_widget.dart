import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/audio_clip.dart';
import 'trim_handles.dart';
import 'clip_context_menu.dart';
import 'volume_automation_dialog.dart';

class AudioClipWidget extends ConsumerStatefulWidget {
  final AudioClip clip;
  final String trackId;
  final bool isSelected;
  final double pixelsPerSecond;
  final double trackHeight;
  final VoidCallback onTap;
  final ValueChanged<bool> onSelectionChanged;
  final Function(Duration, Duration) onTrim;
  final Function(String, String, Duration) onSplit;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final Function(AudioClip) onUpdateClip;

  const AudioClipWidget({
    super.key,
    required this.clip,
    required this.trackId,
    required this.isSelected,
    required this.pixelsPerSecond,
    required this.trackHeight,
    required this.onTap,
    required this.onSelectionChanged,
    required this.onTrim,
    required this.onSplit,
    required this.onDelete,
    required this.onDuplicate,
    required this.onUpdateClip,
  });

  @override
  ConsumerState<AudioClipWidget> createState() => _AudioClipWidgetState();
}

class _AudioClipWidgetState extends ConsumerState<AudioClipWidget> {
  bool _isHovered = false;
  final GlobalKey _clipKey = GlobalKey();
  Offset? _dragStartPosition;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isSelected || _isHovered;
    final width = widget.clip.duration.inMilliseconds / 1000 * widget.pixelsPerSecond;
    
    return GestureDetector(
      onTapDown: _handleTapDown,
      onLongPressStart: _handleLongPressStart,
      onLongPressMoveUpdate: _handleLongPressMove,
      onLongPressEnd: _handleLongPressEnd,
      onLongPressCancel: _handleLongPressCancel,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Stack(
          key: _clipKey,
          children: [
            // Clip content
            Container(
              width: width,
              height: widget.trackHeight - 4,
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue[700]!.withOpacity(0.7),
                border: Border.all(
                  color: isActive ? Colors.blue[100]! : Colors.transparent,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  widget.clip.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            
            // Trim handles (only show when selected)
            if (widget.isSelected)
              Positioned.fill(
                child: TrimHandles(
                  clip: widget.clip,
                  width: width,
                  height: widget.trackHeight,
                  pixelsPerSecond: widget.pixelsPerSecond,
                  onTrim: widget.onTrim,
                  showLeftHandle: true,
                  showRightHandle: true,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleTapDown(TapDownDetails details) {
    widget.onTap();
    
    // Show context menu on right-click
    if (details.kind == PointerDeviceKind.mouse && 
        details.buttons == kSecondaryButton) {
      _showContextMenu(details.globalPosition);
    }
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    _dragStartPosition = details.globalPosition;
    widget.onSelectionChanged(true);
  }

  void _handleLongPressMove(LongPressMoveUpdateDetails details) {
    // Handle drag movement for moving clips
    if (_dragStartPosition != null) {
      final delta = details.globalPosition - _dragStartPosition!;
      // TODO: Implement clip dragging logic
    }
  }

  void _handleLongPressEnd(LongPressEndDetails _) {
    _dragStartPosition = null;
  }

  void _handleLongPressCancel() {
    _dragStartPosition = null;
  }

  void _showContextMenu(Offset position) async {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    await showMenu(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40), // Smaller rect for the tap position
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          height: 0,
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.graphic_eq),
                title: const Text('Volume Automation'),
                onTap: () {
                  Navigator.pop(context);
                  _showVolumeAutomationDialog();
                },
              ),
              const Divider(height: 1),
              ClipContextMenu(
                clip: widget.clip,
                trackId: widget.trackId,
                onDelete: () {
                  Navigator.pop(context);
                  widget.onDelete();
                },
                onDuplicate: widget.onDuplicate,
                onTrim: widget.onTrim,
                onSplit: widget.onSplit,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showVolumeAutomationDialog() async {
    await VolumeAutomationDialog.show(
      context: context,
      clip: widget.clip,
      onSave: (updatedClip) {
        widget.onUpdateClip(updatedClip);
      },
    );
  }
}
