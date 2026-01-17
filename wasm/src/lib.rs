//! OpenGrid WASM World Renderer
//! 
//! GPU-accelerated infinite grid rendering for Flutter Web.

mod renderer;
mod world;

use wasm_bindgen::prelude::*;

pub use renderer::WorldRenderer;

/// Initialize panic hook for better error messages in browser console
#[wasm_bindgen(start)]
pub fn init() {
    console_error_panic_hook::set_once();
    web_sys::console::log_1(&"OpenGrid WASM initialized".into());
}

/// Get version string
#[wasm_bindgen]
pub fn version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}
