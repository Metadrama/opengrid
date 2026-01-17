//! Main WorldRenderer - GPU-accelerated infinite grid
//!
//! Uses Canvas2D for initial implementation, with path to upgrade to WebGPU.

use wasm_bindgen::prelude::*;
use wasm_bindgen::JsCast;
use web_sys::{HtmlCanvasElement, CanvasRenderingContext2d};
use opengrid_world::{ChunkCache, ChunkCoord, CHUNK_SIZE, Camera};

/// City info returned to Flutter on click
#[wasm_bindgen]
pub struct CityInfo {
    pub chunk_x: i32,
    pub chunk_y: i32,
    pub grid_x: i32,
    pub grid_y: i32,
    pub seed: u32,
    pub screen_x: f64,
    pub screen_y: f64,
}

/// Stats for debug overlay
#[wasm_bindgen]
pub struct RenderStats {
    pub visible_chunks: u32,
    pub cached_chunks: u32,
    pub total_cities: u32,
    pub zoom: f64,
    pub camera_x: f64,
    pub camera_y: f64,
}

#[wasm_bindgen]
pub struct WorldRenderer {
    canvas: HtmlCanvasElement,
    ctx: CanvasRenderingContext2d,
    camera: Camera,
    chunks: ChunkCache,
    
    // Selection state
    selected_city: Option<(ChunkCoord, i32, i32)>, // (chunk, gridX, gridY)
    
    // Animation
    running: bool,
    animation_id: Option<i32>,
    
    // Stats
    last_visible_chunks: u32,
    last_total_cities: u32,
}

#[wasm_bindgen]
impl WorldRenderer {
    /// Create new renderer attached to a canvas
    #[wasm_bindgen(constructor)]
    pub fn new(canvas: HtmlCanvasElement, world_seed: u32) -> Result<WorldRenderer, JsValue> {
        // Get 2D context
        let ctx = canvas
            .get_context("2d")?
            .ok_or("Failed to get 2d context")?
            .dyn_into::<CanvasRenderingContext2d>()?;
        
        // Get canvas size
        let width = canvas.client_width() as f64;
        let height = canvas.client_height() as f64;
        
        // Set actual pixel size
        canvas.set_width(width as u32);
        canvas.set_height(height as u32);
        
        Ok(WorldRenderer {
            canvas,
            ctx,
            camera: Camera::new(width, height),
            chunks: ChunkCache::new(world_seed),
            selected_city: None,
            running: false,
            animation_id: None,
            last_visible_chunks: 0,
            last_total_cities: 0,
        })
    }
    
    /// Pan camera by screen delta
    #[wasm_bindgen]
    pub fn pan(&mut self, dx: f64, dy: f64) {
        self.camera.pan(dx, dy);
        self.clear_selection();
    }
    
    /// Zoom at cursor position
    #[wasm_bindgen]
    pub fn zoom_at(&mut self, cursor_x: f64, cursor_y: f64, delta: f64) {
        self.camera.zoom_at(cursor_x, cursor_y, delta);
        self.clear_selection();
    }
    
    /// Set camera position directly
    #[wasm_bindgen]
    pub fn set_camera(&mut self, x: f64, y: f64, zoom: f64) {
        self.camera.x = x;
        self.camera.y = y;
        self.camera.zoom = zoom.clamp(Camera::MIN_ZOOM, Camera::MAX_ZOOM);
    }
    
    /// Handle click - returns CityInfo if hit, null otherwise
    #[wasm_bindgen]
    pub fn click(&mut self, screen_x: f64, screen_y: f64) -> Option<CityInfo> {
        let (world_x, world_y) = self.camera.screen_to_world(screen_x, screen_y);
        
        // Check all cached chunks for city hits
        let visible = self.get_visible_coords();
        
        for coord in visible {
            let chunk = self.chunks.get_or_generate(coord);
            
            for city in &chunk.cities {
                let city_world_x = city.world_x(&coord);
                let city_world_y = city.world_y(&coord);
                
                // Hit test (15 pixel radius in screen space)
                let (city_screen_x, city_screen_y) = self.camera.world_to_screen(city_world_x, city_world_y);
                let dx = screen_x - city_screen_x;
                let dy = screen_y - city_screen_y;
                let dist = (dx * dx + dy * dy).sqrt();
                
                if dist < 15.0 {
                    self.selected_city = Some((coord, city.grid_x, city.grid_y));
                    
                    return Some(CityInfo {
                        chunk_x: coord.x,
                        chunk_y: coord.y,
                        grid_x: city.grid_x,
                        grid_y: city.grid_y,
                        seed: city.seed,
                        screen_x: city_screen_x,
                        screen_y: city_screen_y,
                    });
                }
            }
        }
        
        // No hit - clear selection
        self.clear_selection();
        None
    }
    
    fn clear_selection(&mut self) {
        self.selected_city = None;
    }
    
    /// Get render stats for debug overlay
    #[wasm_bindgen]
    pub fn get_stats(&self) -> RenderStats {
        RenderStats {
            visible_chunks: self.last_visible_chunks,
            cached_chunks: self.chunks.cached_count() as u32,
            total_cities: self.last_total_cities,
            zoom: self.camera.zoom,
            camera_x: self.camera.x,
            camera_y: self.camera.y,
        }
    }
    
    /// Render a single frame
    #[wasm_bindgen]
    pub fn render(&mut self) {
        // Update canvas size if needed
        let width = self.canvas.client_width() as f64;
        let height = self.canvas.client_height() as f64;
        
        if width != self.camera.width || height != self.camera.height {
            self.canvas.set_width(width as u32);
            self.canvas.set_height(height as u32);
            self.camera.resize(width, height);
        }
        
        // Clear background
        self.ctx.set_fill_style_str("#0D0D0D");
        self.ctx.fill_rect(0.0, 0.0, width, height);
        
        // Draw grid lines
        self.draw_grid();
        
        // Load visible chunks and collect city data first
        let visible = self.get_visible_coords();
        self.last_visible_chunks = visible.len() as u32;
        
        // Collect all cities to draw (avoids borrow conflict)
        let mut cities_to_draw: Vec<(ChunkCoord, f64, f64, i32, i32, u32)> = Vec::new();
        let mut total_cities = 0u32;
        
        for coord in &visible {
            let chunk = self.chunks.get_or_generate(*coord);
            total_cities += chunk.cities.len() as u32;
            
            for city in &chunk.cities {
                let world_x = city.world_x(&coord);
                let world_y = city.world_y(&coord);
                cities_to_draw.push((*coord, world_x, world_y, city.grid_x, city.grid_y, city.seed));
            }
        }
        
        // Now draw all cities (no borrow conflict)
        for (coord, world_x, world_y, grid_x, grid_y, _seed) in cities_to_draw {
            self.draw_city_at(coord, world_x, world_y, grid_x, grid_y);
        }
        
        self.last_total_cities = total_cities;
        self.chunks.advance_frame();
    }
    
    fn get_visible_coords(&self) -> Vec<ChunkCoord> {
        self.chunks.get_visible_chunks(
            self.camera.x,
            self.camera.y,
            self.camera.zoom,
            self.camera.width,
            self.camera.height,
        )
    }
    
    fn draw_grid(&self) {
        let ctx = &self.ctx;
        let zoom = self.camera.zoom;
        let width = self.camera.width;
        let height = self.camera.height;
        
        ctx.set_stroke_style_str("#2A2A2A");
        ctx.set_line_width(1.0);
        
        // Calculate visible grid range
        let start_x = self.camera.x.floor() as i32;
        let end_x = (self.camera.x + width / zoom).ceil() as i32;
        let start_y = self.camera.y.floor() as i32;
        let end_y = (self.camera.y + height / zoom).ceil() as i32;
        
        ctx.begin_path();
        
        // Vertical lines
        for x in start_x..=end_x {
            let (screen_x, _) = self.camera.world_to_screen(x as f64, 0.0);
            ctx.move_to(screen_x, 0.0);
            ctx.line_to(screen_x, height);
        }
        
        // Horizontal lines
        for y in start_y..=end_y {
            let (_, screen_y) = self.camera.world_to_screen(0.0, y as f64);
            ctx.move_to(0.0, screen_y);
            ctx.line_to(width, screen_y);
        }
        
        ctx.stroke();
    }
    
    fn draw_city_at(&self, chunk_coord: ChunkCoord, world_x: f64, world_y: f64, grid_x: i32, grid_y: i32) {
        let ctx = &self.ctx;
        
        let (screen_x, screen_y) = self.camera.world_to_screen(world_x, world_y);
        
        // Skip if off screen
        if screen_x < -20.0 || screen_x > self.camera.width + 20.0 ||
           screen_y < -20.0 || screen_y > self.camera.height + 20.0 {
            return;
        }
        
        // Check if selected
        let is_selected = self.selected_city.map_or(false, |(c, gx, gy)| {
            c == chunk_coord && gx == grid_x && gy == grid_y
        });
        
        if is_selected {
            // Selected: yellow glow
            ctx.set_fill_style_str("rgba(255, 255, 0, 0.5)");
            ctx.begin_path();
            ctx.arc(screen_x, screen_y, 10.0, 0.0, std::f64::consts::TAU).unwrap();
            ctx.fill();
            
            ctx.set_fill_style_str("#FFFF00");
            ctx.begin_path();
            ctx.arc(screen_x, screen_y, 4.0, 0.0, std::f64::consts::TAU).unwrap();
            ctx.fill();
        } else {
            // Normal: green glow
            ctx.set_fill_style_str("rgba(0, 255, 136, 0.3)");
            ctx.begin_path();
            ctx.arc(screen_x, screen_y, 6.0, 0.0, std::f64::consts::TAU).unwrap();
            ctx.fill();
            
            ctx.set_fill_style_str("#00FF88");
            ctx.begin_path();
            ctx.arc(screen_x, screen_y, 3.0, 0.0, std::f64::consts::TAU).unwrap();
            ctx.fill();
        }
    }
    
    /// Start render loop
    #[wasm_bindgen]
    pub fn start(&mut self) {
        self.running = true;
        // Initial render
        self.render();
    }
    
    /// Stop render loop
    #[wasm_bindgen]
    pub fn stop(&mut self) {
        self.running = false;
    }
    
    /// Check if running
    #[wasm_bindgen]
    pub fn is_running(&self) -> bool {
        self.running
    }
}
