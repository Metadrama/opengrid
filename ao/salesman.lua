-- Salesman Agent
-- Autonomous agent that moves between cities

local json = require('json')

-- State
State = State or {
  position = {x = 0, y = 0},
  target = {x = 100, y = 100}, -- Default target
  path = {},
  status = "Idle",
  speed = 5
}

-- Handlers
Handlers.add('GetState', function(msg)
  msg.reply({
    Data = json.encode(State)
  })
end)

Handlers.add('SetTarget', function(msg)
  local data = json.decode(msg.Data)
  State.target = {x = data.x, y = data.y}
  State.status = "Moving"
  print("New Target: " .. State.target.x .. ", " .. State.target.y)
end)

Handlers.add('Tick', function(msg)
  -- Simple movement logic towards target
  local dx = State.target.x - State.position.x
  local dy = State.target.y - State.position.y
  local dist = math.sqrt(dx*dx + dy*dy)
  
  if dist < State.speed then
    State.position.x = State.target.x
    State.position.y = State.target.y
    State.status = "Arrived"
  else
    local angle = math.atan(dy, dx)
    State.position.x = State.position.x + math.cos(angle) * State.speed
    State.position.y = State.position.y + math.sin(angle) * State.speed
  end
  
  -- print("Pos: " .. State.position.x .. ", " .. State.position.y)
end)

-- Cron Job (Simulated for now, would use Cron Handler in real AO)
Handlers.add('Cron', function(msg)
  Handlers.utils.reply("Tick")(msg) 
end)
