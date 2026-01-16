# Feasibility Assessment: TSP Salesmen on AO

**Date:** 2026-01-17
**Subject:** Technical & Economic Viability Analysis
**Status:** PASSED (with considerations)

## 1. Technical Feasibility (AO Network)

### 1.1 Process Architecture (PASSED)
The proposed Actor Model (Universe Manager, Salesman, Bank) maps 1:1 with AO's hyper-parallel architecture.
- **Scalability:** AO can comfortably handle N independent Salesman processes.
- **Compute:** Off-chain compute is sufficient for TSP verification (O(N) for validity/cost checks).
- **State:** Procedural generation allows for an infinite grid without massive storage costs; only seed paths and modified states (cities) need tracking.

### 1.2 Latency & Synchronization (CAUTION)
AO message passing is asynchronous.
- **Risk:** "PVP Collisions" rely on race conditions. If Agents A and B move to City X simultaneously, message ordering by the Universe Manager (CRANK) effectively resolves this (first message processed wins priority).
- **Mitigation:** The "Tick-based" approach mentioned in mitigations is the correct solution. The Universe Manager should enforce a `cooldown` or `tick` to bundle state updates, preventing high-frequency spam wars.

### 1.3 On-Chain Verification (PASSED)
The logic to verify `validity` and `cost` is computationally cheap:
- **Validity:** Check for duplicate indices and completeness (Set/Map check).
- **Cost:** Sum Euclidean distances.
- **Conclusion:** Entirely feasible within Lua instructions limit.

## 2. Economic Feasibility

### 2.1 Sustainability (PASSED)
The model `Σ(fees) >= Σ(rewards)` is mathematically sound **provided** the fee tuning is aggressive enough initially.
- **Treasury:** Separation of `Universe Manager` logic from `Central Bank` logic is excellent for security.
- **Token:** Using $AR eliminates the "death spiral" risk of custom game tokens.

### 2.2 Attack Vectors (WARNING)
- **Sybil Solution Farms:** Players spawning 1000 agents to solve trivial TSPs for guaranteed profit.
- **Fix:** "Quality-weighted" rewards must be strict. If a TSP is trivial, the EXP/Reward must be negligible. Consider a "Difficulty Multiplier" based on the randomness of the city layout.

## 3. Gameplay Mechanics

### 3.1 Fun Factor
- **Core Loop:** Navigation + Optimization is engaging for distinct player types (Explorers vs. Optimizers).
- **PVP:** The "Dark Forest" collision mechanic adds necessary tension.

## Conclusion
The project is **FEASIBLE**. The architecture leverages AO's strengths (parallel actors) while respecting its constraints (async messaging).

---

# Agent Categorization

We categorize the system agents (AO Processes) and the conceptual development agents.

## A. System Agents (AO Processes)

These are the autonomous entities live on the network.

### 1. The Arbiter Agents (Infrastructure)
*Singletons that maintain truth.*
- **Universe Manager (UM)**: The Physics Engine. Handles grid generation, movement validation, and collision detection.
- **Central Bank (CB)**: The Treasury. Handles interaction with the AR token, minting internal credits (if any), and distributing payouts.

### 2. The Player Agents (Salesmen)
*Multi-instanced, user-owned processes.*
To add depth, we categorize Salesmen into **Archetypes** based on their logic/stats (even if stats are implicit in code):
- **The Mapper (Explorer)**: Prioritizes movement speed and vision radius. Goal: Find high-density city clusters.
- **The Solver (Mathematician)**: Prioritizes compute efficiency. Goal: Submit highly optimized tours for maximum EXP yield per city.
- **The Raider (PVP)**: Prioritizes aggressive positioning. Goal: Camp typically high-value hubs to intercept Solvers.

## B. Development Agents (Roles)

For the execution of the POC, we define these logical roles:
1.  **Architect (Lua/AO)**: Core process logic, inter-process communication (IPC) standards.
2.  **Economist**: Fee/Reward curve tuning using simulation.
3.  **Cartographer (WASM/Frontend)**: Chunk rendering and procedural generation algorithms.

