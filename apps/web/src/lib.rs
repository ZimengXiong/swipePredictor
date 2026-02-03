//! Web WASM wrapper for swipe-engine
//!
//! This crate re-exports the WASM bindings from swipe-engine for use in the web app.

// Re-export the WASM functions from swipe-engine
pub use swipe_engine::init_dictionary;
pub use swipe_engine::predict_wasm;
