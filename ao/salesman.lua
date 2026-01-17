-- salesman.lua
-- Autonomous agent that moves between cities and solves TSPs

local json = require("json")

-- State
Position = Position or { x = 0, y = 0 }
Target = Target or nil
Speed = 0.1
Status = "idle"

-- Handlers
-- 1. Heartbeat/Cron for autonomous movement
Handlers.add(
  "CronTick",
  Handlers.utils.hasMatchingTag("Action", "Cron"),
  function (msg)
    if Status == "moving" and Target then
      -- Move towards target
      local dx = Target.x - Position.x
      local dy = Target.y - Position.y
      local dist = math.sqrt(dx^2 + dy^2)
      
      if dist < Speed then
        Position.x = Target.x
        Position.y = Target.y
        Status = "arrived"
        Target = nil
        print("Arrived at target")
      else
        Position.x = Position.x + (dx / dist) * Speed
        Position.y = Position.y + (dy / dist) * Speed
      end
    end
  end
)

-- 2. Set Target from Client/Universe
Handlers.add(
  "SetTarget",
  Handlers.utils.hasMatchingTag("Action", "SetTarget"),
  function (msg)
    local target = json.decode(msg.Data)
    Target = target
    Status = "moving"
    print("New target set: " .. msg.Data)
  end
)

-- 3. Get State
Handlers.add(
  "GetState",
  Handlers.utils.hasMatchingTag("Action", "GetState"),
  function (msg)
    ao.send({
      Target = msg.From,
      Action = "StateUpdate",
      Data = json.encode({
        Position = Position,
        Status = Status,
        Target = Target
      })
    })
  end
)
