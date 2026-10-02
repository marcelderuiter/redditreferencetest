//! Walkable surface heights on a fixed XZ grid. Movement and reachability use
//! it headlessly; rendering never feeds back into it.
use std::collections::VecDeque;

pub const CELL: f32 = 0.25;
/// Largest height change between neighbouring cells a walker may take.
pub const STEP: f32 = 0.3;

#[derive(Clone, Debug, Default)]
pub struct WalkGrid {
    pub origin: (f32, f32),
    pub width: usize,
    pub depth: usize,
    pub heights: Vec<f32>,
}

impl WalkGrid {
    pub fn new(min: (f32, f32), max: (f32, f32)) -> WalkGrid {
        let width = ((max.0 - min.0) / CELL).ceil() as usize + 1;
        let depth = ((max.1 - min.1) / CELL).ceil() as usize + 1;
        WalkGrid { origin: min, width, depth, heights: vec![f32::NAN; width * depth] }
    }

    fn index(&self, x: f32, z: f32) -> Option<usize> {
        let i = ((x - self.origin.0) / CELL).floor();
        let j = ((z - self.origin.1) / CELL).floor();
        (i >= 0.0 && j >= 0.0 && (i as usize) < self.width && (j as usize) < self.depth)
            .then(|| j as usize * self.width + i as usize)
    }

    pub fn height(&self, x: f32, z: f32) -> Option<f32> {
        self.index(x, z).map(|i| self.heights[i]).filter(|h| h.is_finite())
    }

    /// Mark cells whose centres fall inside the rectangle with `h(x, z)`.
    pub fn fill(&mut self, x0: f32, z0: f32, x1: f32, z1: f32, h: impl Fn(f32, f32) -> f32) {
        self.each_cell(x0, z0, x1, z1, |grid, i, x, z| grid.heights[i] = h(x, z));
    }

    pub fn block(&mut self, x0: f32, z0: f32, x1: f32, z1: f32) {
        self.each_cell(x0, z0, x1, z1, |grid, i, _, _| grid.heights[i] = f32::NAN);
    }

    pub fn each_cell(&mut self, x0: f32, z0: f32, x1: f32, z1: f32, mut f: impl FnMut(&mut WalkGrid, usize, f32, f32)) {
        let (ax, bx) = (x0.min(x1), x0.max(x1));
        let (az, bz) = (z0.min(z1), z0.max(z1));
        for j in 0..self.depth {
            let z = self.origin.1 + (j as f32 + 0.5) * CELL;
            if z < az || z > bz {
                continue;
            }
            for i in 0..self.width {
                let x = self.origin.0 + (i as f32 + 0.5) * CELL;
                if x >= ax && x <= bx {
                    f(self, j * self.width + i, x, z);
                }
            }
        }
    }

    pub fn walkable_cells(&self) -> usize {
        self.heights.iter().filter(|h| h.is_finite()).count()
    }

    /// Cells reachable from `start` stepping between 4-neighbours.
    pub fn reachable(&self, start: (f32, f32)) -> Vec<bool> {
        let mut seen = vec![false; self.heights.len()];
        let Some(first) = self.index(start.0, start.1).filter(|&i| self.heights[i].is_finite()) else {
            return seen;
        };
        let mut queue = VecDeque::from([first]);
        seen[first] = true;
        while let Some(i) = queue.pop_front() {
            let (x, z) = (i % self.width, i / self.width);
            let h = self.heights[i];
            let neighbours = [
                (x > 0).then(|| i - 1),
                (x + 1 < self.width).then(|| i + 1),
                (z > 0).then(|| i - self.width),
                (z + 1 < self.depth).then(|| i + self.width),
            ];
            for n in neighbours.into_iter().flatten() {
                if !seen[n] && self.heights[n].is_finite() && (self.heights[n] - h).abs() <= STEP {
                    seen[n] = true;
                    queue.push_back(n);
                }
            }
        }
        seen
    }

    pub fn is_reached(&self, seen: &[bool], x: f32, z: f32) -> bool {
        self.index(x, z).is_some_and(|i| seen[i])
    }
}
