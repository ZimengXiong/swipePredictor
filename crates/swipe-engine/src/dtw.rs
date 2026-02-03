use crate::keyboard::euclidean_dist;
use crate::types::Point;

pub fn dtw_distance_fast(s: &[Point], t: &[Point], window: usize, cutoff: f64) -> f64 {
    let n = s.len();
    let m = t.len();
    if n == 0 || m == 0 {
        return f64::INFINITY;
    }

    let len_diff = (n as i64 - m as i64).unsigned_abs() as usize;
    if len_diff > window {
        return f64::INFINITY;
    }

    let mut prev = vec![f64::INFINITY; m + 1];
    let mut curr = vec![f64::INFINITY; m + 1];
    prev[0] = 0.0;

    for i in 1..=n {
        curr[0] = f64::INFINITY;
        let j_start = if i > window { i - window } else { 1 };
        let j_end = (i + window).min(m);

        if j_start > 1 {
            curr[j_start - 1] = f64::INFINITY;
        }

        let mut row_min = f64::INFINITY;
        for j in j_start..=j_end {
            let cost = euclidean_dist(&s[i - 1], &t[j - 1]);
            let prev_min = prev[j].min(curr[j - 1]).min(prev[j - 1]);
            curr[j] = cost + prev_min;
            row_min = row_min.min(curr[j]);
        }

        if row_min > cutoff {
            return f64::INFINITY;
        }

        std::mem::swap(&mut prev, &mut curr);
    }

    prev[m]
}

#[allow(dead_code)]
pub fn dtw_distance(s: &[Point], t: &[Point]) -> f64 {
    let n = s.len();
    let m = t.len();
    if n == 0 || m == 0 {
        return f64::INFINITY;
    }

    let mut dtw = vec![vec![f64::INFINITY; m + 1]; n + 1];
    dtw[0][0] = 0.0;

    for i in 1..=n {
        for j in 1..=m {
            let cost = euclidean_dist(&s[i - 1], &t[j - 1]);
            let prev_min = dtw[i - 1][j].min(dtw[i][j - 1]).min(dtw[i - 1][j - 1]);
            dtw[i][j] = cost + prev_min;
        }
    }

    dtw[n][m]
}
