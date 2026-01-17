import 'package:flutter/material.dart';
import 'package:opengrid_world/bridge/wasm_bridge.dart';
import 'package:opengrid_renderer/controller/wasm_world_controller.dart';

/// Debug overlay showing render stats
class DebugOverlay extends StatefulWidget {
  final WasmWorldController? controller;
  
  const DebugOverlay({super.key, this.controller});
  
  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  RenderStats? _stats;
  
  @override
  void initState() {
    super.initState();
    _startPolling();
  }
  
  void _startPolling() {
    Future.doWhile(() async {
      if (!mounted) return false;
      
      if (widget.controller != null) {
        try {
          final stats = widget.controller!.getStats();
          if (mounted) {
            setState(() => _stats = stats);
          }
        } catch (_) {}
      }
      
      await Future.delayed(const Duration(milliseconds: 100));
      return mounted;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            stats != null
              ? 'Chunks: ${stats.visibleChunks}/${stats.cachedChunks}'
              : 'Initializing...',
            style: const TextStyle(
              color: Color(0xFF00FF88),
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          if (stats != null) ...[
            Text(
              'Cities: ${stats.totalCities}',
              style: const TextStyle(
                color: Color(0xFF00FF88),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              'Zoom: ${stats.zoom.toStringAsFixed(1)}',
              style: const TextStyle(
                color: Color(0xFF00FF88),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ],
          const Text(
            'WASM Renderer',
            style: TextStyle(
              color: Color(0xFF888888),
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
