//! The player's miniature: fixed-step movement over the walk grid.
use crate::math::{V3, v3};
use crate::walk::{STEP, WalkGrid};

pub const TICK: f32 = 1.0 / 120.0;
pub const SPEED: f32 = 3.2;
const RADIUS: f32 = 0.22;

#[derive(Clone, Debug)]
pub struct Player {
    pub position: V3,
    pub yaw: f32,
    /// Walk-cycle phase for the presentation bob; advances only while moving.
    pub stride: f32,
    accumulator: f32,
}

impl Player {
    pub fn new(spawn: V3) -> Player {
        Player { position: spawn, yaw: 0.0, stride: 0.0, accumulator: 0.0 }
    }

    /// `input` is a world-space XZ direction (length <= 1).
    pub fn advance(&mut self, walk: &WalkGrid, seconds: f32, input: (f32, f32)) {
        self.accumulator = (self.accumulator + seconds).min(0.25);
        while self.accumulator >= TICK {
            self.accumulator -= TICK;
            self.tick(walk, input);
        }
    }

    pub fn tick(&mut self, walk: &WalkGrid, input: (f32, f32)) {
        let len = (input.0 * input.0 + input.1 * input.1).sqrt();
        if len < 1e-3 {
            return;
        }
        let dir = (input.0 / len.max(1.0), input.1 / len.max(1.0));
        let step = SPEED * TICK;
        let target_yaw = dir.0.atan2(dir.1);
        let mut d = (target_yaw - self.yaw).rem_euclid(std::f32::consts::TAU);
        if d > std::f32::consts::PI {
            d -= std::f32::consts::TAU;
        }
        self.yaw += d.clamp(-12.0 * TICK, 12.0 * TICK);
        // Slide along blocked axes.
        for (mx, mz) in [(dir.0, dir.1), (dir.0, 0.0), (0.0, dir.1)] {
            if mx == 0.0 && mz == 0.0 {
                continue;
            }
            let next = v3(self.position.x + mx * step, 0.0, self.position.z + mz * step);
            if let Some(h) = self.support(walk, next) {
                self.position = v3(next.x, h, next.z);
                self.stride += step;
                return;
            }
        }
    }

    fn support(&self, walk: &WalkGrid, p: V3) -> Option<f32> {
        let centre = walk.height(p.x, p.z)?;
        if (centre - self.position.y).abs() > STEP {
            return None;
        }
        for (ox, oz) in [(RADIUS, 0.0), (-RADIUS, 0.0), (0.0, RADIUS), (0.0, -RADIUS)] {
            let h = walk.height(p.x + ox, p.z + oz)?;
            if (h - centre).abs() > STEP * 1.5 {
                return None;
            }
        }
        Some(centre)
    }
}
