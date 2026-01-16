--[[
  Interactions Module - TSP Solving Handler
  
  Adds handler for solving TSP problems at cities.
  Integrates with Universe Manager state.
]]

local grid = require("grid")
local tsp = require("lib.tsp-verify")
local json = require("json")

-- Handler: Solve TSP at current position
Handlers.add("SolveTSP",
  Handlers.utils.hasMatchingTag("Action", "SolveTSP"),
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
    
    -- Check if on a city
    local city = grid.getCityAt(State.worldSeed, salesman.x, salesman.y, State.chunkSize)
    
    if not city then
      ao.send({
        Target = pid,
        Action = "Error",
        Data = json.encode({error = "Not on a city"})
      })
      return
    end
    
    -- Check if already solved
    local cityKey = grid.cityKey(city.chunkX, city.chunkY, city.gridX, city.gridY)
    if State.solvedCities[cityKey] then
      ao.send({
        Target = pid,
        Action = "Error",
        Data = json.encode({
          error = "City already solved",
          solvedBy = State.solvedCities[cityKey].solvedBy,
        })
      })
      return
    end
    
    -- Parse solution
    local tour = json.decode(msg.Tags.Tour or "[]")
    local claimedCost = tonumber(msg.Tags.ClaimedCost)
    
    if not tour or #tour == 0 then
      ao.send({
        Target = pid,
        Action = "Error",
        Data = json.encode({error = "Tour required"})
      })
      return
    end
    
    if not claimedCost then
      ao.send({
        Target = pid,
        Action = "Error",
        Data = json.encode({error = "ClaimedCost required"})
      })
      return
    end
    
    -- Generate problem and verify
    local difficulty = tsp.getDifficulty(salesman.exp)
    local cities = tsp.generateProblem(city.seed, difficulty)
    local result = tsp.verifySolution(cities, tour, claimedCost)
    
    if not result.valid then
      ao.send({
        Target = pid,
        Action = "SolveRejected",
        Data = json.encode({
          error = result.error,
          actualCost = result.actualCost,
          claimedCost = result.claimedCost,
        })
      })
      return
    end
    
    -- Record solve
    State.solvedCities[cityKey] = {
      solvedBy = pid,
      solvedAt = os.time(),
      expAwarded = result.expReward,
    }
    
    -- Award EXP
    salesman.exp = salesman.exp + result.expReward
    salesman.lastActive = os.time()
    State.stats.totalSolves = State.stats.totalSolves + 1
    
    ao.send({
      Target = pid,
      Action = "SolveAccepted",
      Data = json.encode({
        cityKey = cityKey,
        expAwarded = result.expReward,
        totalExp = salesman.exp,
        efficiency = result.efficiency,
        actualCost = result.actualCost,
      })
    })
  end
)

-- Handler: Get TSP problem for current city
Handlers.add("GetProblem",
  Handlers.utils.hasMatchingTag("Action", "GetProblem"),
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
    
    local city = grid.getCityAt(State.worldSeed, salesman.x, salesman.y, State.chunkSize)
    
    if not city then
      ao.send({
        Target = pid,
        Action = "Error",
        Data = json.encode({error = "Not on a city"})
      })
      return
    end
    
    local cityKey = grid.cityKey(city.chunkX, city.chunkY, city.gridX, city.gridY)
    local solved = State.solvedCities[cityKey]
    
    if solved then
      ao.send({
        Target = pid,
        Action = "ProblemAlreadySolved",
        Data = json.encode({
          cityKey = cityKey,
          solvedBy = solved.solvedBy,
        })
      })
      return
    end
    
    local difficulty = tsp.getDifficulty(salesman.exp)
    local cities = tsp.generateProblem(city.seed, difficulty)
    
    ao.send({
      Target = pid,
      Action = "TSPProblem",
      Data = json.encode({
        citySeed = city.seed,
        cityKey = cityKey,
        difficulty = difficulty,
        cities = cities,
      })
    })
  end
)

return "Interactions module v1.0 loaded"
