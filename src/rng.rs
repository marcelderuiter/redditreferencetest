//! Seeded SplitMix64 stream plus hash noise. Identical output on every platform.

/// Interior mutability lets callers draw numbers while building arguments for
/// `&mut self` construction calls.
#[derive(Clone, Debug)]
pub struct Rng(std::cell::Cell<u64>);

impl Rng {
    pub fn new(seed: u64) -> Rng {
        Rng(std::cell::Cell::new(seed ^ 0x9E37_79B9_7F4A_7C15))
    }
    pub fn next_u64(&self) -> u64 {
        let state = self.0.get().wrapping_add(0x9E37_79B9_7F4A_7C15);
        self.0.set(state);
        mix(state)
    }
    /// Uniform in [0, 1).
    pub fn f(&self) -> f32 {
        (self.next_u64() >> 40) as f32 / (1u64 << 24) as f32
    }
    pub fn range(&self, lo: f32, hi: f32) -> f32 {
        lo + (hi - lo) * self.f()
    }
    /// Symmetric jitter in [-a, a).
    pub fn sym(&self, a: f32) -> f32 {
        (self.f() * 2.0 - 1.0) * a
    }
    pub fn chance(&self, p: f32) -> bool {
        self.f() < p
    }
    pub fn below(&self, n: usize) -> usize {
        (self.next_u64() % n.max(1) as u64) as usize
    }
    pub fn fork(&self) -> Rng {
        Rng::new(self.next_u64())
    }
}

pub fn mix(mut z: u64) -> u64 {
    z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
    z ^ (z >> 31)
}

fn lattice(seed: u64, x: i32, y: i32, z: i32) -> f32 {
    let h = mix(seed ^ (x as u32 as u64).wrapping_mul(0x8DA6_B343)
        ^ (y as u32 as u64).wrapping_mul(0xD816_3841) << 1
        ^ (z as u32 as u64).wrapping_mul(0xCB1A_B31F) << 2);
    (h >> 40) as f32 / (1u64 << 24) as f32 * 2.0 - 1.0
}

/// Smooth value noise in [-1, 1].
pub fn noise3(seed: u64, x: f32, y: f32, z: f32) -> f32 {
    let (fx, fy, fz) = (x.floor(), y.floor(), z.floor());
    let (ix, iy, iz) = (fx as i32, fy as i32, fz as i32);
    let s = |t: f32| t * t * (3.0 - 2.0 * t);
    let (tx, ty, tz) = (s(x - fx), s(y - fy), s(z - fz));
    let mut acc = 0.0;
    for dz in 0..2 {
        for dy in 0..2 {
            for dx in 0..2 {
                let w = (if dx == 1 { tx } else { 1.0 - tx })
                    * (if dy == 1 { ty } else { 1.0 - ty })
                    * (if dz == 1 { tz } else { 1.0 - tz });
                acc += w * lattice(seed, ix + dx, iy + dy, iz + dz);
            }
        }
    }
    acc
}

pub fn noise1(seed: u64, x: f32) -> f32 {
    noise3(seed, x, 0.37, 0.71)
}
