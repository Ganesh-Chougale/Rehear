import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/editor_settings_provider.dart';

class GridOverlay extends ConsumerWidget {
  final double width;
  final double height;
  final double pixelsPerSecond;
  final ScrollController scrollController;

  const GridOverlay({
    super.key,
    required this.width,
    required this.height,
    required this.pixelsPerSecond,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(editorSettingsProvider);
    final gridSettings = settings.gridSettings;
    
    if (!settings.snapToGrid) return const SizedBox.shrink();

    return CustomPaint(
      size: Size(width, height),
      painter: _GridPainter(
        division: gridSettings.division,
        subdivisions: gridSettings.subdivisions,
        color: gridSettings.color.withOpacity(gridSettings.opacity),
        pixelsPerSecond: pixelsPerSecond,
        scrollOffset: scrollController.offset,
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Duration division;
  final int subdivisions;
  final Color color;
  final double pixelsPerSecond;
  final double scrollOffset;

  _GridPainter({
    required this.division,
    required this.subdivisions,
    required this.color,
    required this.pixelsPerSecond,
    required this.scrollOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final subdivPaint = Paint()
      ..color = color.withOpacity(0.5)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final divisionPx = division.inMilliseconds / 1000 * pixelsPerSecond;
    final subdivPx = divisionPx / subdivisions;

    // Calculate visible range based on scroll position
    final startX = -scrollOffset % divisionPx;
    
    // Draw subdivision lines
    for (var x = startX; x < size.width; x += subdivPx) {
      final isMainLine = (x - startX) % divisionPx == 0;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        isMainLine ? paint : subdivPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) {
    return oldDelegate.division != division ||
        oldDelegate.subdivisions != subdivisions ||
        oldDelegate.color != color ||
        oldDelegate.scrollOffset != scrollOffset;
  }
}
