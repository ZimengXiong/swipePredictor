//! WASM bindings for the swipe engine (feature-gated)

use crate::keyboard::{euclidean_dist, get_keyboard_layout, get_word_path, simplify_path};
use crate::dtw::dtw_distance_fast;
use crate::types::{Dictionary, Point, Prediction};
use std::cell::RefCell;
use wasm_bindgen::prelude::*;

thread_local! {
    static DICTIONARY: RefCell<Option<Dictionary>> = const { RefCell::new(None) };
}

#[wasm_bindgen]
pub fn init_dictionary(freq_text: &str) {
    let mut dict = Dictionary::new();
    dict.load_from_text(freq_text);
    DICTIONARY.with(|d| {
        *d.borrow_mut() = Some(dict);
    });
}

#[wasm_bindgen]
pub fn predict_wasm(swipe_input: &str, limit: usize) -> String {
    let pop_weight = 0.25;

    DICTIONARY.with(|d| {
        let dict = d.borrow();
        let dict = match dict.as_ref() {
            Some(d) => d,
            None => return "[]".to_string(),
        };

        let layout = get_keyboard_layout();
        let raw_input_path = get_word_path(swipe_input, &layout);

        if raw_input_path.is_empty() {
            return "[]".to_string();
        }

        let input_path = simplify_path(&raw_input_path);
        let input_len = input_path.len() as f64;

        let first_char = match swipe_input.chars().next() {
            Some(c) => c,
            None => return "[]".to_string(),
        };
        let first_char_pt = layout.get(&first_char).cloned().unwrap_or(Point { x: 0.0, y: 0.0 });
        let last_char = swipe_input.chars().last().unwrap();
        let last_char_pt = layout.get(&last_char).cloned().unwrap_or(Point { x: 0.0, y: 0.0 });

        let window = (input_path.len() / 2).max(10);
        let mut best_score = f64::INFINITY;

        let mut candidates: Vec<(String, f64, f64)> = dict.words
            .iter()
            .filter(|w| !w.is_empty())
            .filter_map(|w| {
                let word_first_char = w.chars().next().unwrap();
                let mut start_penalty = 0.0;

                if word_first_char != first_char {
                    if let Some(word_first_pt) = layout.get(&word_first_char) {
                        start_penalty = euclidean_dist(&first_char_pt, word_first_pt) * 5.0;
                    } else {
                        start_penalty = 50.0;
                    }
                }

                let word_last_char = w.chars().last().unwrap();
                let mut end_penalty = 0.0;

                if word_last_char != last_char {
                    if let Some(word_last_pt) = layout.get(&word_last_char) {
                        end_penalty = euclidean_dist(&last_char_pt, word_last_pt) * 5.0;
                    } else {
                        end_penalty = 50.0;
                    }
                }

                let cutoff = best_score * input_len;
                let word_path = get_word_path(w, &layout);
                let dist = dtw_distance_fast(&input_path, &word_path, window, cutoff);

                if dist == f64::INFINITY {
                    return None;
                }

                let score = (dist + start_penalty + end_penalty) / input_len;
                if score < best_score {
                    best_score = score;
                }

                let word_freq = *dict.freq.get(w.as_str()).unwrap_or(&0.0);
                Some((w.clone(), score, word_freq))
            })
            .collect();

        candidates.sort_by(|a, b| {
            let combined_a = a.1 - a.2 * pop_weight;
            let combined_b = b.1 - b.2 * pop_weight;
            combined_a.partial_cmp(&combined_b).unwrap_or(std::cmp::Ordering::Equal)
        });

        let predictions: Vec<Prediction> = candidates
            .into_iter()
            .take(limit)
            .map(|(word, score, freq)| Prediction { word, score, freq })
            .collect();

        serde_json::to_string(&predictions).unwrap_or_else(|_| "[]".to_string())
    })
}
