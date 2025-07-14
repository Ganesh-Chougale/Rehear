import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/editor_settings_provider.dart';

class MarkersOverlay extends ConsumerWidget {
  final double width;
  final double height;
  final double pixelsPerSecond;
  final ScrollController scrollController;
  final Function(Marker)? onMarkerTap;
  final Function(Marker)? onMarkerLongPress;

  const MarkersOverlay({
    super.key,
    required this.width,
    required this.height,
    required this.pixelsPerSecond,
    required this.scrollController,
    this.onMarkerTap,
    this.onMarkerLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final markers = ref.watch(editorSettingsProvider.select((s) => s.markers));
    
    return Stack(
      children: markers.map((marker) {
        final position = marker.position.inMilliseconds / 1000 * pixelsPerSecond;
        
        return Positioned(
          left: position - scrollController.offset,
          child: GestureDetector(
            onTap: () => onMarkerTap?.call(marker),
            onLongPress: () => onMarkerLongPress?.call(marker),
            child: Container(
              width: 2,
              height: height,
              color: marker.color,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: marker.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    marker.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class MarkerContextMenu extends StatelessWidget {
  final Marker marker;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MarkerContextMenu({
    super.key,
    required this.marker,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text('Edit Marker'),
          onTap: () {
            Navigator.pop(context);
            onEdit();
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete, color: Colors.red),
          title: const Text('Delete Marker', style: TextStyle(color: Colors.red)),
          onTap: () {
            Navigator.pop(context);
            onDelete();
          },
        ),
      ],
    );
  }
}
