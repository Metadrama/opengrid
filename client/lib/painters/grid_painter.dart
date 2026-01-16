import 'package:flutter/material.dart';
import '../state/chunk_manager.dart';

/// CustomPainter for the infinite grid with dark aesthetic.
class GridPainter extends CustomPainter {
  final double cellSize;
  final Offset viewOffset;
  final Iterable<ChunkData> chunks;
  
  // Dark aesthetic colors
  static const Color bgColor = Color(0xFF0D0D0D);
  static const Color gridLineColor = Color(0xFF2A2A2A); // Brighter for visibility
  static const Color cityGlowColor = Color(0xFF00FF88);
  static const double lineWidth = 1.0; // Slightly thicker

  GridPainter({
    required this.cellSize,
    required this.viewOffset,
    required this.chunks,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridLineColor
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    final cityPaint = Paint()
      ..color = cityGlowColor
      ..style = PaintingStyle.fill;

    final cityGlowPaint = Paint()
      ..color = cityGlowColor.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // Calculate visible grid bounds
    final startX = (-viewOffset.dx / cellSize).floor();
    final endX = ((-viewOffset.dx + size.width) / cellSize).ceil();
    final startY = (-viewOffset.dy / cellSize).floor();
    final endY = ((-viewOffset.dy + size.height) / cellSize).ceil();

    // Draw vertical grid lines
    for (int x = startX; x <= endX; x++) {
      final screenX = x * cellSize + viewOffset.dx;
      canvas.drawLine(
        Offset(screenX, 0),
        Offset(screenX, size.height),
        gridPaint,
      );
    }

    // Draw horizontal grid lines
    for (int y = startY; y <= endY; y++) {
      final screenY = y * cellSize + viewOffset.dy;
      canvas.drawLine(
        Offset(0, screenY),
        Offset(size.width, screenY),
        gridPaint,
      );
    }

    // Draw cities from loaded chunks
    final chunkPixelSize = ChunkManager.chunkSize * cellSize;
    
    for (final chunk in chunks) {
      final chunkOriginX = chunk.coord.x * chunkPixelSize + viewOffset.dx;
      final chunkOriginY = chunk.coord.y * chunkPixelSize + viewOffset.dy;

      for (final city in chunk.cities) {
        final cityX = chunkOriginX + city.localX * chunkPixelSize;
        final cityY = chunkOriginY + city.localY * chunkPixelSize;

        // Skip if off screen
        if (cityX < -20 || cityX > size.width + 20 ||
            cityY < -20 || cityY > size.height + 20) continue;

        // Draw glow
        canvas.drawCircle(Offset(cityX, cityY), 6, cityGlowPaint);
        // Draw city dot
        canvas.drawCircle(Offset(cityX, cityY), 3, cityPaint);
      }
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) {
    return oldDelegate.cellSize != cellSize ||
        oldDelegate.viewOffset != viewOffset;
  }
}
