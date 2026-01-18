-- World Manager Process
-- Acts as the Registry and Authoritative Game Master

local json = require('json')

-- State
Salesmen = Salesmen or {}
Config = Config or {
  canRegister = true,
  worldSeed = 12345
}

-- Handlers
Handlers.add('Register', function(msg)
  if not Config.canRegister then
    msg.reply({Data = "Registration Closed", Status = "Error"})
    return
  end
  
  local pid = msg.From
  if Salesmen[pid] then
    msg.reply({Data = "Already Registered", Status = "Error"})
    return
  end
  
  Salesmen[pid] = {
    registeredAt = msg.Timestamp,
    score = 0,
    owner = msg.Owner
  }
  
  print("Registered salesman: " .. pid)
  msg.reply({Data = "Registered Successfully", Status = "Success"})
end)

Handlers.add('GetRegistry', function(msg)
  msg.reply({
    Data = json.encode({
      salesmen = Salesmen,
      config = Config
    })
  })
end)

Handlers.add('UpdateScore', function(msg)
  -- Only allow updates from trusted Oracle (e.g. self or specific verify process)
  -- For MVP, allow self-report for testing, but in prod this is insecure
  local pid = msg.From
  if Salesmen[pid] then
    local newScore = tonumber(msg.Data) or 0
    Salesmen[pid].score = newScore
    print("Updated score for " .. pid .. " to " .. newScore)
  end
end)
