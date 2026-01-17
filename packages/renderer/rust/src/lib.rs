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
#[derive(Clone, Copy)]
pub struct Salesman {
    pub id: u32,
    pub x: f64,
    pub y: f64,
    pub color: u32, // 0xRRGGBB
}

#[wasm_bindgen]
pub struct WorldRenderer {
    canvas: HtmlCanvasElement,
    ctx: CanvasRenderingContext2d,
    camera: Camera,
    chunks: ChunkCache,
    salesmen: Vec<Salesman>,
    
    // Animation state
    running: bool,
    
    // Stats state
    last_visible_chunks: u32,
    last_total_cities: u32,
}

#[wasm_bindgen]
impl WorldRenderer {
    /// Create new renderer attached to a canvas
    #[wasm_bindgen(constructor)]
    pub fn new(canvas: HtmlCanvasElement, world_seed: u32) -> Result<WorldRenderer, JsValue> {
        let ctx = canvas
            .get_context("2d")?
            .ok_or("Failed to get 2d context")?
            .dyn_into::<CanvasRenderingContext2d>()?;
        
        let width = canvas.client_width() as f64;
        let height = canvas.client_height() as f64;
        
        canvas.set_width(width as u32);
        canvas.set_height(height as u32);
        
        Ok(WorldRenderer {
            canvas,
            ctx,
            camera: Camera::new(width, height),
            chunks: ChunkCache::new(world_seed),
            salesmen: Vec::new(),
            running: false,
            last_visible_chunks: 0,
            last_total_cities: 0,
        })
    }
    
    /// Update salesmen positions
    #[wasm_bindgen]
    pub fn update_salesmen(&mut self, data: Vec<f64>) {
        // Expected format: [id, x, y, color, id, x, y, color, ...]
        self.salesmen.clear();
        for chunk in data.chunks(4) {
            if chunk.len() == 4 {
                self.salesmen.push(Salesman {
                    id: chunk[0] as u32,
                    x: chunk[1],
                    y: chunk[2],
                    color: chunk[3] as u32,
                });
            }
        }
    }

    /// Pan camera by screen delta
    #[wasm_bindgen]
    pub fn pan(&mut self, dx: f64, dy: f64) {
        self.camera.pan(dx, dy);
    }
    
    /// Zoom at cursor position
    #[wasm_bindgen]
    pub fn zoom_at(&mut self, cursor_x: f64, cursor_y: f64, delta: f64) {
        self.camera.zoom_at(cursor_x, cursor_y, delta);
    }
    
    /// Set camera position directly
    #[wasm_bindgen]
    pub fn set_camera(&mut self, x: f64, y: f64, zoom: f64) {
        self.camera.x = x;
        self.camera.y = y;
        self.camera.zoom = zoom.clamp(Camera::MIN_ZOOM, Camera::MAX_ZOOM);
    }

    /// Render a single frame and return stats
    #[wasm_bindgen]
    pub fn render(&mut self) -> RenderStats {
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
        
        // Draw Salesmen
        self.draw_salesmen();
        
        // Update stats and chunks
        let visible = self.get_visible_coords();
        self.last_visible_chunks = visible.len() as u32;
        
        let mut total_cities = 0u32;
        for coord in &visible {
            let chunk = self.chunks.get_or_generate(*coord);
            total_cities += chunk.cities.len() as u32;
        }
        
        self.last_total_cities = total_cities;
        self.chunks.advance_frame();

        RenderStats {
            visible_chunks: self.last_visible_chunks,
            cached_chunks: self.chunks.cached_count() as u32,
            total_cities: self.last_total_cities,
            zoom: self.camera.zoom,
            camera_x: self.camera.x,
            camera_y: self.camera.y,
        }
    }

    fn draw_salesmen(&self) {
        let ctx = &self.ctx;
        for salesman in &self.salesmen {
             let (screen_x, screen_y) = self.camera.world_to_screen(salesman.x, salesman.y);
             
             // Draw Body
             let color = format!("#{:06x}", salesman.color);
             ctx.set_fill_style_str(&color);
             ctx.begin_path();
             ctx.arc(screen_x, screen_y, 8.0, 0.0, std::f64::consts::TAU).unwrap();
             ctx.fill();
             
             // Draw Glow
             ctx.set_stroke_style_str("white");
             ctx.set_line_width(2.0);
             ctx.stroke();
        }
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
