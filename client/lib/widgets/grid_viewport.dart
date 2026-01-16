import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:ui' as ui;
import '../state/chunk_manager.dart';
import '../painters/grid_painter.dart';

/// High-performance viewport with chunk-based rendering.
class GridViewport extends StatefulWidget {
  const GridViewport({super.key});

  @override
  State<GridViewport> createState() => _GridViewportState();
}

class _GridViewportState extends State<GridViewport> {
  late ChunkManager _chunkManager;
  
  // View state
  Offset _viewOffset = const Offset(400, 300);
  double _cellSize = 20.0;
  
  // Zoom limits
  static const double minCellSize = 5.0;
  static const double maxCellSize = 100.0;

  // Chunk image cache - THE KEY OPTIMIZATION
  final Map<ChunkCoord, ui.Image> _chunkImageCache = {};
  bool _needsRepaint = true;

  @override
  void initState() {
    super.initState();
    _chunkManager = ChunkManager(worldSeed: 12345);
  }

  @override
  void dispose() {
    // Dispose cached images
    for (final img in _chunkImageCache.values) {
      img.dispose();
    }
    super.dispose();
  }

  void _handlePan(DragUpdateDetails details) {
    setState(() {
      _viewOffset += details.delta;
      _needsRepaint = true;
    });
  }

  void _handleScroll(PointerScrollEvent event) {
    setState(() {
      final cursorPos = event.localPosition;
      final worldPosBefore = (cursorPos - _viewOffset) / _cellSize;
      
      final zoomDelta = -event.scrollDelta.dy * 0.001;
      final oldCellSize = _cellSize;
      _cellSize = (_cellSize * (1 + zoomDelta)).clamp(minCellSize, maxCellSize);
      
      // Invalidate cache if zoom changed significantly
      if ((oldCellSize - _cellSize).abs() > 0.5) {
        _invalidateChunkCache();
      }
      
      final worldPosAfter = worldPosBefore * _cellSize;
      _viewOffset = cursorPos - worldPosAfter;
      _needsRepaint = true;
    });
  }

  void _invalidateChunkCache() {
    for (final img in _chunkImageCache.values) {
      img.dispose();
    }
    _chunkImageCache.clear();
  }

  Set<ChunkCoord> _getVisibleChunkCoords(Size size) {
    final viewport = Rect.fromLTWH(
      -_viewOffset.dx,
      -_viewOffset.dy,
      size.width,
      size.height,
    );
    return _chunkManager.getVisibleChunks(viewport, _cellSize);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final visibleCoords = _getVisibleChunkCoords(size);
        
        // Load chunks for visible area
        for (final coord in visibleCoords) {
          _chunkManager.loadChunk(coord);
        }
        _chunkManager.evictOutsideView(visibleCoords);
        
        return Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              _handleScroll(event);
            }
          },
          child: GestureDetector(
            onPanUpdate: _handlePan,
            child: Container(
              color: const Color(0xFF0D0D0D),
              child: Stack(
                children: [
                  // Use RepaintBoundary to isolate repaints
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: OptimizedGridPainter(
                        cellSize: _cellSize,
                        viewOffset: _viewOffset,
                        chunks: _chunkManager.chunks,
                        visibleCoords: visibleCoords,
                      ),
                      size: size,
                      isComplex: true, // Hint for caching
                      willChange: false, // Content changes rarely
                    ),
                  ),
                  // Debug overlay
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Chunks: ${visibleCoords.length}/${_chunkManager.cachedChunkCount} | Zoom: ${_cellSize.toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: Color(0xFF00FF88),
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Optimized painter that only draws visible chunks.
class OptimizedGridPainter extends CustomPainter {
  final double cellSize;
  final Offset viewOffset;
  final Iterable<ChunkData> chunks;
  final Set<ChunkCoord> visibleCoords;
  
  static const Color gridLineColor = Color(0xFF2A2A2A);
  static const Color cityGlowColor = Color(0xFF00FF88);

  OptimizedGridPainter({
    required this.cellSize,
    required this.viewOffset,
    required this.chunks,
    required this.visibleCoords,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Clip to viewport for performance
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    final gridPaint = Paint()
      ..color = gridLineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final chunkPixelSize = ChunkManager.chunkSize * cellSize;

    // Draw grid lines only for visible area
    final startX = (-viewOffset.dx / cellSize).floor();
    final endX = ((-viewOffset.dx + size.width) / cellSize).ceil();
    final startY = (-viewOffset.dy / cellSize).floor();
    final endY = ((-viewOffset.dy + size.height) / cellSize).ceil();

    // Batch vertical lines
    final path = Path();
    for (int x = startX; x <= endX; x++) {
      final screenX = x * cellSize + viewOffset.dx;
      path.moveTo(screenX, 0);
      path.lineTo(screenX, size.height);
    }
    
    // Batch horizontal lines
    for (int y = startY; y <= endY; y++) {
      final screenY = y * cellSize + viewOffset.dy;
      path.moveTo(0, screenY);
      path.lineTo(size.width, screenY);
    }
    
    // Single draw call for all lines
    canvas.drawPath(path, gridPaint);

    // Draw cities only from visible chunks
    final cityPaint = Paint()
      ..color = cityGlowColor
      ..style = PaintingStyle.fill;

    final cityGlowPaint = Paint()
      ..color = cityGlowColor.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    for (final chunk in chunks) {
      if (!visibleCoords.contains(chunk.coord)) continue;
      
      final chunkOriginX = chunk.coord.x * chunkPixelSize + viewOffset.dx;
      final chunkOriginY = chunk.coord.y * chunkPixelSize + viewOffset.dy;

      for (final city in chunk.cities) {
        final cityX = chunkOriginX + city.localX * chunkPixelSize;
        final cityY = chunkOriginY + city.localY * chunkPixelSize;

        // Skip if off screen (tight culling)
        if (cityX < -10 || cityX > size.width + 10 ||
            cityY < -10 || cityY > size.height + 10) continue;

        canvas.drawCircle(Offset(cityX, cityY), 5, cityGlowPaint);
        canvas.drawCircle(Offset(cityX, cityY), 2.5, cityPaint);
      }
    }
  }

  @override
  bool shouldRepaint(OptimizedGridPainter oldDelegate) {
    return oldDelegate.cellSize != cellSize ||
        oldDelegate.viewOffset != viewOffset ||
        oldDelegate.visibleCoords.length != visibleCoords.length;
  }
}
