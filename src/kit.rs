//! Masonry, timber and metal construction kit. Every structure is built from
//! many individual jittered pieces so silhouettes and edges stay irregular,
//! like a hand-built tabletop diorama.
use crate::math::{Basis, V3, Xf, lerp, v3};
use crate::rng::{Rng, noise1};
use crate::scene::Scene;

/// Display sRGB (0-255) to linear albedo with alpha 1.
pub fn srgb(r: u8, g: u8, b: u8) -> [f32; 4] {
    let f = |c: u8| {
        let c = c as f32 / 255.0;
        if c <= 0.04045 { c / 12.92 } else { ((c + 0.055) / 1.055).powf(2.4) }
    };
    [f(r), f(g), f(b), 1.0]
}

pub fn shade(c: [f32; 4], k: f32) -> [f32; 4] {
    [c[0] * k, c[1] * k, c[2] * k, c[3]]
}

pub fn mix(a: [f32; 4], b: [f32; 4], t: f32) -> [f32; 4] {
    [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t), lerp(a[3], b[3], t)]
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Side {
    North,
    South,
    East,
    West,
}

pub struct Kit {
    pub scene: Scene,
    pub rng: Rng,
    stone_tones: Vec<[f32; 4]>,
    /// Furniture and figures are built at human scale, then enlarged about
    /// their anchor so they read like chunky tabletop miniatures.
    pub prop_scale: f32,
    prop_depth: u32,
    pending_blocks: Vec<[f32; 4]>,
}

pub const WOOD: (u8, u8, u8) = (96, 66, 44);
pub const WOOD_DARK: (u8, u8, u8) = (58, 41, 30);
pub const BRASS: (u8, u8, u8) = (206, 160, 86);
pub const IRON: (u8, u8, u8) = (64, 62, 60);

impl Kit {
    pub fn new(seed: u64) -> Kit {
        Kit {
            scene: Scene::default(),
            rng: Rng::new(seed),
            stone_tones: vec![
                srgb(132, 120, 106),
                srgb(116, 106, 96),
                srgb(146, 132, 114),
                srgb(102, 95, 88),
                srgb(126, 110, 92),
                srgb(110, 104, 98),
            ],
            prop_scale: 1.0,
            prop_depth: 0,
            pending_blocks: Vec::new(),
        }
    }

    /// Run a prop builder; the outermost call scales everything it adds
    /// (instances, lights, walk blocks) by `prop_scale` about `anchor`.
    pub fn prop(&mut self, anchor: V3, build: impl FnOnce(&mut Kit)) {
        let outer = self.prop_depth == 0;
        let s = if outer { self.prop_scale } else { 1.0 };
        let marks: std::collections::HashMap<_, usize> = if s != 1.0 {
            self.scene.batches.iter().map(|(k, v)| (*k, v.len())).collect()
        } else {
            Default::default()
        };
        let first_light = self.scene.lights.len();
        self.prop_depth += 1;
        build(self);
        self.prop_depth -= 1;
        if !outer {
            return;
        }
        if s != 1.0 {
            let a = [anchor.x, anchor.y, anchor.z];
            for (key, data) in self.scene.batches.iter_mut() {
                let start = marks.get(key).copied().unwrap_or(0);
                for inst in data[start..].chunks_exact_mut(crate::scene::STRIDE) {
                    for row in 0..3 {
                        for col in 0..3 {
                            inst[row * 4 + col] *= s;
                        }
                        inst[row * 4 + 3] = a[row] + (inst[row * 4 + 3] - a[row]) * s;
                    }
                }
            }
            for light in &mut self.scene.lights[first_light..] {
                light.position = anchor + (light.position - anchor) * s;
                light.range *= s;
                light.energy *= s.sqrt();
            }
        }
        for [x0, z0, x1, z1] in std::mem::take(&mut self.pending_blocks) {
            let fx = |x: f32| anchor.x + (x - anchor.x) * s;
            let fz = |z: f32| anchor.z + (z - anchor.z) * s;
            self.scene.walk.block(fx(x0), fz(z0), fx(x1), fz(z1));
        }
    }

    /// Block walking over a prop footprint (deferred until the prop is scaled).
    pub fn block(&mut self, x0: f32, z0: f32, x1: f32, z1: f32) {
        if self.prop_depth > 0 {
            self.pending_blocks.push([x0, z0, x1, z1]);
        } else {
            self.scene.walk.block(x0, z0, x1, z1);
        }
    }

    pub fn wood(&mut self) -> [f32; 4] {
        let k = self.rng.range(0.8, 1.15);
        shade(srgb(WOOD.0, WOOD.1, WOOD.2), k)
    }
    pub fn wood_dark(&mut self) -> [f32; 4] {
        let k = self.rng.range(0.85, 1.1);
        shade(srgb(WOOD_DARK.0, WOOD_DARK.1, WOOD_DARK.2), k)
    }
    pub fn brass(&mut self) -> [f32; 4] {
        let k = self.rng.range(0.85, 1.05);
        shade(srgb(BRASS.0, BRASS.1, BRASS.2), k)
    }
    pub fn iron(&mut self) -> [f32; 4] {
        srgb(IRON.0, IRON.1, IRON.2)
    }

    fn stone_tone(&mut self) -> [f32; 4] {
        let i = self.rng.below(self.stone_tones.len());
        // Wide per-stone spread: the reference reads as a mosaic of light and
        // dark blocks, which carries most of its local contrast.
        let k = self.rng.range(0.62, 1.22);
        shade(self.stone_tones[i], k)
    }

    /// One cut stone. `basis` orients it; size is its full extent.
    pub fn stone(&mut self, center: V3, size: V3, basis: Basis, tone: f32) {
        let mesh = ["stone0", "stone1", "stone2", "stone3"][self.rng.below(4)];
        let jitter = Basis::euler(self.rng.sym(0.025), self.rng.sym(0.018), self.rng.sym(0.018));
        let color = shade(self.stone_tone(), tone);
        let custom = [self.rng.f(), self.rng.f(), 0.0, 0.0];
        self.scene.put(mesh, "stone", Xf::new(center, basis * jitter, size), color, custom);
    }

    /// Flat paving slab: crisper edges than wall stones.
    pub fn flag(&mut self, center: V3, size: V3, basis: Basis, tone: f32) {
        let mesh = ["flag0", "flag1"][self.rng.below(2)];
        let color = shade(self.stone_tone(), tone * self.rng.range(0.95, 1.08));
        let custom = [self.rng.f(), self.rng.f(), 0.0, 0.0];
        self.scene.put(mesh, "stone", Xf::new(center, basis, size), color, custom);
    }

    pub fn put_box(&mut self, material: &'static str, center: V3, size: V3, basis: Basis, color: [f32; 4]) {
        let custom = [self.rng.f(), 0.0, 0.0, 0.0];
        self.scene.put("box", material, Xf::new(center, basis, size), color, custom);
    }

    /// Courses of bricks between `a` and `b` (XZ), rising from `y0`. `height(s)`
    /// gives the wall top above `y0` at distance `s`; `gaps` are open spans;
    /// `windows` are (centre s, width, sill, top) lancet openings.
    pub fn wall(&mut self, a: (f32, f32), b: (f32, f32), y0: f32, thick: f32, height: &dyn Fn(f32) -> f32, gaps: &[(f32, f32)], windows: &[(f32, f32, f32, f32)]) {
        let dir = v3(b.0 - a.0, 0.0, b.1 - a.1);
        let length = dir.length();
        let basis = Basis::looking(dir);
        let course = 0.34;
        let seed = self.rng.next_u64();
        let max_h = (0..=40).map(|i| height(length * i as f32 / 40.0)).fold(0.0f32, f32::max);
        let courses = (max_h / course).ceil() as usize;
        for k in 0..courses {
            let y = y0 + course * (k as f32 + 0.5);
            let mut s = if k % 2 == 0 { 0.0 } else { -self.rng.range(0.2, 0.35) };
            while s < length {
                let len = self.rng.range(0.48, 0.9);
                let (s0, s1) = (s.max(0.0), (s + len).min(length));
                s += len;
                if s1 - s0 < 0.12 {
                    continue;
                }
                let mid = (s0 + s1) * 0.5;
                // Ragged tops: course must sit below the wall profile here.
                let top = height(mid) + noise1(seed, mid * 1.3) * 0.25;
                if (k as f32 + 1.0) * course > top + 0.05 {
                    continue;
                }
                if gaps.iter().any(|&(g0, g1)| s1 > g0 && s0 < g1) {
                    continue;
                }
                let (c0, c1) = (k as f32 * course, (k as f32 + 1.0) * course);
                if windows.iter().any(|&(c, w, sill, top)| s1 > c - w * 0.5 && s0 < c + w * 0.5 && c1 > sill && c0 < top + 0.1) {
                    // Split the brick around the opening so jambs stay solid.
                    for &(c, w, sill, top) in windows {
                        if !(s1 > c - w * 0.5 && s0 < c + w * 0.5 && c1 > sill && c0 < top + 0.1) {
                            continue;
                        }
                        for (p0, p1) in [(s0, c - w * 0.5), (c + w * 0.5, s1)] {
                            if p1 - p0 > 0.1 {
                                let p = v3(a.0, y, a.1) + basis.z * ((p0 + p1) * 0.5);
                                self.stone(p, v3(thick * self.rng.range(0.9, 1.0), course - 0.03, p1 - p0 - 0.03), basis, 1.0);
                            }
                        }
                    }
                    continue;
                }
                let upper = (k as f32 + 1.0) * course > top - course;
                if upper && self.rng.chance(0.06) {
                    continue;
                }
                let inset = if self.rng.chance(0.07) { self.rng.sym(0.05) } else { self.rng.sym(0.012) };
                let p = v3(a.0, y, a.1) + basis.z * mid + basis.x * inset;
                let size = v3(thick * self.rng.range(0.9, 1.0), course - 0.045, s1 - s0 - 0.05);
                self.stone(p, size, basis, 1.0);
            }
        }
        for &(c, w, sill, top) in windows {
            let base = v3(a.0, y0, a.1) + basis.z * c;
            // Dark recess and a pointed arch of voussoirs.
            let dark = srgb(18, 14, 12);
            self.put_box("paint", base + V3::Y * ((sill + top) * 0.5), v3(thick * 0.3, top - sill, w + 0.05), basis, dark);
            let spring = top - w * 0.55;
            for side in [-1.0f32, 1.0] {
                for i in 0..4 {
                    let t = (i as f32 + 0.5) / 4.0;
                    let ang = t * std::f32::consts::FRAC_PI_2 * 0.9;
                    let r = w * 0.75;
                    let off = r * ang.sin();
                    let along = side * (w * 0.5 + 0.1 - r * (1.0 - ang.cos()));
                    let p = base + V3::Y * (spring + off) + basis.z * along;
                    let tilt = basis * Basis::rot_x(-side * ang);
                    self.stone(p, v3(thick * 1.04, 0.2, 0.26), tilt, 1.08);
                }
                // Jamb quoins.
                let mut y = sill;
                while y < spring {
                    self.stone(base + V3::Y * (y + 0.16) + basis.z * (side * (w * 0.5 + 0.12)), v3(thick * 1.04, 0.3, 0.26), basis, 1.08);
                    y += 0.34;
                }
            }
            self.stone(base + V3::Y * (sill - 0.06), v3(thick * 1.1, 0.12, w + 0.4), basis, 1.1);
        }
    }

    /// Square pier of large alternating blocks.
    pub fn pier(&mut self, x: f32, z: f32, y0: f32, y1: f32, size: f32) {
        let course = 0.42;
        let n = ((y1 - y0) / course).round().max(1.0) as usize;
        let h = (y1 - y0) / n as f32;
        for k in 0..n {
            let y = y0 + h * (k as f32 + 0.5);
            let half = size * 0.5;
            if k % 2 == 0 {
                for sx in [-1.0, 1.0] {
                    self.stone(v3(x + sx * half * 0.5, y, z), v3(half - 0.03, h - 0.03, size - 0.02), Basis::IDENTITY, 1.0);
                }
            } else {
                for sz in [-1.0, 1.0] {
                    self.stone(v3(x, y, z + sz * half * 0.5), v3(size - 0.02, h - 0.03, half - 0.03), Basis::IDENTITY, 1.0);
                }
            }
        }
        // Cap stone.
        self.stone(v3(x, y1 + 0.08, z), v3(size + 0.14, 0.16, size + 0.14), Basis::rot_y(self.rng.sym(0.05)), 1.05);
    }

    /// Flagstone floor whose top surface sits at `y`: slabs of mixed sizes
    /// packed on a fine grid so the joints never form a regular lattice.
    pub fn floor(&mut self, x0: f32, z0: f32, x1: f32, z1: f32, y: f32) {
        let unit = 0.3;
        let nx = ((x1 - x0) / unit).round().max(1.0) as usize;
        let nz = ((z1 - z0) / unit).round().max(1.0) as usize;
        let (tx, tz) = ((x1 - x0) / nx as f32, (z1 - z0) / nz as f32);
        let thick = 0.16;
        let mut used = vec![false; nx * nz];
        let shapes: [(usize, usize, f32); 7] = [(2, 2, 0.3), (3, 2, 0.16), (2, 3, 0.16), (3, 3, 0.1), (1, 2, 0.1), (2, 1, 0.1), (1, 1, 0.08)];
        let total: f32 = shapes.iter().map(|s| s.2).sum();
        for j in 0..nz {
            for i in 0..nx {
                if used[j * nx + i] {
                    continue;
                }
                let free = |w: usize, d: usize, used: &Vec<bool>| {
                    i + w <= nx && j + d <= nz && (0..d).all(|dj| (0..w).all(|di| !used[(j + dj) * nx + i + di]))
                };
                let mut pick = self.rng.f() * total;
                let mut shape = (1, 1);
                for &(w, d, p) in &shapes {
                    if pick < p {
                        shape = (w, d);
                        break;
                    }
                    pick -= p;
                }
                if !free(shape.0, shape.1, &used) {
                    shape = if free(2, 2, &used) { (2, 2) } else if free(2, 1, &used) { (2, 1) } else if free(1, 2, &used) { (1, 2) } else { (1, 1) };
                }
                let (w, d) = shape;
                for dj in 0..d {
                    for di in 0..w {
                        used[(j + dj) * nx + i + di] = true;
                    }
                }
                let cx = x0 + (i as f32 + w as f32 * 0.5) * tx;
                let cz = z0 + (j as f32 + d as f32 * 0.5) * tz;
                let size = v3(w as f32 * tx - 0.045, thick, d as f32 * tz - 0.045);
                let lift = self.rng.sym(0.012);
                if self.rng.chance(0.04) {
                    for _ in 0..3 {
                        let p = v3(cx + self.rng.sym(size.x * 0.25), y - thick * 0.5 - 0.01, cz + self.rng.sym(size.z * 0.25));
                        let s = v3(size.x * self.rng.range(0.35, 0.55), thick, size.z * self.rng.range(0.35, 0.55));
                        self.flag(p, s, Basis::rot_y(self.rng.sym(0.6)), 0.95);
                    }
                    continue;
                }
                let basis = Basis::euler(self.rng.sym(0.015), self.rng.sym(0.008), self.rng.sym(0.008));
                self.flag(v3(cx, y - thick * 0.5 + lift, cz), size, basis, 1.0);
            }
        }
        // Mortar bed below the slabs hides the gaps.
        let bed = srgb(46, 43, 40);
        self.put_box("stone", v3((x0 + x1) * 0.5, y - thick - 0.05, (z0 + z1) * 0.5), v3(x1 - x0, 0.12, z1 - z0), Basis::IDENTITY, bed);
    }

    /// Support under a room: a shallow masonry slab with corbels, carried on
    /// stone piers that descend into the abyss with open bays between them,
    /// braced by timber frames. The bays let the blue depths show through.
    pub fn tower(&mut self, x0: f32, z0: f32, x1: f32, z1: f32, top: f32, bottom: f32) {
        // Corbel band and slab courses.
        for (step, inset) in [(0usize, 0.0f32), (1, 0.18)] {
            let y = top - 0.22 - step as f32 * 0.4;
            self.ring_course(x0 + inset, z0 + inset, x1 - inset, z1 - inset, y, 0.38, 0.5, 0.55);
        }
        let inset = 0.45;
        let (ax, az, bx, bz) = (x0 + inset, z0 + inset, x1 - inset, z1 - inset);
        let slab_bottom = top - 2.6;
        let mut y = top - 1.05;
        while y > slab_bottom {
            self.ring_course(ax, az, bx, bz, y, 0.345, 0.5, 0.8);
            y -= 0.38;
        }
        let core = srgb(28, 27, 27);
        let (cx, cz) = ((x0 + x1) * 0.5, (z0 + z1) * 0.5);
        self.put_box("stone", v3(cx, (top - 0.4 + slab_bottom) * 0.5, cz), v3(bx - ax - 0.4, top - 0.4 - slab_bottom, bz - az - 0.4), Basis::IDENTITY, core);
        // Piers at the corners and every few metres along each face.
        let pier = 1.5;
        let mut posts: Vec<(f32, f32)> = Vec::new();
        let n_x = ((bx - ax) / 4.8).round().max(1.0) as usize;
        let n_z = ((bz - az) / 4.8).round().max(1.0) as usize;
        let px0 = ax + pier * 0.5;
        let px1 = bx - pier * 0.5;
        let pz0 = az + pier * 0.5;
        let pz1 = bz - pier * 0.5;
        for i in 0..=n_x {
            let x = px0 + (px1 - px0) * i as f32 / n_x as f32;
            posts.push((x, pz0));
            posts.push((x, pz1));
        }
        for j in 1..n_z {
            let z = pz0 + (pz1 - pz0) * j as f32 / n_z as f32;
            posts.push((px0, z));
            posts.push((px1, z));
        }
        // A central pier under larger rooms.
        if n_x >= 2 && n_z >= 2 {
            posts.push((cx, cz));
        }
        for &(px, pz) in &posts {
            let mut y = slab_bottom;
            let mut k = 0;
            while y > bottom {
                let fine = y > top - 18.0;
                let h = if fine { 0.42 } else { 0.7 };
                let half = pier * 0.5;
                if k % 2 == 0 {
                    for sx in [-1.0, 1.0] {
                        self.stone(v3(px + sx * half * 0.5, y - h * 0.5, pz), v3(half - 0.04, h - 0.04, pier - 0.03), Basis::IDENTITY, 0.95);
                    }
                } else {
                    for sz in [-1.0, 1.0] {
                        self.stone(v3(px, y - h * 0.5, pz + sz * half * 0.5), v3(pier - 0.03, h - 0.04, half - 0.04), Basis::IDENTITY, 0.95);
                    }
                }
                // Projecting string course every few metres.
                if k % 14 == 13 {
                    self.stone(v3(px, y - h - 0.12, pz), v3(pier + 0.3, 0.24, pier + 0.3), Basis::IDENTITY, 1.0);
                }
                y -= h;
                k += 1;
            }
            let c = srgb(30, 29, 29);
            self.put_box("stone", v3(px, (slab_bottom + bottom) * 0.5, pz), v3(pier - 0.3, slab_bottom - bottom, pier - 0.3), Basis::IDENTITY, c);
            // Haunch blocks easing pier into slab.
            self.stone(v3(px, slab_bottom - 0.2, pz), v3(pier + 0.5, 0.4, pier + 0.5), Basis::IDENTITY, 1.0);
        }
        // Timber bracing in some bays along the outer faces.
        let faces: Vec<((f32, f32), (f32, f32))> = {
            let mut f = Vec::new();
            for i in 0..n_x {
                let xa = px0 + (px1 - px0) * i as f32 / n_x as f32;
                let xb = px0 + (px1 - px0) * (i + 1) as f32 / n_x as f32;
                f.push(((xa, pz0), (xb, pz0)));
                f.push(((xa, pz1), (xb, pz1)));
            }
            for j in 0..n_z {
                let za = pz0 + (pz1 - pz0) * j as f32 / n_z as f32;
                let zb = pz0 + (pz1 - pz0) * (j + 1) as f32 / n_z as f32;
                f.push(((px0, za), (px0, zb)));
                f.push(((px1, za), (px1, zb)));
            }
            f
        };
        for (a, b) in faces {
            if !self.rng.chance(0.55) {
                continue;
            }
            let dir = v3(b.0 - a.0, 0.0, b.1 - a.1);
            let span = dir.length() - pier;
            let basis = Basis::looking(dir);
            let mid = v3((a.0 + b.0) * 0.5, 0.0, (a.1 + b.1) * 0.5);
            let depth = self.rng.range(8.0, 20.0);
            let mut y = slab_bottom - 0.4;
            while y > slab_bottom - depth {
                let c = self.wood_dark();
                self.put_box("wood", v3(mid.x, y, mid.z), v3(0.22, 0.26, span + 0.3), basis, c);
                // X-brace in the bay below.
                let h = 2.8;
                let len = (span * span + h * h).sqrt();
                let ang = (h / span).atan();
                for sgn in [-1.0f32, 1.0] {
                    let c = self.wood_dark();
                    self.put_box("wood", v3(mid.x, y - h * 0.5, mid.z), v3(0.14, 0.16, len), basis * Basis::rot_x(sgn * ang), c);
                }
                let c = self.iron();
                for end in [-0.5f32, 0.5] {
                    let p = mid + basis.z * (end * span);
                    self.scene.put("box", "metal", Xf::at(v3(p.x, y, p.z), v3(0.32, 0.36, 0.32)), c, [0.0, 1.0, 0.0, 0.0]);
                }
                y -= h;
            }
        }
    }

    /// One course of blocks around a rectangle's perimeter.
    fn ring_course(&mut self, x0: f32, z0: f32, x1: f32, z1: f32, y: f32, h: f32, depth: f32, mean_len: f32) {
        let corners = [(x0, z0), (x1, z0), (x1, z1), (x0, z1), (x0, z0)];
        for w in corners.windows(2) {
            let (a, b) = (w[0], w[1]);
            let dir = v3(b.0 - a.0, 0.0, b.1 - a.1);
            let length = dir.length();
            let basis = Basis::looking(dir);
            // basis.x points outward for this corner order; blocks sit inside the line.
            let mut s = -self.rng.range(0.0, mean_len * 0.5);
            while s < length {
                let len = mean_len * self.rng.range(0.7, 1.3);
                let (s0, s1) = (s.max(0.0), (s + len).min(length));
                s += len;
                if s1 - s0 < 0.15 {
                    continue;
                }
                let p = v3(a.0, y, a.1) + basis.z * ((s0 + s1) * 0.5) + basis.x * (-depth * 0.5 + self.rng.range(0.0, 0.03));
                self.stone(p, v3(depth, h, s1 - s0 - 0.04), basis, 0.92);
            }
        }
    }

    /// Straight stone steps rising from `y0` at the start to `y1` at the end,
    /// running along `dir` (unit X or Z) for `length` metres.
    pub fn stairs(&mut self, start: V3, dir: V3, length: f32, width: f32, y1: f32) {
        let steps = ((y1 - start.y).abs() / 0.2).ceil().max(1.0) as usize;
        let basis = Basis::looking(dir);
        let run = length / steps as f32;
        for i in 0..steps {
            let top = lerp(start.y, y1, (i + 1) as f32 / steps as f32);
            let p = start + dir * (run * (i as f32 + 0.5));
            let h = top - start.y.min(y1) + 0.2;
            let mut x = -width * 0.5;
            while x < width * 0.5 - 0.1 {
                let w = self.rng.range(0.5, 0.8).min(width * 0.5 - x);
                self.stone(v3(p.x, top - h * 0.5, p.z) + basis.x * (x + w * 0.5), v3(w - 0.03, h, run - 0.02), basis, 1.0);
                x += w;
            }
        }
        let end = start + dir * length;
        self.scene.walk.fill(start.x.min(end.x) - basis.x.x.abs() * width * 0.5, start.z.min(end.z) - basis.x.z.abs() * width * 0.5,
            start.x.max(end.x) + basis.x.x.abs() * width * 0.5, start.z.max(end.z) + basis.x.z.abs() * width * 0.5,
            |x, z| {
                let t = ((v3(x, 0.0, z) - v3(start.x, 0.0, start.z)).dot(dir) / length).clamp(0.0, 1.0);
                lerp(start.y, y1, t)
            });
    }

    /// Timber walkway with brass-capped rails from `a` to `b` (walk surface points).
    pub fn bridge(&mut self, a: V3, b: V3, width: f32, supports: bool) {
        let span = b - a;
        let length = span.length();
        let basis = Basis::looking(span);
        let flat = Basis::looking(v3(span.x, 0.0, span.z));
        let at = |s: f32, x: f32, y: f32| a + basis.z * s + basis.x * x + basis.y * y;
        // Deck planks across the span.
        let mut s = 0.0;
        while s < length {
            let w = self.rng.range(0.22, 0.3).min(length - s);
            if w > 0.08 {
                let color = self.wood();
                let tilt = Basis::euler(0.0, self.rng.sym(0.015), self.rng.sym(0.02));
                self.put_box("wood", at(s + w * 0.5, self.rng.sym(0.03), -0.045), v3(width + self.rng.sym(0.06), 0.07, w - 0.025), basis * tilt, color);
            }
            s += w;
        }
        // Stringers and brass edge trim.
        for side in [-1.0, 1.0] {
            let c = self.wood_dark();
            self.put_box("wood", at(length * 0.5, side * (width * 0.5 - 0.18), -0.26), v3(0.18, 0.32, length), basis, c);
            let c = self.brass();
            self.put_box("metal", at(length * 0.5, side * (width * 0.5 + 0.02), -0.06), v3(0.05, 0.1, length), basis, c);
        }
        // Rails.
        let posts = (length / 1.6).ceil().max(1.0) as usize;
        for i in 0..=posts {
            let s = length * i as f32 / posts as f32;
            for side in [-1.0, 1.0] {
                let base = at(s, side * (width * 0.5 - 0.06), 0.0);
                let c = self.wood_dark();
                self.put_box("wood", base + V3::Y * 0.48, v3(0.11, 0.96, 0.11), flat, c);
                let c = self.brass();
                self.scene.put("sphere", "metal", Xf::at(base + V3::Y * 1.0, V3::splat(0.15)), c, [0.0; 4]);
                self.put_box("metal", base + V3::Y * 0.08, v3(0.16, 0.16, 0.16), flat, c);
            }
        }
        for side in [-1.0, 1.0] {
            let c = self.brass();
            self.put_box("metal", at(length * 0.5, side * (width * 0.5 - 0.06), 0.0) + V3::Y * 0.96, v3(0.06, 0.06, length), basis, c);
            let c = self.wood_dark();
            self.put_box("wood", at(length * 0.5, side * (width * 0.5 - 0.06), 0.0) + V3::Y * 0.5, v3(0.05, 0.07, length), basis, c);
        }
        // Walk surface.
        let (lo, hi) = (a, b);
        let half = width * 0.5 - 0.15;
        let across = flat.x;
        let (x0, x1) = (lo.x.min(hi.x) - across.x.abs() * half, lo.x.max(hi.x) + across.x.abs() * half);
        let (z0, z1) = (lo.z.min(hi.z) - across.z.abs() * half, lo.z.max(hi.z) + across.z.abs() * half);
        let dir_flat = v3(span.x, 0.0, span.z);
        let flat_len = dir_flat.length();
        self.scene.walk.fill(x0, z0, x1, z1, |x, z| {
            let t = ((v3(x, 0.0, z) - v3(a.x, 0.0, a.z)).dot(dir_flat) / (flat_len * flat_len)).clamp(0.0, 1.0);
            lerp(a.y, b.y, t)
        });
        if supports && length > 5.0 {
            let n = (length / 7.0).floor().max(1.0) as usize;
            for i in 1..=n {
                let s = length * i as f32 / (n + 1) as f32;
                self.trestle(at(s, 0.0, -0.4), flat, width, 28.0);
            }
        }
        // Hanging chains under longer spans.
        if length > 4.0 {
            let count = 1 + self.rng.below(3);
            for _ in 0..count {
                let s = self.rng.range(0.25, 0.75) * length;
                let side = if self.rng.chance(0.5) { -1.0 } else { 1.0 };
                let drop = self.rng.range(2.0, 7.0);
                self.chain(at(s, side * (width * 0.5 - 0.1), -0.35), drop);
            }
        }
    }

    /// Vertical timber frame with iron ties, descending below a span.
    pub fn trestle(&mut self, top: V3, flat: Basis, width: f32, depth: f32) {
        for side in [-1.0, 1.0] {
            let c = self.wood_dark();
            let p = top + flat.x * (side * (width * 0.5 - 0.15));
            self.put_box("wood", p - V3::Y * (depth * 0.5), v3(0.22, depth, 0.22), flat, c);
        }
        let mut y = 1.6;
        while y < depth {
            let c = self.wood_dark();
            self.put_box("wood", top - V3::Y * y, v3(width - 0.2, 0.16, 0.16), flat, c);
            // Diagonal brace.
            let d = 2.4;
            let len = ((width - 0.3).powi(2) + d * d).sqrt();
            let ang = (d / (width - 0.3)).atan();
            let tilt = flat * Basis::rot_z(if (y as i32) % 2 == 0 { ang } else { -ang });
            let c = self.wood_dark();
            self.put_box("wood", top - V3::Y * (y + d * 0.5), v3(len, 0.12, 0.1), tilt, c);
            let c = self.iron();
            for side in [-1.0, 1.0] {
                let p = top - V3::Y * y + flat.x * (side * (width * 0.5 - 0.15));
                self.put_box("metal", p, v3(0.3, 0.3, 0.3), flat, c);
            }
            y += 2.4;
        }
    }

    pub fn chain(&mut self, top: V3, length: f32) {
        let n = (length / 0.12) as usize;
        let c = self.iron();
        for i in 0..n {
            let yaw = if i % 2 == 0 { 0.0 } else { std::f32::consts::FRAC_PI_2 };
            let basis = Basis::rot_y(yaw) * Basis::rot_x(std::f32::consts::FRAC_PI_2);
            let p = top - V3::Y * (i as f32 * 0.12);
            self.scene.put("ring", "metal", Xf::new(p, basis, v3(0.1, 0.12, 0.17)), c, [0.0; 4]);
        }
    }
}
