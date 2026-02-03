//! Swipe typing prediction engine
//!
//! This crate provides swipe/gesture typing prediction using Dynamic Time Warping (DTW)
//! to match swipe paths against a dictionary of words.

pub mod types;
pub mod keyboard;
pub mod dtw;

#[cfg(feature = "wasm")]
pub mod wasm;

#[cfg(feature = "wasm")]
pub use wasm::*;

#[cfg(feature = "ffi")]
pub mod ffi;

use std::collections::HashMap;
use types::{Dictionary, Point, Prediction};
use keyboard::{euclidean_dist, get_keyboard_layout, get_word_path, simplify_path};
use dtw::dtw_distance_fast;

// Re-export commonly used items
pub use types::Point as PointType;
pub use keyboard::{euclidean_dist as euclidean_distance, get_keyboard_layout as keyboard_layout, get_word_path as word_path, simplify_path as path_simplify};
pub use dtw::{dtw_distance_fast as dtw_fast, dtw_distance};

/// The main swipe typing prediction engine
pub struct SwipeEngine {
    dictionary: Dictionary,
    layout: HashMap<char, Point>,
    pop_weight: f64,
}

impl SwipeEngine {
    /// Create a new SwipeEngine with default settings
    pub fn new() -> Self {
        Self {
            dictionary: Dictionary::new(),
            layout: get_keyboard_layout(),
            pop_weight: 0.25,
        }
    }

    /// Set the popularity weight factor (higher = more influence from word frequency)
    pub fn set_pop_weight(&mut self, weight: f64) {
        self.pop_weight = weight;
    }

    /// Load a dictionary from frequency text format (word\tcount per line)
    pub fn load_dictionary(&mut self, freq_text: &str) {
        self.dictionary.load_from_text(freq_text);
    }

    /// Get the number of words in the loaded dictionary
    pub fn word_count(&self) -> usize {
        self.dictionary.words.len()
    }

    /// Predict words based on a swipe input pattern
    ///
    /// # Arguments
    /// * `swipe_input` - The swipe pattern as a string of characters
    /// * `limit` - Maximum number of predictions to return
    ///
    /// # Returns
    /// A vector of predictions sorted by combined score (DTW distance adjusted by word frequency)
    pub fn predict(&self, swipe_input: &str, limit: usize) -> Vec<Prediction> {
        let raw_input_path = get_word_path(swipe_input, &self.layout);

        if raw_input_path.is_empty() {
            return vec![];
        }

        let input_path = simplify_path(&raw_input_path);
        let input_len = input_path.len() as f64;

        let first_char = match swipe_input.chars().next() {
            Some(c) => c.to_ascii_lowercase(),
            None => return vec![],
        };
        let first_char_pt = self.layout.get(&first_char).cloned().unwrap_or(Point { x: 0.0, y: 0.0 });
        let last_char = swipe_input.chars().last().unwrap().to_ascii_lowercase();
        let last_char_pt = self.layout.get(&last_char).cloned().unwrap_or(Point { x: 0.0, y: 0.0 });

        let window = (input_path.len() / 2).max(10);
        let mut best_score = f64::INFINITY;

        let mut candidates: Vec<(String, f64, f64)> = self.dictionary.words
            .iter()
            .filter(|w| !w.is_empty())
            .filter_map(|w| {
                let word_first_char = w.chars().next().unwrap();
                let mut start_penalty = 0.0;

                if word_first_char != first_char {
                    if let Some(word_first_pt) = self.layout.get(&word_first_char) {
                        start_penalty = euclidean_dist(&first_char_pt, word_first_pt) * 5.0;
                    } else {
                        start_penalty = 50.0;
                    }
                }

                let word_last_char = w.chars().last().unwrap();
                let mut end_penalty = 0.0;

                if word_last_char != last_char {
                    if let Some(word_last_pt) = self.layout.get(&word_last_char) {
                        end_penalty = euclidean_dist(&last_char_pt, word_last_pt) * 5.0;
                    } else {
                        end_penalty = 50.0;
                    }
                }

                let cutoff = best_score * input_len;
                let word_path = get_word_path(w, &self.layout);
                let dist = dtw_distance_fast(&input_path, &word_path, window, cutoff);

                if dist == f64::INFINITY {
                    return None;
                }

                let score = (dist + start_penalty + end_penalty) / input_len;
                if score < best_score {
                    best_score = score;
                }

                let word_freq = *self.dictionary.freq.get(w.as_str()).unwrap_or(&0.0);
                Some((w.clone(), score, word_freq))
            })
            .collect();

        candidates.sort_by(|a, b| {
            let combined_a = a.1 - a.2 * self.pop_weight;
            let combined_b = b.1 - b.2 * self.pop_weight;
            combined_a.partial_cmp(&combined_b).unwrap_or(std::cmp::Ordering::Equal)
        });

        candidates
            .into_iter()
            .take(limit)
            .map(|(word, score, freq)| Prediction { word, score, freq })
            .collect()
    }
}

impl Default for SwipeEngine {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_engine_creation() {
        let engine = SwipeEngine::new();
        assert_eq!(engine.word_count(), 0);
    }

    #[test]
    fn test_dictionary_loading() {
        let mut engine = SwipeEngine::new();
        engine.load_dictionary("hello\t1000\nworld\t500\n");
        assert_eq!(engine.word_count(), 2);
    }

    #[test]
    fn test_prediction() {
        let mut engine = SwipeEngine::new();
        engine.load_dictionary("hello\t1000\nhello\t1000\nhelp\t800\nhell\t600\n");

        let predictions = engine.predict("hello", 5);
        assert!(!predictions.is_empty());
        // The exact word "hello" should be among top predictions
        assert!(predictions.iter().any(|p| p.word == "hello"));
    }
}
