import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:ui' as ui;
import '../state/chunk_manager.dart';

/// High-performance viewport with chunk-based rendering and city interaction.
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

  // Selection state
  City? _selectedCity;
  ChunkCoord? _selectedChunk;
  Offset? _selectedScreenPos;

  // Chunk image cache
  final Map<ChunkCoord, ui.Image> _chunkImageCache = {};

  @override
  void initState() {
    super.initState();
    _chunkManager = ChunkManager(worldSeed: 12345);
  }

  @override
  void dispose() {
    for (final img in _chunkImageCache.values) {
      img.dispose();
    }
    super.dispose();
  }

  void _handlePan(DragUpdateDetails details) {
    setState(() {
      _viewOffset += details.delta;
      _clearSelection();
    });
  }

  void _handleScroll(PointerScrollEvent event) {
    setState(() {
      final cursorPos = event.localPosition;
      final worldPosBefore = (cursorPos - _viewOffset) / _cellSize;
      
      final zoomDelta = -event.scrollDelta.dy * 0.001;
      final oldCellSize = _cellSize;
      _cellSize = (_cellSize * (1 + zoomDelta)).clamp(minCellSize, maxCellSize);
      
      if ((oldCellSize - _cellSize).abs() > 0.5) {
        _invalidateChunkCache();
      }
      
      final worldPosAfter = worldPosBefore * _cellSize;
      _viewOffset = cursorPos - worldPosAfter;
      _clearSelection();
    });
  }

  void _handleTap(TapUpDetails details) {
    final tapPos = details.localPosition;
    final chunkPixelSize = ChunkManager.chunkSize * _cellSize;
    
    // Find city near tap
    for (final chunk in _chunkManager.chunks) {
      final chunkOriginX = chunk.coord.x * chunkPixelSize + _viewOffset.dx;
      final chunkOriginY = chunk.coord.y * chunkPixelSize + _viewOffset.dy;
      
      for (final city in chunk.cities) {
        final cityX = chunkOriginX + city.localX * chunkPixelSize;
        final cityY = chunkOriginY + city.localY * chunkPixelSize;
        
        final distance = (Offset(cityX, cityY) - tapPos).distance;
        if (distance < 15) {
          setState(() {
            _selectedCity = city;
            _selectedChunk = chunk.coord;
            _selectedScreenPos = Offset(cityX, cityY);
          });
          return;
        }
      }
    }
    
    // Tapped empty space - clear selection
    setState(() => _clearSelection());
  }

  void _clearSelection() {
    _selectedCity = null;
    _selectedChunk = null;
    _selectedScreenPos = null;
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
            onTapUp: _handleTap,
            child: Container(
              color: const Color(0xFF0D0D0D),
              child: Stack(
                children: [
                  // Grid canvas
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: OptimizedGridPainter(
                        cellSize: _cellSize,
                        viewOffset: _viewOffset,
                        chunks: _chunkManager.chunks,
                        visibleCoords: visibleCoords,
                        selectedCity: _selectedCity,
                        selectedChunk: _selectedChunk,
                      ),
                      size: size,
                      isComplex: true,
                      willChange: false,
                    ),
                  ),
                  
                  // City tooltip
                  if (_selectedCity != null && _selectedScreenPos != null)
                    Positioned(
                      left: _selectedScreenPos!.dx + 15,
                      top: _selectedScreenPos!.dy - 60,
                      child: _CityTooltip(
                        city: _selectedCity!,
                        chunk: _selectedChunk!,
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

/// Tooltip showing city/TSP info.
class _CityTooltip extends StatelessWidget {
  final City city;
  final ChunkCoord chunk;

  const _CityTooltip({required this.city, required this.chunk});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF00FF88), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FF88).withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'CITY NODE',
            style: TextStyle(
              color: Color(0xFF00FF88),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Chunk: (${chunk.x}, ${chunk.y})',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            'TSP Seed: ${city.seed.toRadixString(16).toUpperCase()}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF88).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'ENTER TO SOLVE',
              style: TextStyle(
                color: Color(0xFF00FF88),
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Optimized painter with selection highlight.
class OptimizedGridPainter extends CustomPainter {
  final double cellSize;
  final Offset viewOffset;
  final Iterable<ChunkData> chunks;
  final Set<ChunkCoord> visibleCoords;
  final City? selectedCity;
  final ChunkCoord? selectedChunk;
  
  static const Color gridLineColor = Color(0xFF2A2A2A);
  static const Color cityGlowColor = Color(0xFF00FF88);
  static const Color selectedGlowColor = Color(0xFFFFFF00);

  OptimizedGridPainter({
    required this.cellSize,
    required this.viewOffset,
    required this.chunks,
    required this.visibleCoords,
    this.selectedCity,
    this.selectedChunk,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    final gridPaint = Paint()
      ..color = gridLineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final chunkPixelSize = ChunkManager.chunkSize * cellSize;

    // Grid lines
    final startX = (-viewOffset.dx / cellSize).floor();
    final endX = ((-viewOffset.dx + size.width) / cellSize).ceil();
    final startY = (-viewOffset.dy / cellSize).floor();
    final endY = ((-viewOffset.dy + size.height) / cellSize).ceil();

    final path = Path();
    for (int x = startX; x <= endX; x++) {
      final screenX = x * cellSize + viewOffset.dx;
      path.moveTo(screenX, 0);
      path.lineTo(screenX, size.height);
    }
    for (int y = startY; y <= endY; y++) {
      final screenY = y * cellSize + viewOffset.dy;
      path.moveTo(0, screenY);
      path.lineTo(size.width, screenY);
    }
    canvas.drawPath(path, gridPaint);

    // Cities
    final cityPaint = Paint()
      ..color = cityGlowColor
      ..style = PaintingStyle.fill;
    final cityGlowPaint = Paint()
      ..color = cityGlowColor.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    
    final selectedPaint = Paint()
      ..color = selectedGlowColor
      ..style = PaintingStyle.fill;
    final selectedGlowPaint = Paint()
      ..color = selectedGlowColor.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    for (final chunk in chunks) {
      if (!visibleCoords.contains(chunk.coord)) continue;
      
      final chunkOriginX = chunk.coord.x * chunkPixelSize + viewOffset.dx;
      final chunkOriginY = chunk.coord.y * chunkPixelSize + viewOffset.dy;

      for (final city in chunk.cities) {
        final cityX = chunkOriginX + city.localX * chunkPixelSize;
        final cityY = chunkOriginY + city.localY * chunkPixelSize;

        if (cityX < -10 || cityX > size.width + 10 ||
            cityY < -10 || cityY > size.height + 10) continue;

        final isSelected = selectedCity != null && 
            selectedChunk == chunk.coord &&
            city.seed == selectedCity!.seed;

        if (isSelected) {
          canvas.drawCircle(Offset(cityX, cityY), 10, selectedGlowPaint);
          canvas.drawCircle(Offset(cityX, cityY), 4, selectedPaint);
        } else {
          canvas.drawCircle(Offset(cityX, cityY), 5, cityGlowPaint);
          canvas.drawCircle(Offset(cityX, cityY), 2.5, cityPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(OptimizedGridPainter oldDelegate) {
    return oldDelegate.cellSize != cellSize ||
        oldDelegate.viewOffset != viewOffset ||
        oldDelegate.visibleCoords.length != visibleCoords.length ||
        oldDelegate.selectedCity != selectedCity;
  }
}
