// deploy.mjs - Deploy salesman processes to local WAO server
import { AO } from "wao"
import { readFileSync, writeFileSync, existsSync } from "fs"

const PORT = 4000
const SALESMEN_FILE = "./salesmen.json"
const CITIES_FILE = "./cities.json"

async function main() {
  console.log("🚀 OpenGrid Salesman Deployment")
  console.log("================================\n")
  
  // Read Lua source
  const salesmanLua = readFileSync("./salesman.1.lua", "utf8")
  console.log("✅ Loaded salesman.1.lua")
  
  // Connect to local WAO
  let ao
  try {
    ao = await new AO(PORT).init(null) // null = local testing without wallet
    console.log(`✅ Connected to local WAO server on port ${PORT}\n`)
  } catch (e) {
    console.error(`❌ Failed to connect to WAO on port ${PORT}`)
    console.error("   Make sure to run: npx wao --port 4000")
    process.exit(1)
  }
  
  // Generate 10 random cities in a 500x500 grid centered at origin
  const cities = Array.from({ length: 10 }, (_, i) => ({
    x: Math.round((Math.random() * 400 - 200) * 100) / 100,
    y: Math.round((Math.random() * 400 - 200) * 100) / 100,
    name: `City${i + 1}`
  }))
  
  console.log("📍 Generated cities:")
  cities.forEach(c => console.log(`   ${c.name}: (${c.x}, ${c.y})`))
  console.log("")
  
  // Deploy 3 salesmen
  const salesmen = []
  const colors = [0xFF5500, 0x00FF55, 0x5500FF] // Orange, Green, Blue
  const startPositions = [
    { x: 0, y: 0 },
    { x: -50, y: -50 },
    { x: 50, y: 50 }
  ]
  
  for (let i = 0; i < 3; i++) {
    console.log(`\n🚀 Deploying Salesman ${i + 1}...`)
    
    try {
      const { pid } = await ao.deploy({ src_data: salesmanLua })
      console.log(`   PID: ${pid}`)
      
      // Initialize with position and color
      const initResult = await ao.msg({
        pid,
        act: "Init",
        data: JSON.stringify({
          id: i + 1,
          position: startPositions[i],
          color: colors[i],
          speed: 15 + i * 5, // Different speeds: 15, 20, 25
          cities: cities
        })
      })
      console.log(`   ✅ Initialized`)
      
      // Plan initial route
      const planResult = await ao.msg({
        pid,
        act: "PlanRoute",
        data: JSON.stringify({ cities })
      })
      console.log(`   ✅ Route planned`)
      
      salesmen.push({
        pid,
        id: i + 1,
        color: colors[i],
        startPosition: startPositions[i]
      })
    } catch (e) {
      console.error(`   ❌ Failed: ${e.message}`)
    }
  }
  
  // Save registry files
  writeFileSync(SALESMEN_FILE, JSON.stringify(salesmen, null, 2))
  writeFileSync(CITIES_FILE, JSON.stringify(cities, null, 2))
  
  console.log(`\n================================`)
  console.log(`✅ Deployed ${salesmen.length} salesmen`)
  console.log(`📁 Saved to ${SALESMEN_FILE}`)
  console.log(`📁 Saved to ${CITIES_FILE}`)
  console.log(`\n📋 Next steps:`)
  console.log(`   1. Copy salesmen.json to your Flutter assets/`)
  console.log(`   2. Run: flutter run -d chrome`)
}

main().catch(e => {
  console.error("❌ Deployment failed:", e.message)
  process.exit(1)
})
