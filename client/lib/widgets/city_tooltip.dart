import 'package:flutter/material.dart';
import '../wasm/wasm_bridge.dart';

/// Tooltip showing city/TSP info
class CityTooltip extends StatelessWidget {
  final CityInfo city;

  const CityTooltip({super.key, required this.city});

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
            'Chunk: (${city.chunkX}, ${city.chunkY})',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            'Grid: (${city.gridX}, ${city.gridY})',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            'TSP Seed: ${city.seedHex}',
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
