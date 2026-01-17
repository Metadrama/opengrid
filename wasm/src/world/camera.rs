//! Camera state for viewport

pub struct Camera {
    /// World X position (left edge)
    pub x: f64,
    /// World Y position (top edge)
    pub y: f64,
    /// Zoom level (pixels per cell)
    pub zoom: f64,
    /// Viewport width in pixels
    pub width: f64,
    /// Viewport height in pixels
    pub height: f64,
}

impl Camera {
    pub const MIN_ZOOM: f64 = 5.0;
    pub const MAX_ZOOM: f64 = 100.0;
    
    pub fn new(width: f64, height: f64) -> Self {
        Self {
            x: 0.0,
            y: 0.0,
            zoom: 20.0,
            width,
            height,
        }
    }
    
    /// Pan by screen delta
    pub fn pan(&mut self, dx: f64, dy: f64) {
        self.x -= dx / self.zoom;
        self.y -= dy / self.zoom;
    }
    
    /// Zoom centered on cursor position
    pub fn zoom_at(&mut self, cursor_x: f64, cursor_y: f64, delta: f64) {
        // World position under cursor before zoom
        let world_x = self.x + cursor_x / self.zoom;
        let world_y = self.y + cursor_y / self.zoom;
        
        // Apply zoom
        let old_zoom = self.zoom;
        self.zoom = (self.zoom * (1.0 + delta)).clamp(Self::MIN_ZOOM, Self::MAX_ZOOM);
        
        // Adjust position to keep cursor over same world point
        self.x = world_x - cursor_x / self.zoom;
        self.y = world_y - cursor_y / self.zoom;
    }
    
    /// Resize viewport
    pub fn resize(&mut self, width: f64, height: f64) {
        self.width = width;
        self.height = height;
    }
    
    /// Convert screen position to world position
    pub fn screen_to_world(&self, screen_x: f64, screen_y: f64) -> (f64, f64) {
        let world_x = self.x + screen_x / self.zoom;
        let world_y = self.y + screen_y / self.zoom;
        (world_x, world_y)
    }
    
    /// Convert world position to screen position
    pub fn world_to_screen(&self, world_x: f64, world_y: f64) -> (f64, f64) {
        let screen_x = (world_x - self.x) * self.zoom;
        let screen_y = (world_y - self.y) * self.zoom;
        (screen_x, screen_y)
    }
}
