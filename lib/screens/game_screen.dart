import 'dart:async';
import 'package:flutter/material.dart';
import 'package:opengrid_renderer/widgets/wasm_world_view.dart';
import 'package:opengrid_renderer/widgets/debug_overlay.dart';
import 'package:opengrid_renderer/controller/wasm_world_controller.dart';
import 'package:opengrid_world/bridge/wasm_bridge.dart';
import '../services/world_service.dart';

/// Main game screen with WASM world and Flutter UI overlays
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  WasmWorldController? _controller;
  RenderStats? _stats;
  
  // World State
  int? _worldSeed;
  final _worldService = WorldService(); // Connects to localhost:3000
  String _status = 'Connecting to Server...';

  Timer? _salesmanTimer;

  @override
  void initState() {
    super.initState();
    _fetchWorld();
  }
  
  @override
  void dispose() {
    _salesmanTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchWorld() async {
    try {
      // 1. Fetch Authoritative Seed from Deno Server
      final seed = await _worldService.getWorldSeed();
      
      if (mounted) {
        setState(() {
          _worldSeed = seed;
          _status = 'World Loaded';
        });
        
        // 2. Start Polling Salesmen (Mocking Real-time AO)
        _startSalesmanSync();
      }
    } catch (e) {
      if (mounted) {
        // Show error but maybe allow retry?
        setState(() => _status = 'Connection Failed: Is server running?\n$e');
      }
    }
  }
  
  void _startSalesmanSync() {
    _salesmanTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      if (_controller != null && _controller!.isRunning) {
         try {
           final data = await _worldService.getSalesmen();
           if (data.isNotEmpty) {
             _controller!.updateSalesmanPaths(data);
           }
         } catch(e) {
           // Ignore poll errors to avoid spam
         }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          // WASM-rendered world (only when seed is ready)
          if (_worldSeed != null)
            Positioned.fill(
              child: WasmWorldView(
                worldSeed: _worldSeed!,
                onReady: (controller) {
                  setState(() => _controller = controller);
                },
                onStats: (stats) {
                  setState(() => _stats = stats);
                },
              ),
            )
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   const CircularProgressIndicator(color: Color(0xFF00FF88)),
                   const SizedBox(height: 16),
                   Text(
                     _status,
                     style: const TextStyle(color: Colors.white54),
                     textAlign: TextAlign.center,
                   ),
                   const SizedBox(height: 8),
                   if (_status.contains('Failed'))
                     ElevatedButton(
                       onPressed: _fetchWorld,
                       style: ElevatedButton.styleFrom(
                         backgroundColor: const Color(0xFF00FF88),
                         foregroundColor: Colors.black,
                       ),
                       child: const Text('RETRY'),
                     ),
                ],
              ),
            ),

          // Debug HUD (Flutter overlay) - only show when running
          if (_controller != null)
            Positioned(
              top: 8,
              left: 8,
              child: DebugOverlay(stats: _stats),
            ),

          // Title
          const Positioned(
            top: 8,
            right: 8,
            child: Text(
              'OPENGRID',
              style: TextStyle(
                color: Color(0xFF00FF88),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
          ),
          
          // Seed Display (Server Verified)
          if (_worldSeed != null)
            Positioned(
              bottom: 8,
              right: 8,
              child: Text(
                'SERVER SEED: $_worldSeed',
                 style: const TextStyle(
                  color: Colors.white24,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
