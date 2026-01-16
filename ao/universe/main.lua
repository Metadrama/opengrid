--[[
  Universe Manager - Main Process
  
  Source of truth for:
  - Salesman positions and state
  - Spatial indexing for collision detection
  - City solve records
  
  Constraints:
  - MAX_SALESMEN: 10,000 (cap, plan sharding later)
  - INACTIVE_TIMEOUT: 86400 seconds (24 hours)
  - Memory budget: ~50MB
]]

local grid = require("grid")
local json = require("json")

-- Constants
local MAX_SALESMEN = 10000
local INACTIVE_TIMEOUT = 86400
local CHUNK_SIZE = 64
local WORLD_SEED = 12345

-- Initialize state (persists across messages)
State = State or {
  worldSeed = WORLD_SEED,
  chunkSize = CHUNK_SIZE,
  
  -- Salesman data: pid -> {x, y, exp, balance, lastActive}
  salesmen = {},
  salesmenCount = 0,
  
  -- Spatial index: "chunkX,chunkY" -> {pid1=true, pid2=true, ...}
  chunkIndex = {},
  
  -- Solved cities: "cx,cy,gx,gy" -> {solvedBy, solvedAt, expAwarded}
  solvedCities = {},
  
  -- Stats
  stats = {
    totalSpawns = 0,
    totalMoves = 0,
    totalSolves = 0,
  },
}

-- Helper: Get current timestamp
local function now()
  return os.time()
end

-- Helper: Update spatial index when salesman moves
local function updateChunkIndex(pid, oldX, oldY, newX, newY)
  local oldChunkX, oldChunkY = grid.globalToLocal(oldX, oldY, CHUNK_SIZE)
  local newChunkX, newChunkY = grid.globalToLocal(newX, newY, CHUNK_SIZE)
  
  local oldKey = grid.chunkKey(oldChunkX, oldChunkY)
  local newKey = grid.chunkKey(newChunkX, newChunkY)
  
  if oldKey ~= newKey then
    -- Remove from old chunk
    if State.chunkIndex[oldKey] then
      State.chunkIndex[oldKey][pid] = nil
      -- Clean up empty chunks
      if next(State.chunkIndex[oldKey]) == nil then
        State.chunkIndex[oldKey] = nil
      end
    end
    
    -- Add to new chunk
    if not State.chunkIndex[newKey] then
      State.chunkIndex[newKey] = {}
    end
    State.chunkIndex[newKey][pid] = true
  end
end

-- Helper: Add salesman to spatial index
local function addToChunkIndex(pid, x, y)
  local chunkX, chunkY = grid.globalToLocal(x, y, CHUNK_SIZE)
  local key = grid.chunkKey(chunkX, chunkY)
  
  if not State.chunkIndex[key] then
    State.chunkIndex[key] = {}
  end
  State.chunkIndex[key][pid] = true
end

-- Helper: Remove salesman from spatial index
local function removeFromChunkIndex(pid, x, y)
  local chunkX, chunkY = grid.globalToLocal(x, y, CHUNK_SIZE)
  local key = grid.chunkKey(chunkX, chunkY)
  
  if State.chunkIndex[key] then
    State.chunkIndex[key][pid] = nil
    if next(State.chunkIndex[key]) == nil then
      State.chunkIndex[key] = nil
    end
  end
end

-- Helper: Find collision at position
local function findCollision(excludePid, x, y)
  for pid, s in pairs(State.salesmen) do
    if pid ~= excludePid and s.x == x and s.y == y then
      return pid
    end
  end
  return nil
end

-- Garbage collection: Evict inactive salesmen
local function evictInactive()
  local timestamp = now()
  local evicted = {}
  
  for pid, s in pairs(State.salesmen) do
    if timestamp - s.lastActive > INACTIVE_TIMEOUT then
      evicted[#evicted + 1] = pid
    end
  end
  
  for _, pid in ipairs(evicted) do
    local s = State.salesmen[pid]
    removeFromChunkIndex(pid, s.x, s.y)
    State.salesmen[pid] = nil
    State.salesmenCount = State.salesmenCount - 1
  end
  
  return #evicted
end

-- Handler: Get chunk data
Handlers.add("GetChunk",
  Handlers.utils.hasMatchingTag("Action", "GetChunk"),
  function(msg)
    local chunkX = tonumber(msg.Tags.ChunkX)
    local chunkY = tonumber(msg.Tags.ChunkY)
    
    if not chunkX or not chunkY then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Data = json.encode({error = "ChunkX and ChunkY required"})
      })
      return
    end
    
    local cities = grid.generateChunk(State.worldSeed, chunkX, chunkY, CHUNK_SIZE)
    
    -- Mark solved cities
    for _, city in ipairs(cities) do
      local cityKey = grid.cityKey(chunkX, chunkY, city.gridX, city.gridY)
      local solved = State.solvedCities[cityKey]
      if solved then
        city.solved = true
        city.solvedBy = solved.solvedBy
      end
    end
    
    -- Get salesmen in this chunk
    local chunkKey = grid.chunkKey(chunkX, chunkY)
    local salesmenInChunk = {}
    if State.chunkIndex[chunkKey] then
      for pid, _ in pairs(State.chunkIndex[chunkKey]) do
        local s = State.salesmen[pid]
        if s then
          salesmenInChunk[#salesmenInChunk + 1] = {
            pid = pid,
            x = s.x,
            y = s.y,
            exp = s.exp,
          }
        end
      end
    end
    
    ao.send({
      Target = msg.From,
      Action = "ChunkData",
      Data = json.encode({
        chunkX = chunkX,
        chunkY = chunkY,
        cities = cities,
        salesmen = salesmenInChunk,
      })
    })
  end
)

-- Handler: Spawn salesman
Handlers.add("Spawn",
  Handlers.utils.hasMatchingTag("Action", "Spawn"),
  function(msg)
    local pid = msg.From
    
    -- Check if already spawned
    if State.salesmen[pid] then
      ao.send({
        Target = pid,
        Action = "Error",
        Data = json.encode({error = "Already spawned"})
      })
      return
    end
    
    -- Check capacity
    if State.salesmenCount >= MAX_SALESMEN then
      -- Try evicting inactive first
      local evicted = evictInactive()
      if State.salesmenCount >= MAX_SALESMEN then
        ao.send({
          Target = pid,
          Action = "Error",
          Data = json.encode({error = "Server at capacity", max = MAX_SALESMEN})
        })
        return
      end
    end
    
    local x = tonumber(msg.Tags.X) or 0
    local y = tonumber(msg.Tags.Y) or 0
    
    -- Create salesman
    State.salesmen[pid] = {
      x = x,
      y = y,
      exp = 0,
      balance = 0,
      lastActive = now(),
    }
    State.salesmenCount = State.salesmenCount + 1
    State.stats.totalSpawns = State.stats.totalSpawns + 1
    
    addToChunkIndex(pid, x, y)
    
    -- Check if spawned on a city
    local city = grid.getCityAt(State.worldSeed, x, y, CHUNK_SIZE)
    
    ao.send({
      Target = pid,
      Action = "Spawned",
      Data = json.encode({
        pid = pid,
        x = x,
        y = y,
        city = city,
      })
    })
  end
)

-- Handler: Move salesman
Handlers.add("Move",
  Handlers.utils.hasMatchingTag("Action", "Move"),
  function(msg)
    local pid = msg.From
    local salesman = State.salesmen[pid]
    
    if not salesman then
      ao.send({
        Target = pid,
        Action = "Error",
        Data = json.encode({error = "Not spawned"})
      })
      return
    end
    
    local direction = msg.Tags.Direction
    local dx, dy = 0, 0
    
    if direction == "north" then dy = -1
    elseif direction == "south" then dy = 1
    elseif direction == "east" then dx = 1
    elseif direction == "west" then dx = -1
    else
      ao.send({
        Target = pid,
        Action = "Error",
        Data = json.encode({error = "Invalid direction: " .. tostring(direction)})
      })
      return
    end
    
    local oldX, oldY = salesman.x, salesman.y
    local newX, newY = oldX + dx, oldY + dy
    
    -- Update position
    salesman.x = newX
    salesman.y = newY
    salesman.lastActive = now()
    State.stats.totalMoves = State.stats.totalMoves + 1
    
    -- Update spatial index
    updateChunkIndex(pid, oldX, oldY, newX, newY)
    
    -- Check collision
    local collisionPid = findCollision(pid, newX, newY)
    
    -- Check if on city
    local city = grid.getCityAt(State.worldSeed, newX, newY, CHUNK_SIZE)
    
    local response = {
      x = newX,
      y = newY,
      city = city,
    }
    
    if collisionPid then
      response.collision = {
        pid = collisionPid,
        exp = State.salesmen[collisionPid] and State.salesmen[collisionPid].exp or 0,
      }
    end
    
    ao.send({
      Target = pid,
      Action = "Moved",
      Data = json.encode(response)
    })
  end
)

-- Handler: Get salesman state
Handlers.add("GetState",
  Handlers.utils.hasMatchingTag("Action", "GetState"),
  function(msg)
    local targetPid = msg.Tags.Pid or msg.From
    local salesman = State.salesmen[targetPid]
    
    if not salesman then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Data = json.encode({error = "Salesman not found"})
      })
      return
    end
    
    ao.send({
      Target = msg.From,
      Action = "SalesmanState",
      Data = json.encode({
        pid = targetPid,
        x = salesman.x,
        y = salesman.y,
        exp = salesman.exp,
        balance = salesman.balance,
        lastActive = salesman.lastActive,
      })
    })
  end
)

-- Handler: Get universe stats
Handlers.add("GetStats",
  Handlers.utils.hasMatchingTag("Action", "GetStats"),
  function(msg)
    ao.send({
      Target = msg.From,
      Action = "UniverseStats",
      Data = json.encode({
        salesmenCount = State.salesmenCount,
        maxSalesmen = MAX_SALESMEN,
        totalSpawns = State.stats.totalSpawns,
        totalMoves = State.stats.totalMoves,
        totalSolves = State.stats.totalSolves,
        worldSeed = State.worldSeed,
        chunkSize = CHUNK_SIZE,
      })
    })
  end
)

-- Handler: Admin - Force GC
Handlers.add("EvictInactive",
  Handlers.utils.hasMatchingTag("Action", "EvictInactive"),
  function(msg)
    local evicted = evictInactive()
    ao.send({
      Target = msg.From,
      Action = "EvictResult",
      Data = json.encode({
        evicted = evicted,
        remaining = State.salesmenCount,
      })
    })
  end
)

return "Universe Manager v1.0 loaded"
