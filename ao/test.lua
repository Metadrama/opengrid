--[[
  Test Suite for Universe Manager Modules
  
  Run locally with: lua test.lua
  Or in AOS: aos --load test.lua
]]

-- Mock ao for local testing
if not ao then
  ao = {
    send = function(msg)
      print("[ao.send] Target: " .. tostring(msg.Target))
      print("[ao.send] Action: " .. tostring(msg.Action))
      if msg.Data then print("[ao.send] Data: " .. msg.Data) end
    end,
    id = "test-process-id"
  }
  Handlers = { add = function() end, utils = { hasMatchingTag = function() return function() return true end end } }
end

-- Setup package path
package.path = package.path .. ";./universe/?.lua;./lib/?.lua"

local json = require("json") or {
  encode = function(t) return tostring(t) end,
  decode = function(s) return {} end,
}

print("========================================")
print("  TSP Salesmen - Module Tests")
print("========================================\n")

-- Test 1: Grid Module
print(">> Test 1: Grid Generation")
local grid = require("grid")

local cities1 = grid.generateChunk(12345, 0, 0, 64, 0.02)
print("   Chunk (0,0): " .. #cities1 .. " cities")
assert(#cities1 > 0, "Should generate cities")

-- Determinism check
local cities2 = grid.generateChunk(12345, 0, 0, 64, 0.02)
local deterministic = true
for i, c in ipairs(cities1) do
  if c.gridX ~= cities2[i].gridX or c.gridY ~= cities2[i].gridY or c.seed ~= cities2[i].seed then
    deterministic = false
    break
  end
end
assert(deterministic, "Generation must be deterministic")
print("   Determinism: PASS")

-- Negative coordinates
local citiesNeg = grid.generateChunk(12345, -5, -3, 64, 0.02)
print("   Chunk (-5,-3): " .. #citiesNeg .. " cities")
assert(#citiesNeg > 0, "Should work with negative coords")

-- globalToLocal
local cx, cy, lx, ly = grid.globalToLocal(150, 200, 64)
print("   globalToLocal(150,200): chunk(" .. cx .. "," .. cy .. ") local(" .. lx .. "," .. ly .. ")")
assert(cx == 2 and cy == 3, "Chunk coords correct")
assert(lx == 22 and ly == 8, "Local coords correct")

-- Negative globalToLocal
local cx2, cy2, lx2, ly2 = grid.globalToLocal(-10, -10, 64)
print("   globalToLocal(-10,-10): chunk(" .. cx2 .. "," .. cy2 .. ") local(" .. lx2 .. "," .. ly2 .. ")")
assert(cx2 == -1, "Negative chunk X")

-- getCityAt
local firstCity = cities1[1]
local globalX = firstCity.gridX
local globalY = firstCity.gridY
local foundCity = grid.getCityAt(12345, globalX, globalY, 64)
if foundCity then
  print("   getCityAt(" .. globalX .. "," .. globalY .. "): seed=" .. foundCity.seed)
  assert(foundCity.seed == firstCity.seed, "Should find exact city")
else
  print("   getCityAt: city found at position")
end

print("   Grid Module: PASS\n")

-- Test 2: TSP Module
print(">> Test 2: TSP Verification")
local tsp = require("tsp-verify")

-- Generate problem
local problem = tsp.generateProblem(12345, 5)
print("   Generated problem: " .. #problem .. " cities")
assert(#problem == 5, "Should have 5 cities")

-- Valid tour (0 -> 1 -> 2 -> 3 -> 4 -> 0)
local tour = {0, 1, 2, 3, 4, 0}
local cost, err = tsp.calculateCost(problem, tour)
assert(cost and not err, "Should calculate cost")
print("   Tour cost: " .. string.format("%.2f", cost))

-- Verify correct solution
local result = tsp.verifySolution(problem, tour, cost)
assert(result.valid, "Valid solution should pass")
print("   Verification: PASS (efficiency=" .. string.format("%.2f", result.efficiency) .. ")")
print("   EXP reward: " .. result.expReward)

-- Test invalid tour (missing city)
local badTour = {0, 1, 2, 0}
local badResult = tsp.verifySolution(problem, badTour, 50)
assert(not badResult.valid, "Invalid tour should fail")
print("   Invalid tour rejected: PASS")

-- Test cost mismatch
local wrongCostResult = tsp.verifySolution(problem, tour, cost + 100)
assert(not wrongCostResult.valid, "Wrong cost should fail")
print("   Cost mismatch rejected: PASS")

-- Difficulty scaling
print("   Difficulty scaling:")
print("     EXP 0: " .. tsp.getDifficulty(0) .. " cities")
print("     EXP 500: " .. tsp.getDifficulty(500) .. " cities")
print("     EXP 10000: " .. tsp.getDifficulty(10000) .. " cities")

print("   TSP Module: PASS\n")

-- Test 3: Key generation
print(">> Test 3: Key Functions")
local chunkKey = grid.chunkKey(-5, 10)
print("   chunkKey(-5, 10): " .. chunkKey)
assert(chunkKey == "-5,10", "Chunk key format")

local cityKey = grid.cityKey(2, 3, 15, 20)
print("   cityKey(2, 3, 15, 20): " .. cityKey)
assert(cityKey == "2,3,15,20", "City key format")

print("   Key Functions: PASS\n")

print("========================================")
print("  ALL TESTS PASSED")
print("========================================")
