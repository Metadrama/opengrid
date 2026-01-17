import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { WorldGenerator } from "./pkg/opengrid_world.js";

// Initialize WASM
console.log("🚀 Initializing OpenGrid Shared Core...");
// No explicit init needed for Deno target (uses top-level await)

const SEED = 12345;
const generator = new WorldGenerator(SEED);

console.log(`✅ Shared Core loaded. World Seed: ${SEED}`);
console.log(`🌍 Server running on http://localhost:3000`);

serve(async (req) => {
    const url = new URL(req.url);

    // CORS headers
    const headers = new Headers({
        "Access-Control-Allow-Origin": "*",
        "Content-Type": "application/json",
    });

    // GET /api/world - Return the Master Seed
    if (url.pathname === "/api/world") {
        return new Response(JSON.stringify({
            seed: SEED,
            chunk_size: 64, // From minimal constant
            city_density: 0.02
        }), { headers });
    }

    // GET /api/verify?x=100&y=200 - Verify city existence
    if (url.pathname === "/api/verify") {
        const x = parseFloat(url.searchParams.get("x") || "0");
        const y = parseFloat(url.searchParams.get("y") || "0");

        const exists = generator.verify_city(x, y);

        return new Response(JSON.stringify({
            x, y, exists
        }), { headers });
    }

    // GET /api/cities?chunkX=0&chunkY=0 - Debug: Get cities for a chunk
    if (url.pathname === "/api/cities") {
        const cx = parseInt(url.searchParams.get("chunkX") || "0");
        const cy = parseInt(url.searchParams.get("chunkY") || "0");

        const rawData = generator.get_cities_in_chunk(cx, cy);
        const cities = [];

        // Convert flat array [x1, y1, s1, x2, y2, s2...] to objects
        for (let i = 0; i < rawData.length; i += 3) {
            cities.push({
                x: rawData[i],
                y: rawData[i + 1],
                seed: rawData[i + 2]
            });
        }

        return new Response(JSON.stringify({
            chunkX: cx,
            chunkY: cy,
            cities
        }), { headers });
    }

    return new Response("OpenGrid World Server", { headers });
}, { port: 3000 });
