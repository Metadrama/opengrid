import 'package:flutter/material.dart';
import 'package:opengrid_renderer/widgets/wasm_world_view.dart';
import 'package:opengrid_renderer/widgets/debug_overlay.dart';
import 'package:opengrid_world/bridge/wasm_bridge.dart';
import 'package:opengrid_renderer/controller/wasm_world_controller.dart';
import '../services/ao_service.dart';
import '../services/salesman_registry.dart';
import '../services/salesman_sync_service.dart';

/// Main game screen with WASM world and Flutter UI overlays
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  WasmWorldController? _controller;
  RenderStats? _stats;
  
  // AO services
  final _registry = SalesmanRegistry();
  late final SalesmanSyncService _syncService;
  bool _aoConnected = false;

  @override
  void initState() {
    super.initState();
    _syncService = SalesmanSyncService(
      aoService: AOService(),
      registry: _registry,
    );
    _initRegistry();
  }
  
  Future<void> _initRegistry() async {
    await _registry.load();
    if (mounted) {
      setState(() {});
    }
  }
  
  void _onControllerReady(WasmWorldController controller) {
    setState(() => _controller = controller);
    
    // Start syncing salesman paths from AO
    _syncService.start((wasmData) {
      if (mounted && _controller != null) {
        _controller!.updateSalesmanPaths(wasmData);
        if (!_aoConnected) {
          setState(() => _aoConnected = true);
        }
      }
    });
  }

  @override
  void dispose() {
    _syncService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          // WASM-rendered world (full screen)
          Positioned.fill(
            child: WasmWorldView(
              worldSeed: 12345,
              onReady: _onControllerReady,
              onStats: (stats) {
                setState(() => _stats = stats);
              },
            ),
          ),

          // Debug HUD (Flutter overlay)
          Positioned(
            top: 8,
            left: 8,
            child: DebugOverlay(stats: _stats),
          ),

          // Title and AO status
          Positioned(
            top: 8,
            right: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'TSP SALESMEN',
                  style: TextStyle(
                    color: Color(0xFF00FF88),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _aoConnected ? Colors.greenAccent : Colors.orangeAccent,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _aoConnected ? 'AO Connected' : 'AO Connecting...',
                      style: TextStyle(
                        color: _aoConnected ? Colors.greenAccent : Colors.orangeAccent,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                if (_registry.isLoaded)
                  Text(
                    '${_registry.all.length} salesmen',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
