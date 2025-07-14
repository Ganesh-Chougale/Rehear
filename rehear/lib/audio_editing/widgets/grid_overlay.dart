import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/editor_settings_provider.dart';

class GridOverlay extends ConsumerWidget {
  final double width;
  final double height;
  final double pixelsPerSecond;
  final Function(Duration position)? onAddMarker;
  final Function(Marker marker)? onMarkerTap;

  const GridOverlay({
    super.key,
    required this.width,
    required this.height,
    required this.pixelsPerSecond,
    this.onAddMarker,
    this.onMarkerTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(editorSettingsProvider);
    final markers = settings.markers;
    
    return GestureDetector(
      onDoubleTapDown: (details) {
        final position = Duration(
          milliseconds: (details.localPosition.dx / pixelsPerSecond * 1000).round(),
        );
        onAddMarker?.call(position);
      },
      child: CustomPaint(
        size: Size(width, height),
        painter: _GridPainter(
          settings: settings,
          pixelsPerSecond: pixelsPerSecond,
          markers: markers,
          onMarkerTap: onMarkerTap,
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final EditorSettings settings;
  final double pixelsPerSecond;
  final List<Marker> markers;
  final Function(Marker marker)? onMarkerTap;

  _GridPainter({
    required this.settings,
    required this.pixelsPerSecond,
    required this.markers,
    this.onMarkerTap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    _drawMarkers(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = settings.gridSettings.color
          .withOpacity(settings.gridSettings.opacity)
      ..strokeWidth = 1.0;

    final division = settings.gridSettings.division;
    if (division.inMilliseconds == 0) return;

    final divisions = (size.width / (division.inMilliseconds / 1000 * pixelsPerSecond)).ceil();
    final subDivisions = settings.gridSettings.subdivisions;

    for (int i = 0; i <= divisions; i++) {
      final x = i * division.inMilliseconds / 1000 * pixelsPerSecond;
      
      // Draw main division
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );

      // Draw sub-divisions
      if (subDivisions > 1) {
        final subDivisionWidth = (division.inMilliseconds / subDivisions) / 1000 * pixelsPerSecond;
        for (int j = 1; j < subDivisions; j++) {
          final subX = x + j * subDivisionWidth;
          canvas.drawLine(
            Offset(subX, size.height * 0.7),
            Offset(subX, size.height),
            gridPaint..strokeWidth = 0.5,
          );
        }
      }
    }
  }

  void _drawMarkers(Canvas canvas, Size size) {
    final markerPaint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 2.0;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    for (final marker in markers) {
      final x = marker.position.inMilliseconds / 1000 * pixelsPerSecond;
      
      // Draw marker line
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        markerPaint..color = marker.color,
      );

      // Draw marker label
      textPainter.text = TextSpan(
        text: marker.name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          backgroundColor: Colors.black54,
        ),
      );
      
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + 4, 4),
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) {
    return oldDelegate.settings != settings ||
        oldDelegate.pixelsPerSecond != pixelsPerSecond ||
        oldDelegate.markers.length != markers.length;
  }
}
