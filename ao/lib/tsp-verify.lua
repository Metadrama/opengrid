--[[
  TSP Verification Module
  
  Verifies Travelling Salesman Problem solutions.
  - Cost verification is O(n)
  - Generates reproducible problems from city seeds
  - Calculates efficiency scores for EXP rewards
]]

local tsp = {}

-- Calculate Euclidean distance
local function distance(x1, y1, x2, y2)
  local dx = x2 - x1
  local dy = y2 - y1
  return math.sqrt(dx * dx + dy * dy)
end

-- LCG for problem generation (must match grid.lua)
local function createRng(seed)
  local state = math.abs(seed) % 2147483648
  return {
    nextFloat = function(self)
      state = (state * 1103515245 + 12345) % 2147483648
      return state / 2147483648
    end
  }
end

--[[
  Generate TSP problem from a city seed.
  
  @param citySeed number - Seed from city data
  @param numCities number - Number of cities (5-20, scales with difficulty)
  @return table[] - List of city positions [{x, y}, ...]
]]
function tsp.generateProblem(citySeed, numCities)
  numCities = numCities or 10
  numCities = math.max(5, math.min(20, numCities))
  
  local rng = createRng(citySeed)
  local cities = {}
  
  for i = 1, numCities do
    cities[i] = {
      x = rng:nextFloat() * 100,
      y = rng:nextFloat() * 100,
    }
  end
  
  return cities
end

--[[
  Calculate tour cost.
  
  @param cities table[] - List of {x, y} positions
  @param tour number[] - City indices (0-indexed, starts and ends at same city)
  @return number|nil, string|nil - Cost or nil with error message
]]
function tsp.calculateCost(cities, tour)
  if #tour < 2 then
    return nil, "Tour too short"
  end
  
  local totalCost = 0
  
  for i = 1, #tour - 1 do
    local fromIdx = tour[i] + 1  -- Convert to 1-indexed
    local toIdx = tour[i + 1] + 1
    
    if fromIdx < 1 or fromIdx > #cities then
      return nil, "Invalid from index: " .. (fromIdx - 1)
    end
    if toIdx < 1 or toIdx > #cities then
      return nil, "Invalid to index: " .. (toIdx - 1)
    end
    
    local from = cities[fromIdx]
    local to = cities[toIdx]
    totalCost = totalCost + distance(from.x, from.y, to.x, to.y)
  end
  
  return totalCost
end

--[[
  Verify a TSP solution.
  
  @param cities table[] - Problem cities
  @param tour number[] - Submitted tour (0-indexed)
  @param claimedCost number - Cost claimed by submitter
  @return table - {valid, error?, actualCost?, efficiency?}
]]
function tsp.verifySolution(cities, tour, claimedCost)
  local n = #cities
  
  -- Must visit all cities plus return
  if #tour ~= n + 1 then
    return {
      valid = false,
      error = string.format("Tour length %d, expected %d", #tour, n + 1)
    }
  end
  
  -- Must start and end at same city
  if tour[1] ~= tour[#tour] then
    return {
      valid = false,
      error = "Tour must return to starting city"
    }
  end
  
  -- Check all cities visited exactly once
  local visited = {}
  for i = 1, #tour - 1 do
    local cityIdx = tour[i]
    
    if cityIdx < 0 or cityIdx >= n then
      return {
        valid = false,
        error = "Invalid city index: " .. cityIdx
      }
    end
    
    if visited[cityIdx] then
      return {
        valid = false,
        error = "City " .. cityIdx .. " visited more than once"
      }
    end
    visited[cityIdx] = true
  end
  
  -- Verify all cities covered
  local visitedCount = 0
  for _ in pairs(visited) do
    visitedCount = visitedCount + 1
  end
  
  if visitedCount ~= n then
    return {
      valid = false,
      error = string.format("Only %d of %d cities visited", visitedCount, n)
    }
  end
  
  -- Calculate actual cost
  local actualCost, err = tsp.calculateCost(cities, tour)
  if err then
    return {valid = false, error = err}
  end
  
  -- Verify claimed cost (tolerance for floating point)
  local tolerance = 0.01
  if math.abs(actualCost - claimedCost) > tolerance then
    return {
      valid = false,
      error = "Cost mismatch",
      actualCost = actualCost,
      claimedCost = claimedCost,
    }
  end
  
  -- Calculate efficiency (baseline = sequential tour)
  local baselineTour = {}
  for i = 0, n - 1 do
    baselineTour[i + 1] = i
  end
  baselineTour[n + 1] = 0
  
  local baselineCost = tsp.calculateCost(cities, baselineTour)
  
  local efficiency = 1.0
  if actualCost > 0 then
    efficiency = baselineCost / actualCost
  end
  
  -- EXP reward scales with efficiency and problem size
  local baseExp = 10 * n  -- 10 EXP per city
  local expReward = math.floor(baseExp * efficiency)
  
  return {
    valid = true,
    actualCost = actualCost,
    efficiency = efficiency,
    expReward = expReward,
  }
end

--[[
  Get problem difficulty based on salesman EXP.
  Higher EXP = more cities in TSP problems.
  
  @param exp number - Salesman experience
  @return number - Number of cities (5-20)
]]
function tsp.getDifficulty(exp)
  if exp < 100 then return 5
  elseif exp < 500 then return 7
  elseif exp < 2000 then return 10
  elseif exp < 10000 then return 15
  else return 20
  end
end

return tsp
