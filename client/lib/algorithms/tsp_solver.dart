import 'dart:math';

/// TSP Problem city point.
class TspCity {
  final double x;
  final double y;
  final int index;

  const TspCity(this.x, this.y, this.index);
}

/// TSP Solution with tour and cost.
class TspSolution {
  final List<int> tour;
  final double cost;
  final String algorithm;
  final Duration solveTime;

  const TspSolution({
    required this.tour,
    required this.cost,
    required this.algorithm,
    required this.solveTime,
  });

  /// Efficiency compared to baseline (higher = better).
  double efficiency(double baselineCost) {
    if (cost <= 0) return 1.0;
    return baselineCost / cost;
  }
}

/// TSP Solver with multiple algorithms.
class TspSolver {
  /// LCG parameters (must match AO tsp-verify.lua).
  static const int _lcgA = 1103515245;
  static const int _lcgC = 12345;
  static const int _lcgM = 2147483648; // 2^31

  /// Generate TSP problem from city seed (deterministic).
  /// Must produce identical results to AO.
  static List<TspCity> generateProblem(int citySeed, int numCities) {
    numCities = numCities.clamp(5, 20);
    var state = citySeed.abs() % _lcgM;

    double nextFloat() {
      state = (state * _lcgA + _lcgC) % _lcgM;
      return state / _lcgM;
    }

    final cities = <TspCity>[];
    for (int i = 0; i < numCities; i++) {
      cities.add(TspCity(
        nextFloat() * 100,
        nextFloat() * 100,
        i,
      ));
    }

    return cities;
  }

  /// Calculate Euclidean distance between two cities.
  static double distance(TspCity a, TspCity b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    return sqrt(dx * dx + dy * dy);
  }

  /// Calculate total tour cost.
  static double calculateCost(List<TspCity> cities, List<int> tour) {
    if (tour.length < 2) return 0;

    double total = 0;
    for (int i = 0; i < tour.length - 1; i++) {
      total += distance(cities[tour[i]], cities[tour[i + 1]]);
    }
    return total;
  }

  /// Nearest Neighbor algorithm (greedy baseline).
  /// O(n²) complexity, typically ~25% above optimal.
  static TspSolution nearestNeighbor(List<TspCity> cities) {
    final stopwatch = Stopwatch()..start();
    final n = cities.length;
    if (n == 0) {
      return TspSolution(
        tour: [0, 0],
        cost: 0,
        algorithm: 'Nearest Neighbor',
        solveTime: stopwatch.elapsed,
      );
    }

    final visited = List<bool>.filled(n, false);
    final tour = <int>[0];
    visited[0] = true;

    while (tour.length < n) {
      final last = tour.last;
      var nearestIdx = -1;
      var minDist = double.infinity;

      for (int i = 0; i < n; i++) {
        if (!visited[i]) {
          final d = distance(cities[last], cities[i]);
          if (d < minDist) {
            minDist = d;
            nearestIdx = i;
          }
        }
      }

      if (nearestIdx >= 0) {
        visited[nearestIdx] = true;
        tour.add(nearestIdx);
      }
    }

    tour.add(0); // Return to start
    stopwatch.stop();

    return TspSolution(
      tour: tour,
      cost: calculateCost(cities, tour),
      algorithm: 'Nearest Neighbor',
      solveTime: stopwatch.elapsed,
    );
  }

  /// 2-opt improvement heuristic.
  /// Iteratively reverses segments to reduce tour length.
  static TspSolution twoOpt(List<TspCity> cities, List<int> initialTour) {
    final stopwatch = Stopwatch()..start();
    var bestTour = List<int>.from(initialTour);
    var bestCost = calculateCost(cities, bestTour);
    var improved = true;

    while (improved) {
      improved = false;

      for (int i = 1; i < bestTour.length - 2; i++) {
        for (int j = i + 1; j < bestTour.length - 1; j++) {
          // Calculate delta without full recalculation
          final delta = _twoOptDelta(cities, bestTour, i, j);

          if (delta < -0.0001) {
            bestTour = _twoOptSwap(bestTour, i, j);
            bestCost += delta;
            improved = true;
          }
        }
      }
    }

    stopwatch.stop();

    return TspSolution(
      tour: bestTour,
      cost: calculateCost(cities, bestTour), // Recalculate for precision
      algorithm: '2-opt',
      solveTime: stopwatch.elapsed,
    );
  }

  /// Calculate the change in tour length for a 2-opt swap.
  static double _twoOptDelta(
      List<TspCity> cities, List<int> tour, int i, int j) {
    final a = cities[tour[i - 1]];
    final b = cities[tour[i]];
    final c = cities[tour[j]];
    final d = cities[tour[j + 1]];

    // Original edges: a-b and c-d
    // New edges: a-c and b-d
    final before = distance(a, b) + distance(c, d);
    final after = distance(a, c) + distance(b, d);

    return after - before;
  }

  /// Perform 2-opt swap: reverse segment from i to j.
  static List<int> _twoOptSwap(List<int> tour, int i, int j) {
    final result = List<int>.from(tour);
    // Reverse the segment
    var left = i;
    var right = j;
    while (left < right) {
      final temp = result[left];
      result[left] = result[right];
      result[right] = temp;
      left++;
      right--;
    }
    return result;
  }

  /// Solve TSP using best available method.
  /// Combines Nearest Neighbor + 2-opt.
  static TspSolution solve(List<TspCity> cities) {
    final stopwatch = Stopwatch()..start();

    // Start with Nearest Neighbor
    final nnSolution = nearestNeighbor(cities);

    // Improve with 2-opt
    final optimized = twoOpt(cities, nnSolution.tour);

    stopwatch.stop();

    return TspSolution(
      tour: optimized.tour,
      cost: optimized.cost,
      algorithm: 'NN + 2-opt',
      solveTime: stopwatch.elapsed,
    );
  }

  /// Get difficulty (number of cities) based on EXP.
  static int getDifficulty(int exp) {
    if (exp < 100) return 5;
    if (exp < 500) return 7;
    if (exp < 2000) return 10;
    if (exp < 10000) return 15;
    return 20;
  }

  /// Calculate baseline cost (sequential tour: 0-1-2-...-n-0).
  static double baselineCost(List<TspCity> cities) {
    final tour = <int>[];
    for (int i = 0; i < cities.length; i++) {
      tour.add(i);
    }
    tour.add(0);
    return calculateCost(cities, tour);
  }
}
