use wasm_bindgen::prelude::*;
use rand::SeedableRng;
use rand::Rng;
use rand_pcg::Pcg32;

/// City data returned to JavaScript.
#[wasm_bindgen]
#[derive(Clone, Copy)]
pub struct City {
    pub local_x: f64,
    pub local_y: f64,
    pub seed: u32,
}

#[wasm_bindgen]
impl City {
    #[wasm_bindgen(constructor)]
    pub fn new(local_x: f64, local_y: f64, seed: u32) -> City {
        City { local_x, local_y, seed }
    }
}

/// Generate cities for a chunk using deterministic PRNG.
/// Same inputs = same outputs, guaranteed across all platforms.
#[wasm_bindgen]
pub fn generate_chunk(world_seed: u32, chunk_x: i32, chunk_y: i32) -> Vec<City> {
    // Deterministic seed from coordinates
    let chunk_seed = world_seed
        .wrapping_mul(73856093)
        .wrapping_add(chunk_x as u32)
        .wrapping_mul(19349663)
        .wrapping_add(chunk_y as u32);
    
    let mut rng = Pcg32::seed_from_u64(chunk_seed as u64);
    
    // ~2% density: 64x64 = 4096 cells, ~82 cities per chunk
    const CHUNK_SIZE: usize = 64;
    const DENSITY: f64 = 0.02;
    let expected_count = ((CHUNK_SIZE * CHUNK_SIZE) as f64 * DENSITY) as usize;
    
    let mut cities = Vec::with_capacity(expected_count);
    
    for _ in 0..expected_count {
        cities.push(City {
            local_x: rng.gen_range(0.0..1.0),
            local_y: rng.gen_range(0.0..1.0),
            seed: rng.gen(),
        });
    }
    
    cities
}

/// Get the number of cities in a chunk (for verification).
#[wasm_bindgen]
pub fn get_city_count(world_seed: u32, chunk_x: i32, chunk_y: i32) -> usize {
    generate_chunk(world_seed, chunk_x, chunk_y).len()
}

/// Initialize the WASM module (called once on load).
#[wasm_bindgen(start)]
pub fn init() {
    // Future: set up panic hook for better error messages
}
