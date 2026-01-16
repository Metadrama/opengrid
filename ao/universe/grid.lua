--[[
  Grid Generation Module
  
  Deterministic city generation from chunk coordinates.
  Uses LCG PRNG for cross-platform consistency with Dart/WASM.
  
  IMPORTANT: This algorithm MUST match client-side generation exactly.
  Both use the same seed formula and LCG parameters.
]]

local grid = {}

-- LCG parameters (matches Dart's Random class behavior)
local LCG_A = 1103515245
local LCG_C = 12345
local LCG_M = 2147483648  -- 2^31

-- Create deterministic RNG from seed
local function createRng(seed)
  local state = math.abs(seed) % LCG_M
  return {
    nextInt = function(self, max)
      state = (state * LCG_A + LCG_C) % LCG_M
      return state % max
    end,
    next = function(self)
      state = (state * LCG_A + LCG_C) % LCG_M
      return state
    end
  }
end

-- Compute chunk seed from world seed and coordinates
-- Must match: worldSeed ^ (coord.x * 73856093) ^ (coord.y * 19349663)
local function computeChunkSeed(worldSeed, chunkX, chunkY)
  local seed = worldSeed
  -- XOR with coordinate hashes (handle negative coordinates)
  local xHash = chunkX * 73856093
  local yHash = chunkY * 19349663
  
  -- Lua 5.3+ has native bitwise XOR
  if bit32 then
    seed = bit32.bxor(seed, xHash % (2^32))
    seed = bit32.bxor(seed, yHash % (2^32))
  else
    -- Fallback for environments without bit32
    seed = ((seed % (2^32)) + (xHash % (2^32)) + (yHash % (2^32))) % (2^32)
  end
  
  return math.abs(seed)
end

--[[
  Generate cities for a chunk.
  
  @param worldSeed number - World seed
  @param chunkX number - Chunk X coordinate (can be negative)
  @param chunkY number - Chunk Y coordinate (can be negative)
  @param chunkSize number - Cells per chunk side (default 64)
  @param density number - City density 0.0-1.0 (default 0.02)
  @return table[] - List of cities [{gridX, gridY, seed}, ...]
]]
function grid.generateChunk(worldSeed, chunkX, chunkY, chunkSize, density)
  chunkSize = chunkSize or 64
  density = density or 0.02
  
  local chunkSeed = computeChunkSeed(worldSeed, chunkX, chunkY)
  local rng = createRng(chunkSeed)
  
  local cities = {}
  local usedPositions = {}
  local numCells = chunkSize * chunkSize
  local expectedCities = math.floor(numCells * density)
  
  for _ = 1, expectedCities do
    local gridX = rng:nextInt(chunkSize)
    local gridY = rng:nextInt(chunkSize)
    local posKey = gridY * chunkSize + gridX
    
    if not usedPositions[posKey] then
      usedPositions[posKey] = true
      local citySeed = rng:next()
      cities[#cities + 1] = {
        gridX = gridX,
        gridY = gridY,
        seed = citySeed,
      }
    end
  end
  
  return cities
end

--[[
  Convert global grid position to chunk and local coordinates.
  
  @param globalX number - Global X coordinate
  @param globalY number - Global Y coordinate
  @param chunkSize number - Cells per chunk side
  @return chunkX, chunkY, localX, localY
]]
function grid.globalToLocal(globalX, globalY, chunkSize)
  chunkSize = chunkSize or 64
  
  local chunkX = math.floor(globalX / chunkSize)
  local chunkY = math.floor(globalY / chunkSize)
  
  -- Handle negative coordinates correctly
  local localX = globalX % chunkSize
  local localY = globalY % chunkSize
  if localX < 0 then localX = localX + chunkSize end
  if localY < 0 then localY = localY + chunkSize end
  
  return chunkX, chunkY, localX, localY
end

--[[
  Check if a city exists at a global position.
  
  @param worldSeed number - World seed
  @param globalX number - Global X coordinate
  @param globalY number - Global Y coordinate
  @param chunkSize number - Cells per chunk side
  @return table|nil - City data or nil if no city
]]
function grid.getCityAt(worldSeed, globalX, globalY, chunkSize)
  chunkSize = chunkSize or 64
  
  local chunkX, chunkY, localX, localY = grid.globalToLocal(globalX, globalY, chunkSize)
  local cities = grid.generateChunk(worldSeed, chunkX, chunkY, chunkSize)
  
  for _, city in ipairs(cities) do
    if city.gridX == localX and city.gridY == localY then
      return {
        gridX = city.gridX,
        gridY = city.gridY,
        seed = city.seed,
        chunkX = chunkX,
        chunkY = chunkY,
        globalX = globalX,
        globalY = globalY,
      }
    end
  end
  
  return nil
end

--[[
  Create chunk key string for indexing.
  
  @param chunkX number
  @param chunkY number
  @return string
]]
function grid.chunkKey(chunkX, chunkY)
  return string.format("%d,%d", chunkX, chunkY)
end

--[[
  Create city key string for indexing.
  
  @param chunkX number
  @param chunkY number
  @param gridX number
  @param gridY number
  @return string
]]
function grid.cityKey(chunkX, chunkY, gridX, gridY)
  return string.format("%d,%d,%d,%d", chunkX, chunkY, gridX, gridY)
end

return grid
