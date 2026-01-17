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
    pub salesman_count: u32,
}

/// A waypoint in the salesman's path
#[derive(Clone)]
struct Waypoint {
    x: f64,
    y: f64,
    arrival_time: f64,
}

/// Salesman path for smooth animation
#[derive(Clone)]
struct SalesmanPath {
    id: u32,
    color: u32,
    speed: f64,
    waypoints: Vec<Waypoint>,
}

impl SalesmanPath {
    /// Get interpolated position based on elapsed time
    fn get_position(&self, elapsed: f64) -> (f64, f64, bool) {
        if self.waypoints.is_empty() {
            return (0.0, 0.0, true);
        }
        
        if self.waypoints.len() == 1 {
            return (self.waypoints[0].x, self.waypoints[0].y, true);
        }
        
        // Find the segment we're currently on
        for i in 0..(self.waypoints.len() - 1) {
            let current = &self.waypoints[i];
            let next = &self.waypoints[i + 1];
            
            if elapsed >= current.arrival_time && elapsed < next.arrival_time {
                // Interpolate between current and next
                let segment_duration = next.arrival_time - current.arrival_time;
                if segment_duration <= 0.0 {
                    return (next.x, next.y, false);
                }
                
                let t = (elapsed - current.arrival_time) / segment_duration;
                let x = current.x + (next.x - current.x) * t;
                let y = current.y + (next.y - current.y) * t;
                return (x, y, false);
            }
        }
        
        // Past the end - return final position
        let last = &self.waypoints[self.waypoints.len() - 1];
        (last.x, last.y, true)
    }
}

#[wasm_bindgen]
pub struct WorldRenderer {
    canvas: HtmlCanvasElement,
    ctx: CanvasRenderingContext2d,
    camera: Camera,
    chunks: ChunkCache,
    
    // Path-based salesman animation
    salesman_paths: Vec<SalesmanPath>,
    animation_start_time: f64,
    
    // Animation state
    running: bool,
    
    // Stats state
    last_visible_chunks: u32,
    last_total_cities: u32,
}

fn get_time_seconds() -> f64 {
    js_sys::Date::now() / 1000.0
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
            salesman_paths: Vec::new(),
            animation_start_time: get_time_seconds(),
            running: false,
            last_visible_chunks: 0,
            last_total_cities: 0,
        })
    }
    
    /// Update salesman paths from AO
    /// Data format: [id, color, speed, numWaypoints, x1, y1, t1, x2, y2, t2, ..., (next salesman)]
    #[wasm_bindgen]
    pub fn update_salesman_paths(&mut self, data: Vec<f64>) {
        self.salesman_paths.clear();
        self.animation_start_time = get_time_seconds();
        
        let mut i = 0;
        while i + 3 < data.len() {
            let id = data[i] as u32;
            let color = data[i + 1] as u32;
            let speed = data[i + 2];
            let num_waypoints = data[i + 3] as usize;
            i += 4;
            
            let mut waypoints = Vec::with_capacity(num_waypoints);
            for _ in 0..num_waypoints {
                if i + 2 < data.len() {
                    waypoints.push(Waypoint {
                        x: data[i],
                        y: data[i + 1],
                        arrival_time: data[i + 2],
                    });
                    i += 3;
                }
            }
            
            if !waypoints.is_empty() {
                self.salesman_paths.push(SalesmanPath {
                    id,
                    color,
                    speed,
                    waypoints,
                });
            }
        }
        
        web_sys::console::log_1(&format!(
            "Updated {} salesman paths", 
            self.salesman_paths.len()
        ).into());
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
        
        // Draw salesman paths (trails)
        self.draw_salesman_trails();
        
        // Draw salesmen (animated positions)
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
            salesman_count: self.salesman_paths.len() as u32,
        }
    }

    fn draw_salesman_trails(&self) {
        let ctx = &self.ctx;
        
        for path in &self.salesman_paths {
            if path.waypoints.len() < 2 {
                continue;
            }
            
            // Draw path trail
            let r = (path.color >> 16) & 0xFF;
            let g = (path.color >> 8) & 0xFF;
            let b = path.color & 0xFF;
            
            ctx.set_stroke_style_str(&format!("rgba({}, {}, {}, 0.3)", r, g, b));
            ctx.set_line_width(2.0);
            ctx.begin_path();
            
            let (sx, sy) = self.camera.world_to_screen(
                path.waypoints[0].x, 
                path.waypoints[0].y
            );
            ctx.move_to(sx, sy);
            
            for wp in path.waypoints.iter().skip(1) {
                let (wx, wy) = self.camera.world_to_screen(wp.x, wp.y);
                ctx.line_to(wx, wy);
            }
            
            ctx.stroke();
            
            // Draw waypoint dots
            ctx.set_fill_style_str(&format!("rgba({}, {}, {}, 0.5)", r, g, b));
            for wp in &path.waypoints {
                let (wx, wy) = self.camera.world_to_screen(wp.x, wp.y);
                ctx.begin_path();
                ctx.arc(wx, wy, 3.0, 0.0, std::f64::consts::TAU).ok();
                ctx.fill();
            }
        }
    }

    fn draw_salesmen(&self) {
        let ctx = &self.ctx;
        let elapsed = get_time_seconds() - self.animation_start_time;
        
        for path in &self.salesman_paths {
            let (world_x, world_y, _complete) = path.get_position(elapsed);
            let (screen_x, screen_y) = self.camera.world_to_screen(world_x, world_y);
            
            // Extract RGB
            let r = (path.color >> 16) & 0xFF;
            let g = (path.color >> 8) & 0xFF;
            let b = path.color & 0xFF;
            
            // Draw glow
            ctx.set_shadow_color(&format!("rgb({}, {}, {})", r, g, b));
            ctx.set_shadow_blur(15.0);
            
            // Draw body
            ctx.set_fill_style_str(&format!("#{:06x}", path.color));
            ctx.begin_path();
            ctx.arc(screen_x, screen_y, 8.0, 0.0, std::f64::consts::TAU).ok();
            ctx.fill();
            
            // Draw border
            ctx.set_shadow_blur(0.0);
            ctx.set_stroke_style_str("white");
            ctx.set_line_width(2.0);
            ctx.stroke();
            
            // Draw ID label
            ctx.set_fill_style_str("white");
            ctx.set_font("10px monospace");
            ctx.fill_text(&format!("{}", path.id), screen_x + 12.0, screen_y + 4.0).ok();
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
