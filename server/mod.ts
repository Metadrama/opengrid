import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { WorldGenerator } from "./pkg/opengrid_world.js";

// Initialize WASM
console.log("🚀 Initializing OpenGrid Shared Core...");
// No explicit init needed for Deno target (uses top-level await)

const SEED = 12345;
const generator = new WorldGenerator(SEED);

// Mock State
interface Waypoint {
    x: number;
    y: number;
    arrivalTime: number;
}
interface Salesman {
    id: number;
    color: number;
    speed: number;
    waypoints: Waypoint[];
}

const salesmen: Salesman[] = [
    { id: 1, color: 0xFF0055, speed: 5, waypoints: [] }, // Red
    { id: 2, color: 0x00FF88, speed: 7, waypoints: [] }, // Green
    { id: 3, color: 0x00AAdd, speed: 4, waypoints: [] }, // Blue
];

// Helper to get random city
function getRandomCity() {
    // Pick a random chunk around 0,0
    const cx = Math.floor(Math.random() * 10) - 5;
    const cy = Math.floor(Math.random() * 10) - 5;
    const cities = generator.get_cities_in_chunk(cx, cy);
    // cities is flat array [x, y, seed, x, y, seed...]
    if (cities.length === 0) return { x: 0, y: 0 }; // Fallback

    const idx = Math.floor(Math.random() * (cities.length / 3)) * 3;
    return { x: cities[idx], y: cities[idx + 1] };
}

// Simulation Loop
function updateSimulation() {
    const now = Date.now() / 1000;

    for (const s of salesmen) {
        // Clean old waypoints
        s.waypoints = s.waypoints.filter(wp => wp.arrivalTime > now - 5);

        // Add new waypoints if running low
        if (s.waypoints.length < 3) {
            const lastWp = s.waypoints[s.waypoints.length - 1] || { x: 0, y: 0, arrivalTime: now };
            const nextCity = getRandomCity();

            const dx = nextCity.x - lastWp.x;
            const dy = nextCity.y - lastWp.y;
            const dist = Math.sqrt(dx * dx + dy * dy);

            // Calculate travel time based on speed
            const duration = (dist / s.speed) || 1; // Avoid divide by zero

            s.waypoints.push({
                x: nextCity.x,
                y: nextCity.y,
                arrivalTime: lastWp.arrivalTime + duration
            });
        }
    }
}

// Run simulation tick every 500ms
setInterval(updateSimulation, 500);


console.log("🌍 Server running on http://localhost:3000");

serve(async (req) => {
    const url = new URL(req.url);
    const headers = {
        "content-type": "application/json",
        "Access-Control-Allow-Origin": "*",
    };

    if (url.pathname === "/api/world") {
        return new Response(JSON.stringify({
            seed: SEED,
            chunk_size: 64,
            city_density: 0.02
        }), { headers });
    }

    if (url.pathname === "/api/salesmen") {
        // Format for Client: [id, color, speed, count, x, y, t, x, y, t...] flattened
        const data: number[] = [];
        for (const s of salesmen) {
            data.push(s.id, s.color, s.speed, s.waypoints.length);
            for (const wp of s.waypoints) {
                data.push(wp.x, wp.y, wp.arrivalTime);
            }
        }
        return new Response(JSON.stringify(data), { headers });
    }

    if (url.pathname === "/api/verify") {
        const x = parseFloat(url.searchParams.get("x") || "0");
        const y = parseFloat(url.searchParams.get("y") || "0");
        const exists = generator.verify_city(x, y);
        return new Response(JSON.stringify({ x, y, exists }), { headers });
    }

    return new Response("OpenGrid World Server", { headers });
}, { port: 3000 });
