-- universe.lua
-- Manager of the OpenGrid world state and agents

local json = require("json")

Agents = Agents or {}

-- Register an agent
Handlers.add(
  "Register",
  Handlers.utils.hasMatchingTag("Action", "Register"),
  function (msg)
    Agents[msg.From] = {
      Id = msg.From,
      RegisteredAt = msg.Timestamp
    }
    print("Agent registered: " .. msg.From)
    ao.send({ Target = msg.From, Action = "Registered" })
  end
)

-- Broadcast world updates (Simplified)
Handlers.add(
  "Broadcast",
  Handlers.utils.hasMatchingTag("Action", "Tick"),
  function (msg)
    -- In a real AOS app, this might be triggered by a Cron or specific message
    -- For now, it's a placeholder for world-state distribution
  end
)
