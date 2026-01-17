use wasm_bindgen::prelude::*;

#[derive(Clone, Copy, Debug, Default)]
pub struct Camera {
    pub x: f64,
    pub y: f64,
    pub zoom: f64,
    pub width: f64,
    pub height: f64,
}

impl Camera {
    // Constants
    pub const MIN_ZOOM: f64 = 2.0;
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

    pub fn resize(&mut self, width: f64, height: f64) {
        self.width = width;
        self.height = height;
    }

    pub fn pan(&mut self, screen_dx: f64, screen_dy: f64) {
        self.x -= screen_dx / self.zoom;
        self.y -= screen_dy / self.zoom;
    }

    pub fn zoom_at(&mut self, screen_x: f64, screen_y: f64, delta: f64) {
        let (world_x, world_y) = self.screen_to_world(screen_x, screen_y);
        
        let zoom_factor = if delta > 0.0 { 1.1 } else { 0.9 };
        let new_zoom = (self.zoom * zoom_factor).clamp(Self::MIN_ZOOM, Self::MAX_ZOOM);
        
        self.zoom = new_zoom;
        
        self.x = world_x - screen_x / self.zoom;
        self.y = world_y - screen_y / self.zoom;
    }

    pub fn screen_to_world(&self, screen_x: f64, screen_y: f64) -> (f64, f64) {
        (
            self.x + screen_x / self.zoom,
            self.y + screen_y / self.zoom
        )
    }

    pub fn world_to_screen(&self, world_x: f64, world_y: f64) -> (f64, f64) {
        (
            (world_x - self.x) * self.zoom,
            (world_y - self.y) * self.zoom
        )
    }
}
