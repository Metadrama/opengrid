import 'dart:js_util' as js_util;

/// City info returned from WASM on click
class CityInfo {
  final int chunkX;
  final int chunkY;
  final int gridX;
  final int gridY;
  final int seed;
  final double screenX;
  final double screenY;
  
  CityInfo({
    required this.chunkX,
    required this.chunkY,
    required this.gridX,
    required this.gridY,
    required this.seed,
    required this.screenX,
    required this.screenY,
  });
  
  factory CityInfo.fromJs(Object jsObj) {
    return CityInfo(
      chunkX: js_util.getProperty(jsObj, 'chunk_x') as int,
      chunkY: js_util.getProperty(jsObj, 'chunk_y') as int,
      gridX: js_util.getProperty(jsObj, 'grid_x') as int,
      gridY: js_util.getProperty(jsObj, 'grid_y') as int,
      seed: js_util.getProperty(jsObj, 'seed') as int,
      screenX: (js_util.getProperty(jsObj, 'screen_x') as num).toDouble(),
      screenY: (js_util.getProperty(jsObj, 'screen_y') as num).toDouble(),
    );
  }
  
  String get seedHex => seed.toRadixString(16).toUpperCase().padLeft(8, '0');
}

/// Render stats from WASM
class RenderStats {
  final int visibleChunks;
  final int cachedChunks;
  final int totalCities;
  final double zoom;
  final double cameraX;
  final double cameraY;
  
  RenderStats({
    required this.visibleChunks,
    required this.cachedChunks,
    required this.totalCities,
    required this.zoom,
    required this.cameraX,
    required this.cameraY,
  });
  
  factory RenderStats.fromJs(Object jsObj) {
    return RenderStats(
      visibleChunks: js_util.getProperty(jsObj, 'visible_chunks') as int,
      cachedChunks: js_util.getProperty(jsObj, 'cached_chunks') as int,
      totalCities: js_util.getProperty(jsObj, 'total_cities') as int,
      zoom: (js_util.getProperty(jsObj, 'zoom') as num).toDouble(),
      cameraX: (js_util.getProperty(jsObj, 'camera_x') as num).toDouble(),
      cameraY: (js_util.getProperty(jsObj, 'camera_y') as num).toDouble(),
    );
  }
}
