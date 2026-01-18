import 'package:flutter/material.dart';

/// Main game screen - placeholder after JS interop scraping
class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          // Placeholder for WASM world (to be re-integrated)
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.grid_4x4, size: 64, color: Color(0xFF00FF88)),
                SizedBox(height: 16),
                Text(
                  'OPENGRID',
                  style: TextStyle(
                    color: Color(0xFF00FF88),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'World Core Ready',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
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

          // Seed Display
          const Positioned(
            bottom: 8,
            right: 8,
            child: Text(
              'LOCAL SEED: 42',
              style: TextStyle(
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
