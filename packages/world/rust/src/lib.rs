pub mod chunk;
pub mod camera;

pub use chunk::{ChunkCache, ChunkCoord, ChunkData, City, CHUNK_SIZE, CITY_DENSITY};
pub use camera::Camera;

use wasm_bindgen::prelude::*;

#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = console)]
    fn log(s: &str);
}

// Re-export for Deno/JS consumption
#[wasm_bindgen]
pub struct WorldGenerator {
    seed: u32,
    chunk_cache: ChunkCache,
}

#[wasm_bindgen]
impl WorldGenerator {
    #[wasm_bindgen(constructor)]
    pub fn new(seed: u32) -> Self {
        WorldGenerator {
            seed,
            chunk_cache: ChunkCache::new(seed),
        }
    }

    /// Get valid city coordinates in a chunk
    pub fn get_cities_in_chunk(&self, chunk_x: i32, chunk_y: i32) -> Vec<f64> {
        // We create a temporary cache to generate just this chunk deterministically
        // Note: In a real server scenario, we might want to keep the cache or be stateless
        // Since ChunkCache::new(seed) is cheap, we can just use the internal one
        // But `generate_chunk` is private in ChunkCache, so we need to use get_or_generate
        
        let mut cache = ChunkCache::new(self.seed);
        let coord = ChunkCoord::new(chunk_x, chunk_y);
        let data = cache.get_or_generate(coord);
        
        let mut result = Vec::with_capacity(data.cities.len() * 3);
        for city in &data.cities {
            result.push(city.world_x(&coord));
            result.push(city.world_y(&coord));
            result.push(city.seed as f64);
        }
        result
    }
    
    /// Verify if a city exists at a rough world location (tolerance check)
    pub fn verify_city(&self, world_x: f64, world_y: f64) -> bool {
        let chunk_x = (world_x / CHUNK_SIZE as f64).floor() as i32;
        let chunk_y = (world_y / CHUNK_SIZE as f64).floor() as i32;
        
        let mut cache = ChunkCache::new(self.seed);
        let coord = ChunkCoord::new(chunk_x, chunk_y);
        let data = cache.get_or_generate(coord);
        
        for city in &data.cities {
             let cx = city.world_x(&coord);
             let cy = city.world_y(&coord);
             
             // Exact match check (float tolerance)
             if (cx - world_x).abs() < 0.01 && (cy - world_y).abs() < 0.01 {
                 return true;
             }
        }
        false
    }
}
