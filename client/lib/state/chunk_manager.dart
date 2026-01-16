import 'dart:math';
import 'dart:ui';

/// Represents a chunk coordinate in the infinite grid.
class ChunkCoord {
  final int x;
  final int y;

  const ChunkCoord(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChunkCoord && x == other.x && y == other.y;

  @override
  int get hashCode => x.hashCode ^ (y.hashCode << 16);

  @override
  String toString() => 'Chunk($x, $y)';
}

/// A city within a chunk.
class City {
  final double localX; // 0.0 - 1.0 within chunk
  final double localY;
  final int seed;

  const City(this.localX, this.localY, this.seed);
}

/// Data for a single chunk.
class ChunkData {
  final ChunkCoord coord;
  final List<City> cities;
  final DateTime loadedAt;

  ChunkData(this.coord, this.cities) : loadedAt = DateTime.now();
}

/// Manages chunk loading/unloading with LRU-style eviction.
class ChunkManager {
  static const int chunkSize = 64; // cells per chunk side
  static const int maxCachedChunks = 100;
  static const double cityDensity = 0.02; // ~2% of cells have cities

  final Map<ChunkCoord, ChunkData> _cache = {};
  final int worldSeed;

  ChunkManager({this.worldSeed = 42});

  /// Get visible chunks for a viewport.
  Set<ChunkCoord> getVisibleChunks(Rect viewport, double cellSize) {
    final chunkPixelSize = chunkSize * cellSize;
    
    final minCx = (viewport.left / chunkPixelSize).floor();
    final maxCx = (viewport.right / chunkPixelSize).ceil();
    final minCy = (viewport.top / chunkPixelSize).floor();
    final maxCy = (viewport.bottom / chunkPixelSize).ceil();

    final chunks = <ChunkCoord>{};
    for (int cx = minCx; cx <= maxCx; cx++) {
      for (int cy = minCy; cy <= maxCy; cy++) {
        chunks.add(ChunkCoord(cx, cy));
      }
    }
    return chunks;
  }

  /// Load a chunk (generates if not cached).
  ChunkData loadChunk(ChunkCoord coord) {
    if (_cache.containsKey(coord)) {
      return _cache[coord]!;
    }

    // Generate chunk
    final data = _generateChunk(coord);
    _cache[coord] = data;

    // Evict old chunks if over limit
    _evictIfNeeded();

    return data;
  }

  /// Evict chunks outside visible area + buffer.
  void evictOutsideView(Set<ChunkCoord> visible, {int buffer = 2}) {
    final toKeep = <ChunkCoord>{};
    for (final vc in visible) {
      for (int dx = -buffer; dx <= buffer; dx++) {
        for (int dy = -buffer; dy <= buffer; dy++) {
          toKeep.add(ChunkCoord(vc.x + dx, vc.y + dy));
        }
      }
    }
    _cache.removeWhere((coord, _) => !toKeep.contains(coord));
  }

  ChunkData _generateChunk(ChunkCoord coord) {
    // Deterministic PRNG based on world seed + chunk coord
    final chunkSeed = worldSeed ^ (coord.x * 73856093) ^ (coord.y * 19349663);
    final rng = Random(chunkSeed);

    final cities = <City>[];
    final numCells = chunkSize * chunkSize;
    final expectedCities = (numCells * cityDensity).round();

    for (int i = 0; i < expectedCities; i++) {
      final localX = rng.nextDouble();
      final localY = rng.nextDouble();
      final citySeed = rng.nextInt(1 << 30);
      cities.add(City(localX, localY, citySeed));
    }

    return ChunkData(coord, cities);
  }

  void _evictIfNeeded() {
    if (_cache.length <= maxCachedChunks) return;

    // Sort by load time, evict oldest
    final sorted = _cache.entries.toList()
      ..sort((a, b) => a.value.loadedAt.compareTo(b.value.loadedAt));

    final toRemove = sorted.take(_cache.length - maxCachedChunks);
    for (final entry in toRemove) {
      _cache.remove(entry.key);
    }
  }

  int get cachedChunkCount => _cache.length;
  Iterable<ChunkData> get chunks => _cache.values;
}
