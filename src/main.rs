use anyhow::{Context, Result};
use clap::Parser;
use colored::*;
use rayon::prelude::*;
use std::collections::HashMap;
use std::fs::File;
use std::io::{self, BufRead, Write};
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};
use swipe_predictor_rs::{dtw_distance_fast, euclidean_dist, get_keyboard_layout, get_word_path, simplify_path, Point};

#[derive(Parser, Debug)]
#[command(author, version, about = "Swipe/Gesture Typing Predictor in Rust")]
struct Args {
    swipe: Option<String>,

    /// # of suggestions to show
    #[arg(short, long, default_value_t = 5)]
    limit: usize,

    #[arg(short, long, default_value = "words.txt")]
    words: PathBuf,

    #[arg(short, long, default_value = "word_freq.txt")]
    freq: PathBuf,

    /// popularity weight factor (higher = more influence from word frequency)
    #[arg(long, default_value_t = 1.0)]
    pop_weight: f64,
}

fn load_words(path: &PathBuf) -> Result<Vec<String>> {
    let file = File::open(path).with_context(|| format!("Failed to open dictionary file: {:?}", path))?;
    let reader = io::BufReader::new(file);
    let mut words = Vec::new();
    for line in reader.lines() {
        let line = line?;
        let trimmed = line.trim();
        if !trimmed.is_empty() {
            words.push(trimmed.to_lowercase());
        }
    }
    Ok(words)
}

fn load_frequencies(path: &PathBuf) -> Result<HashMap<String, f64>> {
    let mut freq_map = HashMap::new();

    let file = match File::open(path) {
        Ok(f) => f,
        Err(_) => {
            eprintln!("{}", format!("Warning: Frequency file {:?} not found. Using uniform frequencies.", path).yellow());
            return Ok(freq_map);
        }
    };

    let reader = io::BufReader::new(file);
    let mut max_freq: f64 = 0.0;

    // First pass: find max frequency for normalization
    let lines: Vec<String> = reader.lines().filter_map(|l| l.ok()).collect();
    for line in &lines {
        if let Some((_, count_str)) = line.split_once('\t') {
            if let Ok(count) = count_str.parse::<f64>() {
                max_freq = max_freq.max(count);
            }
        }
    }

    // Second pass: store normalized log frequencies
    for line in &lines {
        if let Some((word, count_str)) = line.split_once('\t') {
            if let Ok(count) = count_str.parse::<f64>() {
                // Log-normalize: higher = more common, range roughly 0-1
                let log_freq = (count.ln() - 1.0) / (max_freq.ln());
                freq_map.insert(word.to_lowercase(), log_freq.max(0.0));
            }
        }
    }

    Ok(freq_map)
}

fn predict(swipe_input: &str, words: &[String], freq: &HashMap<String, f64>, limit: usize, pop_weight: f64) {
    let layout = get_keyboard_layout();
    let raw_input_path = get_word_path(swipe_input, &layout);

    if raw_input_path.is_empty() {
        println!("{}", "Invalid swipe input (no valid QWERTY characters).".red());
        return;
    }

    let input_path = simplify_path(&raw_input_path);
    let input_len = input_path.len() as f64;

    let first_char = swipe_input.chars().next().unwrap();
    let last_char = swipe_input.chars().last().unwrap();

    let last_char_pt = layout.get(&last_char).cloned().unwrap_or(Point { x: 0.0, y: 0.0 });

    // Sakoe-Chiba window size - adaptive based on input length
    let window = (input_path.len() / 2).max(10);

    // Atomic for tracking best score for early termination
    let best_score = AtomicU64::new(f64::INFINITY.to_bits());

    // Parallel filtering and scoring
    let mut candidates: Vec<(String, f64, f64)> = words
        .par_iter()
        .filter(|w| {
            if w.is_empty() { return false; }
            w.starts_with(first_char)
        })
        .filter_map(|w| {
            let word_last_char = w.chars().last().unwrap();
            let mut end_penalty = 0.0;

            if word_last_char != last_char {
                if let Some(word_last_pt) = layout.get(&word_last_char) {
                    end_penalty = euclidean_dist(&last_char_pt, word_last_pt) * 5.0;
                } else {
                    end_penalty = 50.0;
                }
            }

            // Get current best for cutoff
            let current_best = f64::from_bits(best_score.load(Ordering::Relaxed));
            let cutoff = current_best * input_len;

            let word_path = get_word_path(w, &layout);
            let dist = dtw_distance_fast(&input_path, &word_path, window, cutoff);

            if dist == f64::INFINITY {
                return None;
            }

            let score = (dist + end_penalty) / input_len;

            // Update best score atomically
            let mut current = best_score.load(Ordering::Relaxed);
            loop {
                let current_score = f64::from_bits(current);
                if score >= current_score {
                    break;
                }
                match best_score.compare_exchange_weak(
                    current,
                    score.to_bits(),
                    Ordering::Relaxed,
                    Ordering::Relaxed,
                ) {
                    Ok(_) => break,
                    Err(x) => current = x,
                }
            }

            // Get word frequency (default to 0 if unknown)
            let word_freq = *freq.get(w.as_str()).unwrap_or(&0.0);

            Some((w.clone(), score, word_freq))
        })
        .collect();

    // Sort by combined score: DTW score * (1 - popularity * weight)
    // This makes popularity influence scale proportionally with score differences
    candidates.sort_by(|a, b| {
        let combined_a = a.1 * (1.0 - a.2 * pop_weight).max(0.1);
        let combined_b = b.1 * (1.0 - b.2 * pop_weight).max(0.1);
        combined_a.partial_cmp(&combined_b).unwrap_or(std::cmp::Ordering::Equal)
    });

    println!("\n{}", format!("Predictions for '{}'", swipe_input).bold().cyan());
    println!("{}", "-".repeat(45));
    println!("{:<5} | {:<15} | {:<10} | {:<6}", "Rank", "Word", "Score", "Freq");
    println!("{}", "-".repeat(45));

    for (i, (word, score, word_freq)) in candidates.iter().take(limit).enumerate() {
        println!(
            "{} | {} | {} | {}",
            format!("{:<5}", i + 1).yellow(),
            format!("{:<15}", word).magenta(),
            format!("{:<10.4}", score).green(),
            format!("{:<6.3}", word_freq).cyan()
        );
    }
}

fn main() -> Result<()> {
    let args = Args::parse();

    if !args.words.exists() {
        println!("{}", format!("Warning: Word file {:?} not found.", args.words).red());
    }

    let words = load_words(&args.words)?;
    let freq = load_frequencies(&args.freq)?;

    println!("{}", format!("Loaded {} words, {} with frequency data", words.len(), freq.len()).dimmed());

    if let Some(swipe) = args.swipe {
        predict(&swipe, &words, &freq, args.limit, args.pop_weight);
    } else {
        println!("{}", "Starting Interactive Mode. Type 'exit' or 'quit' to stop.".yellow().bold());
        loop {
            print!("{}", "Enter swipe pattern: ".blue().bold());
            io::stdout().flush()?;

            let mut input = String::new();
            io::stdin().read_line(&mut input)?;
            let input = input.trim().to_lowercase();

            if input == "exit" || input == "quit" {
                break;
            }
            if input.is_empty() {
                continue;
            }

            predict(&input, &words, &freq, args.limit, args.pop_weight);
        }
    }

    Ok(())
}
