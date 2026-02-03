use crate::types::Point;
use std::collections::HashMap;

pub fn get_keyboard_layout() -> HashMap<char, Point> {
    let mut layout = HashMap::new();
    let rows = [
        ("qwertyuiop", 0.0, 0.0),
        ("asdfghjkl", 0.5, 1.0),
        ("zxcvbnm", 1.5, 2.0),
    ];

    for (chars, x_offset, y) in rows {
        for (i, c) in chars.chars().enumerate() {
            layout.insert(c, Point { x: i as f64 + x_offset, y });
        }
    }
    layout
}

pub fn get_word_path(word: &str, layout: &HashMap<char, Point>) -> Vec<Point> {
    let key_points: Vec<Point> = word.chars()
        .filter_map(|c| layout.get(&c.to_ascii_lowercase()).cloned())
        .collect();

    if key_points.is_empty() {
        return vec![];
    }

    let step_size = 0.5;
    let mut full_path = vec![key_points[0]];

    for i in 1..key_points.len() {
        let p1 = key_points[i - 1];
        let p2 = key_points[i];

        let dist = euclidean_dist(&p1, &p2);
        if dist > step_size {
            let num_steps = (dist / step_size) as i32;
            let dx = (p2.x - p1.x) / num_steps as f64;
            let dy = (p2.y - p1.y) / num_steps as f64;

            for s in 1..num_steps {
                let new_x = p1.x + dx * s as f64;
                let new_y = p1.y + dy * s as f64;
                full_path.push(Point { x: new_x, y: new_y });
            }
        }
        full_path.push(p2);
    }

    full_path
}

pub fn euclidean_dist(p1: &Point, p2: &Point) -> f64 {
    ((p1.x - p2.x).powi(2) + (p1.y - p2.y).powi(2)).sqrt()
}

pub fn simplify_path(path: &[Point]) -> Vec<Point> {
    if path.is_empty() {
        return vec![];
    }

    let mut new_path = vec![path[0]];
    for p in path.iter().skip(1) {
        if euclidean_dist(p, new_path.last().unwrap()) > 0.01 {
            new_path.push(*p);
        }
    }
    new_path
}
