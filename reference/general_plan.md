# TSP Salesmen - Implementation Plan

## Phase 1: The Core Grid (PoC)
**Goal:** Spawn a process, move it on a grid, and verify a TSP solution.

### 1. Project Structure
```text
tsp-salesman/
├── ao/
│   ├── universe/
│   │   ├── main.lua       <-- Universe Manager Entry
│   │   ├── grid.lua       <-- Procedural Gen & State
│   │   └── interactions.lua <-- Move/Collision Logic
│   ├── salesman/
│   │   ├── main.lua       <-- Salesman Agent Entry
│   │   ├── navigation.lua <-- Pathfinding Stubs
│   │   └── solver.lua     <-- TSP Logic (Lua)
│   └── lib/
│       ├── tsp-verify.lua <-- Shared Verification Logic
│       └── utils.lua
├── client/                <-- (Later) Flutter/Web
└── tests/
    └── simulation.js      <-- AOS Simulation Script
```

### 2. Universe Manager (UM) Implementation
- [ ] **State**: `Grid` table (sparse map of modified chunks).
- [ ] **Handler: `Spawn`**: Accept generic payment dummy, return `pid`.
- [ ] **Handler: `Move`**: Update coordinates. Check collision.
- [ ] **Module: `GridGen`**: Deterministic PRNG based on coordinates to generate City locations.

### 3. Salesman Agent Implementation
- [ ] **State**: `Position`, `Inventory` (EXP).
- [ ] **Action: `AutoMove`**: Simple logic to ping UM for movement.
- [ ] **Action: `Solve`**: When arriving at a city, read `CitySeed`, run local TSP solver (Nearest Neighbor or generic), submit tour.

### 4. Verification Logic
- [ ] Implement `verify_tour(cities, tour)` in pure Lua.
- [ ] Calculate Euclidean distance verification.

## Phase 2: The Economy (Bank)
**Goal:** Connect AR flows and EXP tracking.

### 1. Central Bank Process
- [ ] **Token Standard**: Implement `ao-20` (or similar) interface for internal credits if needed, or simpler direct AR handling.
- [ ] **Handler: `Deposit`**: Receive AR, credit Universe Balance.
- [ ] **Handler: `Payout`**: Verify `UM` signed success message, send AR to Salesman.

### 2. PVP Resolution
- [ ] **Collision Logic**:
    - Trigger `CollisionEvent`.
    - Lock movement for involved PIDs.
    - Wait for `SolutionSubmission` from both.
    - Compare costs -> Distribute Loot.

## Risks & Critical Path
1.  **RNG Determinism**: Lua's `math.random` must be seeded consistently across network nodes for verification. We must use a custom PRNG library (e.g., LCG or PCG) to ensure `hash(coord) -> same cities` everywhere.
2.  **Gas/Compute Limits**: Large TSPs (N>20) might hit instruction limits if processed naïvely. We will cap initial Cities to N=10 for PoC.
