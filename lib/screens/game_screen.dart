import 'package:flutter/material.dart';
import 'package:opengrid_renderer/widgets/wasm_world_view.dart';
import 'package:opengrid_world/widgets/city_tooltip.dart';
import 'package:opengrid_renderer/widgets/debug_overlay.dart';
import 'package:opengrid_world/bridge/wasm_bridge.dart';
import 'package:opengrid_renderer/controller/wasm_world_controller.dart';

/// Main game screen with WASM world and Flutter UI overlays
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  WasmWorldController? _controller;
  CityInfo? _selectedCity;

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
              onReady: (controller) {
                setState(() => _controller = controller);
              },
              onCitySelected: (city) {
                setState(() => _selectedCity = city);
              },
              onSelectionCleared: () {
                setState(() => _selectedCity = null);
              },
            ),
          ),

          // City tooltip (Flutter overlay)
          if (_selectedCity != null)
            Positioned(
              left: _selectedCity!.screenX + 15,
              top: _selectedCity!.screenY - 80,
              child: CityTooltip(city: _selectedCity!),
            ),

          // Debug HUD (Flutter overlay)
          Positioned(
            top: 8,
            left: 8,
            child: DebugOverlay(controller: _controller),
          ),

          // Title
          const Positioned(
            top: 8,
            right: 8,
            child: Text(
              'TSP SALESMEN',
              style: TextStyle(
                color: Color(0xFF00FF88),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
