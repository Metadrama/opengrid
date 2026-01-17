import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:opengrid_world/bridge/wasm_bridge.dart';
import '../controller/wasm_world_controller.dart';

/// Widget that embeds the WASM world renderer
class WasmWorldView extends StatefulWidget {
  final int worldSeed;
  final void Function(WasmWorldController)? onReady;
  
  const WasmWorldView({
    super.key,
    required this.worldSeed,
    this.onReady,
  });
  
  @override
  State<WasmWorldView> createState() => _WasmWorldViewState();
}

class _WasmWorldViewState extends State<WasmWorldView> {
  static const String _viewType = 'opengrid-wasm-canvas';
  static bool _registered = false;
  
  late html.CanvasElement _canvas;
  WasmWorldController? _controller;
  bool _initialized = false;
  String? _error;
  
  // For requestAnimationFrame loop
  int? _animationFrameId;
  
  @override
  void initState() {
    super.initState();
    _setupCanvas();
    _initWasm();
  }
  
  void _setupCanvas() {
    _canvas = html.CanvasElement()
      ..id = 'world-canvas-${DateTime.now().millisecondsSinceEpoch}'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'block';
    
    final viewId = 'opengrid-wasm-canvas-${widget.worldSeed}';
    
    if (!_registered) {
      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int id) => _canvas,
      );
      _registered = true;
    }
  }
  
  Future<void> _initWasm() async {
    try {
      _controller = await WasmWorldController.create(_canvas, widget.worldSeed);
      _controller!.start();
      
      // Start render loop
      _startRenderLoop();
      
      setState(() => _initialized = true);
      widget.onReady?.call(_controller!);
    } catch (e) {
      setState(() => _error = e.toString());
      print('WASM init failed: $e');
    }
  }
  
  void _startRenderLoop() {
    void loop(num timestamp) {
      if (!mounted || _controller == null) return;
      
      _controller!.render();
      _animationFrameId = html.window.requestAnimationFrame(loop);
    }
    
    _animationFrameId = html.window.requestAnimationFrame(loop);
  }
  
  @override
  void dispose() {
    if (_animationFrameId != null) {
      html.window.cancelAnimationFrame(_animationFrameId!);
    }
    _controller?.stop();
    super.dispose();
  }
  
  void _handlePan(DragUpdateDetails details) {
    _controller?.pan(details.delta.dx, details.delta.dy);
  }
  
  void _handleScroll(PointerScrollEvent event) {
    _controller?.zoomAt(
      event.localPosition.dx,
      event.localPosition.dy,
      -event.scrollDelta.dy * 0.001,
    );
  }
  
  
  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Text(
          'WASM Error: $_error',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _handleScroll(event);
        }
      },
      child: GestureDetector(
        onPanUpdate: _handlePan,
        child: const HtmlElementView(viewType: _viewType),
      ),
    );
  }
}
