-- salesman.lua (Path-Based Version)
-- Autonomous agent that computes TSP routes and provides waypoints for frontend rendering

local json = require("json")

-- State
Position = Position or { x = 0, y = 0 }
Color = Color or 0xFF5500
Id = Id or 0
CurrentPath = CurrentPath or nil  -- Array of {x, y, arrivalTime}
PathIndex = PathIndex or 0
Status = Status or "idle"
Speed = Speed or 10.0  -- units per second

-- Nearby cities (will be set by Universe or Init)
Cities = Cities or {}

-- TSP Solver (Nearest Neighbor for MVP)
function solveTSP(startPos, cities)
  local path = {}
  local unvisited = {}
  for i, city in ipairs(cities) do
    table.insert(unvisited, { x = city.x, y = city.y, name = city.name })
  end
  
  local current = { x = startPos.x, y = startPos.y }
  local time = 0
  
  -- Add starting position as first waypoint
  table.insert(path, {
    x = current.x,
    y = current.y,
    arrivalTime = 0
  })
  
  while #unvisited > 0 do
    -- Find nearest city
    local nearestIdx = 1
    local nearestDist = math.huge
    
    for i, city in ipairs(unvisited) do
      local dx = city.x - current.x
      local dy = city.y - current.y
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist < nearestDist then
        nearestDist = dist
        nearestIdx = i
      end
    end
    
    -- Add to path
    local next = table.remove(unvisited, nearestIdx)
    time = time + (nearestDist / Speed)
    table.insert(path, {
      x = next.x,
      y = next.y,
      arrivalTime = time
    })
    current = next
  end
  
  return path
end

-- Handler: Plan New Route
Handlers.add(
  "PlanRoute",
  Handlers.utils.hasMatchingTag("Action", "PlanRoute"),
  function (msg)
    local data = json.decode(msg.Data)
    Cities = data.cities or Cities
    
    -- Solve TSP from current position
    CurrentPath = solveTSP(Position, Cities)
    PathIndex = 1
    Status = "traveling"
    
    print("Planned route with " .. #CurrentPath .. " waypoints")
    
    msg.reply({
      Data = json.encode({
        path = CurrentPath,
        status = "route_planned",
        totalTime = CurrentPath[#CurrentPath].arrivalTime
      })
    })
  end
)

-- Handler: Get State (returns current path for rendering)
Handlers.add(
  "GetState",
  Handlers.utils.hasMatchingTag("Action", "GetState"),
  function (msg)
    msg.reply({
      Data = json.encode({
        id = Id,
        color = Color,
        position = Position,
        path = CurrentPath,
        pathIndex = PathIndex,
        status = Status,
        speed = Speed
      })
    })
  end
)

-- Handler: Cron Tick (advance along path - for AO state tracking)
Handlers.add(
  "CronTick",
  Handlers.utils.hasMatchingTag("Action", "Cron"),
  function (msg)
    if Status == "traveling" and CurrentPath and PathIndex < #CurrentPath then
      PathIndex = PathIndex + 1
      Position = {
        x = CurrentPath[PathIndex].x,
        y = CurrentPath[PathIndex].y
      }
      
      if PathIndex >= #CurrentPath then
        Status = "route_complete"
        print("Route completed! ID: " .. Id)
        
        -- Request new cities from Universe (future feature)
        -- ao.send({ Target = UniverseId, Action = "RequestCities" })
      end
    end
  end
)

-- Handler: Init
Handlers.add(
  "Init",
  Handlers.utils.hasMatchingTag("Action", "Init"),
  function (msg)
    local data = json.decode(msg.Data)
    Position = data.position or Position
    Color = data.color or Color
    Id = data.id or Id
    Speed = data.speed or Speed
    Cities = data.cities or Cities
    
    print("Salesman initialized! ID: " .. Id)
    
    msg.reply({
      Data = json.encode({
        status = "initialized",
        id = Id
      })
    })
  end
)

-- Handler: SetCities (for Universe to update available cities)
Handlers.add(
  "SetCities",
  Handlers.utils.hasMatchingTag("Action", "SetCities"),
  function (msg)
    local data = json.decode(msg.Data)
    Cities = data.cities or Cities
    print("Cities updated! Count: " .. #Cities)
  end
)
