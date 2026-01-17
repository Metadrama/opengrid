use wasm_bindgen::prelude::*;

pub use opengrid_renderer::{WorldRenderer, CityInfo, RenderStats};

#[wasm_bindgen(start)]
pub fn init() {
    console_error_panic_hook::set_once();
    web_sys::console::log_1(&"OpenGrid WASM initialized".into());
}

#[wasm_bindgen]
pub fn version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}
