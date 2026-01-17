import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:async';
import 'package:opengrid_world/bridge/wasm_bridge.dart';

/// Controller for the WASM WorldRenderer
class WasmWorldController {
  final Object _renderer;
  
  WasmWorldController._(this._renderer);
  
  /// Create a new renderer on a canvas
  static Future<WasmWorldController> create(
    html.CanvasElement canvas,
    int worldSeed,
  ) async {
    // Wait for WASM to be ready
    await _waitForWasm();
    
    // Create renderer using the JS function
    final renderer = js_util.callMethod(
      html.window, 
      'createWorldRenderer', 
      [canvas, worldSeed]
    );
    
    return WasmWorldController._(renderer);
  }
  
  static Future<void> _waitForWasm() async {
    // Poll until the createWorldRenderer function exists
    for (int i = 0; i < 100; i++) {
      final ready = js_util.getProperty(html.window, 'wasmReady');
      final createFn = js_util.getProperty(html.window, 'createWorldRenderer');
      
      if (ready == true && createFn != null) {
        return;
      }
      
      await Future.delayed(const Duration(milliseconds: 50));
    }
    
    // Check for error
    final error = js_util.getProperty(html.window, 'wasmError');
    if (error != null) {
      throw Exception('WASM error: $error');
    }
    
    throw Exception('WASM initialization timeout - createWorldRenderer not available');
  }
  
  /// Pan camera by screen delta
  void pan(double dx, double dy) {
    js_util.callMethod(_renderer, 'pan', [dx, dy]);
  }
  
  /// Zoom at cursor position
  void zoomAt(double cursorX, double cursorY, double delta) {
    js_util.callMethod(_renderer, 'zoom_at', [cursorX, cursorY, delta]);
  }
  
  /// Set camera position directly
  void setCamera(double x, double y, double zoom) {
    js_util.callMethod(_renderer, 'set_camera', [x, y, zoom]);
  }
  
  /// Handle click - returns CityInfo if hit
  CityInfo? click(double x, double y) {
    final result = js_util.callMethod(_renderer, 'click', [x, y]);
    if (result == null) return null;
    return CityInfo.fromJs(result);
  }
  
  /// Get render stats
  RenderStats getStats() {
    final result = js_util.callMethod(_renderer, 'get_stats', []);
    return RenderStats.fromJs(result);
  }
  
  /// Render a single frame
  void render() {
    js_util.callMethod(_renderer, 'render', []);
  }
  
  /// Start render loop
  void start() {
    js_util.callMethod(_renderer, 'start', []);
  }
  
  /// Stop render loop
  void stop() {
    js_util.callMethod(_renderer, 'stop', []);
  }
  
  /// Check if running
  bool get isRunning {
    return js_util.callMethod(_renderer, 'is_running', []) as bool;
  }
}
