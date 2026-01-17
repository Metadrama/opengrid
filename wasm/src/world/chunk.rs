//! Chunk generation and caching
//! 
//! Deterministic procedural generation matching the original Dart implementation.

use rand::SeedableRng;
use rand::Rng;
use rand_pcg::Pcg32;
use std::collections::HashMap;

pub const CHUNK_SIZE: i32 = 64;
pub const CITY_DENSITY: f64 = 0.02;
pub const MAX_CACHED_CHUNKS: usize = 100;

#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub struct ChunkCoord {
    pub x: i32,
    pub y: i32,
}

impl ChunkCoord {
    pub fn new(x: i32, y: i32) -> Self {
        Self { x, y }
    }
}

#[derive(Clone, Debug)]
pub struct City {
    pub grid_x: i32,
    pub grid_y: i32,
    pub seed: u32,
}

impl City {
    /// Get world X coordinate
    pub fn world_x(&self, chunk: &ChunkCoord) -> f64 {
        (chunk.x * CHUNK_SIZE + self.grid_x) as f64
    }
    
    /// Get world Y coordinate  
    pub fn world_y(&self, chunk: &ChunkCoord) -> f64 {
        (chunk.y * CHUNK_SIZE + self.grid_y) as f64
    }
    
    /// Get normalized position within chunk (0.0-1.0)
    pub fn local_x(&self) -> f64 {
        self.grid_x as f64 / CHUNK_SIZE as f64
    }
    
    pub fn local_y(&self) -> f64 {
        self.grid_y as f64 / CHUNK_SIZE as f64
    }
}

pub struct ChunkData {
    pub coord: ChunkCoord,
    pub cities: Vec<City>,
    pub last_used: u64,
}

pub struct ChunkCache {
    world_seed: u32,
    cache: HashMap<ChunkCoord, ChunkData>,
    frame_counter: u64,
}

impl ChunkCache {
    pub fn new(world_seed: u32) -> Self {
        Self {
            world_seed,
            cache: HashMap::new(),
            frame_counter: 0,
        }
    }
    
    /// Get or generate a chunk
    pub fn get_or_generate(&mut self, coord: ChunkCoord) -> &ChunkData {
        if !self.cache.contains_key(&coord) {
            let data = self.generate_chunk(coord);
            self.cache.insert(coord, data);
            self.evict_if_needed();
        }
        
        // Update LRU timestamp
        if let Some(chunk) = self.cache.get_mut(&coord) {
            chunk.last_used = self.frame_counter;
        }
        
        self.cache.get(&coord).unwrap()
    }
    
    /// Generate chunk - MUST match Dart algorithm exactly!
    fn generate_chunk(&self, coord: ChunkCoord) -> ChunkData {
        // Dart: worldSeed ^ (coord.x * 73856093) ^ (coord.y * 19349663)
        let chunk_seed = (self.world_seed as i64)
            ^ ((coord.x as i64).wrapping_mul(73856093))
            ^ ((coord.y as i64).wrapping_mul(19349663));
        
        let mut rng = Pcg32::seed_from_u64(chunk_seed as u64);
        
        let num_cells = (CHUNK_SIZE * CHUNK_SIZE) as usize;
        let expected_cities = (num_cells as f64 * CITY_DENSITY).round() as usize;
        
        let mut cities = Vec::with_capacity(expected_cities);
        let mut used_positions = std::collections::HashSet::new();
        
        for _ in 0..expected_cities {
            // Dart: rng.nextInt(chunkSize)
            let grid_x = rng.gen_range(0..CHUNK_SIZE);
            let grid_y = rng.gen_range(0..CHUNK_SIZE);
            let pos_key = grid_y * CHUNK_SIZE + grid_x;
            
            // Skip if position already used
            if used_positions.contains(&pos_key) {
                continue;
            }
            used_positions.insert(pos_key);
            
            // Dart: rng.nextInt(1 << 30)
            let seed = rng.gen::<u32>() & 0x3FFFFFFF;
            cities.push(City { grid_x, grid_y, seed });
        }
        
        ChunkData {
            coord,
            cities,
            last_used: self.frame_counter,
        }
    }
    
    /// Evict oldest chunks if over limit
    fn evict_if_needed(&mut self) {
        if self.cache.len() <= MAX_CACHED_CHUNKS {
            return;
        }
        
        // Sort by last_used, remove oldest
        let mut entries: Vec<_> = self.cache.iter()
            .map(|(k, v)| (*k, v.last_used))
            .collect();
        entries.sort_by_key(|(_, t)| *t);
        
        let to_remove = self.cache.len() - MAX_CACHED_CHUNKS;
        for (coord, _) in entries.into_iter().take(to_remove) {
            self.cache.remove(&coord);
        }
    }
    
    /// Get visible chunk coordinates for a viewport
    pub fn get_visible_chunks(
        &self,
        camera_x: f64,
        camera_y: f64,
        zoom: f64,
        viewport_width: f64,
        viewport_height: f64,
    ) -> Vec<ChunkCoord> {
        let cell_size = zoom;
        let chunk_pixel_size = CHUNK_SIZE as f64 * cell_size;
        
        // Viewport in world coordinates
        let view_left = camera_x;
        let view_right = camera_x + viewport_width / cell_size;
        let view_top = camera_y;
        let view_bottom = camera_y + viewport_height / cell_size;
        
        // Chunk bounds
        let min_cx = (view_left / CHUNK_SIZE as f64).floor() as i32;
        let max_cx = (view_right / CHUNK_SIZE as f64).ceil() as i32;
        let min_cy = (view_top / CHUNK_SIZE as f64).floor() as i32;
        let max_cy = (view_bottom / CHUNK_SIZE as f64).ceil() as i32;
        
        let mut chunks = Vec::new();
        for cx in min_cx..=max_cx {
            for cy in min_cy..=max_cy {
                chunks.push(ChunkCoord::new(cx, cy));
            }
        }
        chunks
    }
    
    /// Advance frame counter for LRU
    pub fn advance_frame(&mut self) {
        self.frame_counter += 1;
    }
    
    /// Get cached chunk count
    pub fn cached_count(&self) -> usize {
        self.cache.len()
    }
    
    /// Iterate over all cached chunks
    pub fn iter(&self) -> impl Iterator<Item = &ChunkData> {
        self.cache.values()
    }
}
