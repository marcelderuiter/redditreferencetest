//! Furniture, lighting fixtures, treasure and painted miniature figures.
use crate::kit::{Kit, mix, shade, srgb};
use crate::math::{Basis, V3, Xf, v3};
use std::f32::consts::{FRAC_PI_2, PI, TAU};

/// Warm candle light colour (linear).
pub const CANDLE: [f32; 3] = [1.0, 0.7, 0.4];
pub const FIRE: [f32; 3] = [1.0, 0.56, 0.24];

#[derive(Clone, Copy)]
pub enum Weapon {
    None,
    Spear,
    Sword,
    Staff([f32; 3]),
    Axe,
}

#[derive(Clone, Copy)]
pub struct Figure {
    pub armor: [f32; 4],
    pub cloth: [f32; 4],
    pub trim: [f32; 4],
    pub robe: bool,
    pub helmet: bool,
    pub cape: bool,
    pub shield: bool,
    pub weapon: Weapon,
    pub scale: f32,
}

impl Figure {
    pub fn knight() -> Figure {
        Figure { armor: srgb(150, 140, 128), cloth: srgb(120, 30, 24), trim: srgb(200, 150, 70), robe: false, helmet: true, cape: true, shield: false, weapon: Weapon::Sword, scale: 1.55 }
    }
    pub fn guard() -> Figure {
        Figure { armor: srgb(120, 116, 110), cloth: srgb(96, 30, 26), trim: srgb(180, 140, 70), robe: false, helmet: true, cape: false, shield: true, weapon: Weapon::Spear, scale: 1.55 }
    }
    pub fn priest() -> Figure {
        Figure { armor: srgb(180, 140, 70), cloth: srgb(128, 36, 30), trim: srgb(214, 170, 90), robe: true, helmet: false, cape: false, shield: false, weapon: Weapon::Staff([1.0, 0.6, 0.25]), scale: 1.55 }
    }
    pub fn mage() -> Figure {
        Figure { armor: srgb(110, 90, 130), cloth: srgb(78, 44, 104), trim: srgb(190, 160, 220), robe: true, helmet: false, cape: true, shield: false, weapon: Weapon::Staff([0.6, 0.3, 1.0]), scale: 1.55 }
    }
    pub fn brute() -> Figure {
        Figure { armor: srgb(110, 80, 60), cloth: srgb(140, 40, 30), trim: srgb(160, 120, 60), robe: false, helmet: false, cape: false, shield: true, weapon: Weapon::Axe, scale: 1.65 }
    }
    pub fn hero() -> Figure {
        Figure { armor: srgb(170, 160, 150), cloth: srgb(36, 74, 110), trim: srgb(220, 175, 90), robe: false, helmet: false, cape: true, shield: false, weapon: Weapon::Sword, scale: 1.55 }
    }
}

impl Kit {
    pub fn candle(&mut self, base: V3, height: f32, radius: f32) {
        let wax = mix(srgb(232, 220, 190), srgb(214, 190, 150), self.rng.f());
        let custom = [self.rng.f(), 0.0, 0.0, 0.0];
        self.scene.put("cyl", "wax", Xf::at(base + V3::Y * (height * 0.5), v3(radius * 2.0, height, radius * 2.0)), wax, custom);
        let flame = base + V3::Y * (height + radius * 1.3);
        let custom = [self.rng.f(), 1.0, 0.0, 0.0];
        self.scene.put("flame", "flame", Xf::at(flame, v3(radius * 1.3, radius * 3.2, radius * 1.3)), [1.0, 0.55, 0.18, 1.0], custom);
    }

    /// A few candles of mixed height plus one light for the cluster.
    pub fn candles(&mut self, base: V3, count: usize, spread: f32, light: f32) {
        self.prop(base, |k| k.candles_raw(base, count, spread, light));
    }

    fn candles_raw(&mut self, base: V3, count: usize, spread: f32, light: f32) {
        let mut top = base.y;
        for i in 0..count {
            let a = i as f32 / count as f32 * TAU + self.rng.sym(0.4);
            let r = if i == 0 { 0.0 } else { spread * self.rng.range(0.5, 1.0) };
            let h = self.rng.range(0.12, 0.38);
            top = top.max(base.y + h);
            self.candle(base + v3(a.cos() * r, 0.0, a.sin() * r), h, self.rng.range(0.03, 0.045));
        }
        if light > 0.0 {
            let energy = light * (1.0 + 0.22 * count as f32);
            self.scene.light(v3(base.x, top + 0.25, base.z), CANDLE, energy, 2.6 + 0.35 * count as f32, false, 0.15);
        }
    }

    /// Iron floor stand with three candles.
    pub fn candelabra(&mut self, base: V3) {
        self.prop(base, |k| k.candelabra_raw(base));
    }

    fn candelabra_raw(&mut self, base: V3) {
        let c = self.iron();
        self.scene.put("cyl", "metal", Xf::at(base + V3::Y * 0.04, v3(0.36, 0.08, 0.36)), c, [0.0, 1.0, 0.0, 0.0]);
        self.scene.put("cyl", "metal", Xf::at(base + V3::Y * 0.7, v3(0.06, 1.4, 0.06)), c, [0.0, 1.0, 0.0, 0.0]);
        let b = self.brass();
        self.scene.put("cyl", "metal", Xf::at(base + V3::Y * 1.4, v3(0.6, 0.04, 0.12)), b, [0.0; 4]);
        for x in [-0.25, 0.0, 0.25] {
            self.scene.put("cyl", "metal", Xf::at(base + v3(x, 1.43, 0.0), v3(0.09, 0.05, 0.09)), b, [0.0; 4]);
            self.candle(base + v3(x, 1.45, 0.0), self.rng.range(0.15, 0.25), 0.035);
        }
        self.scene.light(base + V3::Y * 1.9, CANDLE, 2.4, 4.5, false, 0.12);
    }

    /// Stone column with a fire bowl; a strong shadowed light.
    pub fn brazier(&mut self, base: V3, height: f32) {
        self.prop(base, |k| k.brazier_raw(base, height));
    }

    fn brazier_raw(&mut self, base: V3, height: f32) {
        self.pier(base.x, base.z, base.y, base.y + height, 0.55);
        let top = base + V3::Y * (height + 0.16);
        let b = self.brass();
        self.scene.put("cone", "metal", Xf::new(top + V3::Y * 0.15, Basis::rot_x(PI), v3(0.7, 0.3, 0.7)), b, [0.0; 4]);
        self.scene.put("ring", "metal", Xf::at(top + V3::Y * 0.3, v3(0.72, 0.4, 0.72)), b, [0.0; 4]);
        self.fire(top + V3::Y * 0.28, 0.28, 3.5, 7.0, true);
    }

    /// Ember bed and flames with one light.
    pub fn fire(&mut self, base: V3, radius: f32, energy: f32, range: f32, shadow: bool) {
        for _ in 0..(6.0 + radius * 20.0) as usize {
            let a = self.rng.range(0.0, TAU);
            let r = radius * self.rng.f().sqrt();
            let p = base + v3(a.cos() * r, 0.02, a.sin() * r);
            let custom = [self.rng.f(), 0.6, 0.0, 0.0];
            self.scene.put("stone0", "glow", Xf::new(p, Basis::euler(self.rng.sym(3.0), 0.3, 0.2), V3::splat(radius * 0.35)), [1.0, 0.3, 0.06, 1.0], custom);
        }
        for i in 0..5 {
            let a = i as f32 * 1.3;
            let r = if i == 0 { 0.0 } else { radius * 0.5 };
            let h = radius * self.rng.range(1.4, 2.4) * if i == 0 { 1.4 } else { 1.0 };
            let p = base + v3(a.cos() * r, h * 0.5, a.sin() * r);
            let custom = [self.rng.f(), 1.6, 0.0, 0.0];
            self.scene.put("flame", "flame", Xf::at(p, v3(radius * 0.8, h, radius * 0.8)), [1.0, 0.45, 0.12, 1.0], custom);
        }
        self.scene.light(base + V3::Y * (radius * 2.0 + 0.3), FIRE, energy, range, shadow, 0.25);
    }

    pub fn table(&mut self, center: V3, size: (f32, f32), yaw: f32) {
        self.prop(center, |k| k.table_raw(center, size, yaw));
    }

    fn table_raw(&mut self, center: V3, size: (f32, f32), yaw: f32) {
        let basis = Basis::rot_y(yaw);
        let h = 0.75;
        let c = self.wood();
        self.put_box("wood", center + V3::Y * (h - 0.04), v3(size.0, 0.08, size.1), basis, c);
        for (sx, sz) in [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)] {
            let p = center + basis.apply(v3(sx * (size.0 * 0.5 - 0.08), (h - 0.08) * 0.5, sz * (size.1 * 0.5 - 0.08)));
            let c = self.wood_dark();
            self.put_box("wood", p, v3(0.09, h - 0.08, 0.09), basis, c);
        }
        let top = center + V3::Y * h;
        // Clutter: books, papers, cups.
        for _ in 0..3 {
            let p = top + basis.apply(v3(self.rng.sym(size.0 * 0.35), 0.0, self.rng.sym(size.1 * 0.3)));
            self.book_stack(p, basis * Basis::rot_y(self.rng.sym(0.5)));
        }
        for _ in 0..2 {
            let p = top + basis.apply(v3(self.rng.sym(size.0 * 0.4), 0.006, self.rng.sym(size.1 * 0.35)));
            self.put_box("cloth", p, v3(0.22, 0.01, 0.3), basis * Basis::rot_y(self.rng.sym(0.6)), srgb(200, 184, 150));
        }
        let b = self.brass();
        let p = top + basis.apply(v3(self.rng.sym(size.0 * 0.3), 0.07, self.rng.sym(size.1 * 0.3)));
        self.scene.put("cone", "metal", Xf::new(p, Basis::rot_x(PI), v3(0.09, 0.14, 0.09)), b, [0.0; 4]);
        self.candles(top + basis.apply(v3(size.0 * 0.32, 0.0, 0.0)), 3, 0.08, 1.0);
        self.block(center.x - size.0 * 0.6, center.z - size.1 * 0.6, center.x + size.0 * 0.6, center.z + size.1 * 0.6);
    }

    fn book_stack(&mut self, base: V3, basis: Basis) {
        let mut y = 0.0;
        for _ in 0..1 + self.rng.below(3) {
            let h = self.rng.range(0.04, 0.07);
            let c = self.book_color();
            self.put_box("paint", base + V3::Y * (y + h * 0.5), v3(self.rng.range(0.16, 0.24), h, self.rng.range(0.22, 0.3)), basis * Basis::rot_y(self.rng.sym(0.3)), c);
            y += h;
        }
    }

    fn book_color(&mut self) -> [f32; 4] {
        let palette = [srgb(110, 30, 26), srgb(40, 64, 44), srgb(84, 56, 34), srgb(34, 44, 74), srgb(130, 96, 50), srgb(70, 30, 50)];
        shade(palette[self.rng.below(palette.len())], self.rng.range(0.8, 1.1))
    }

    pub fn chair(&mut self, base: V3, yaw: f32) {
        self.prop(base, |k| k.chair_raw(base, yaw));
    }

    fn chair_raw(&mut self, base: V3, yaw: f32) {
        let basis = Basis::rot_y(yaw);
        let c = self.wood_dark();
        self.put_box("wood", base + V3::Y * 0.45, v3(0.42, 0.06, 0.42), basis, c);
        self.put_box("wood", base + basis.apply(v3(0.0, 0.75, -0.19)), v3(0.42, 0.6, 0.05), basis, c);
        for (sx, sz) in [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)] {
            self.put_box("wood", base + basis.apply(v3(sx * 0.17, 0.22, sz * 0.17)), v3(0.05, 0.44, 0.05), basis, c);
        }
    }

    pub fn barrel(&mut self, base: V3, scale: f32) {
        self.prop(base, |k| k.barrel_raw(base, scale));
    }

    fn barrel_raw(&mut self, base: V3, scale: f32) {
        let c = self.wood();
        let (h, r) = (0.8 * scale, 0.55 * scale);
        let custom = [self.rng.f(), 1.0, 0.0, 0.0];
        self.scene.put("barrel", "wood", Xf::new(base + V3::Y * (h * 0.5), Basis::rot_y(self.rng.range(0.0, TAU)), v3(r, h, r)), c, custom);
        let m = self.iron();
        for y in [0.2, 0.8] {
            let bulge = 1.0 + 0.16 * (1.0 - (2.0 * y - 1.0f32).powi(2));
            self.scene.put("ring", "metal", Xf::at(base + V3::Y * (h * y), v3(r * 0.86 * bulge + 0.02, 0.25, r * 0.86 * bulge + 0.02)), m, [0.0, 1.0, 0.0, 0.0]);
        }
        self.block(base.x - r * 0.6, base.z - r * 0.6, base.x + r * 0.6, base.z + r * 0.6);
    }

    pub fn crate_box(&mut self, base: V3, size: f32, yaw: f32) {
        self.prop(base, |k| k.crate_box_raw(base, size, yaw));
    }

    fn crate_box_raw(&mut self, base: V3, size: f32, yaw: f32) {
        let basis = Basis::rot_y(yaw);
        let c = self.wood();
        self.put_box("wood", base + V3::Y * (size * 0.5), V3::splat(size), basis, c);
        let d = self.wood_dark();
        for (sx, sz) in [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)] {
            self.put_box("wood", base + basis.apply(v3(sx * size * 0.47, size * 0.5, sz * size * 0.47)), v3(0.07, size + 0.01, 0.07), basis, d);
        }
        for y in [0.04, 0.96] {
            self.put_box("wood", base + V3::Y * (size * y), v3(size + 0.03, 0.06, size + 0.03), basis, d);
        }
        self.block(base.x - size * 0.6, base.z - size * 0.6, base.x + size * 0.6, base.z + size * 0.6);
    }

    pub fn chest(&mut self, base: V3, yaw: f32, open: bool) {
        self.prop(base, |k| k.chest_raw(base, yaw, open));
    }

    fn chest_raw(&mut self, base: V3, yaw: f32, open: bool) {
        let basis = Basis::rot_y(yaw);
        let c = self.wood();
        self.put_box("wood", base + V3::Y * 0.2, v3(0.8, 0.4, 0.5), basis, c);
        let b = self.brass();
        for x in [-0.3, 0.3] {
            self.put_box("metal", base + basis.apply(v3(x, 0.21, 0.0)), v3(0.06, 0.42, 0.52), basis, b);
        }
        if open {
            let lid = basis * Basis::rot_x(-1.1);
            self.put_box("wood", base + basis.apply(v3(0.0, 0.52, -0.33)), v3(0.8, 0.08, 0.5), lid, c);
            for _ in 0..14 {
                let p = base + basis.apply(v3(self.rng.sym(0.33), 0.41, self.rng.sym(0.2)));
                self.coin(p);
            }
            self.scene.put("sphere", "gold", Xf::at(base + V3::Y * 0.38, v3(0.7, 0.14, 0.4)), srgb(230, 176, 74), [0.0; 4]);
        } else {
            self.scene.put("cyl", "wood", Xf::new(base + V3::Y * 0.4, basis * Basis::rot_z(FRAC_PI_2), v3(0.3, 0.8, 0.5)), c, [0.0, 1.0, 0.0, 0.0]);
            self.put_box("metal", base + basis.apply(v3(0.0, 0.32, 0.26)), v3(0.1, 0.12, 0.04), basis, b);
        }
        self.block(base.x - 0.5, base.z - 0.5, base.x + 0.5, base.z + 0.5);
    }

    fn coin(&mut self, p: V3) {
        let basis = Basis::euler(self.rng.range(0.0, TAU), self.rng.sym(0.6), self.rng.sym(0.6));
        let c = shade(srgb(236, 182, 78), self.rng.range(0.8, 1.1));
        self.scene.put("cyl", "gold", Xf::new(p, basis, v3(0.09, 0.018, 0.09)), c, [0.0; 4]);
    }

    pub fn gold_pile(&mut self, center: V3, radius: f32) {
        self.prop(center, |k| k.gold_pile_raw(center, radius));
    }

    fn gold_pile_raw(&mut self, center: V3, radius: f32) {
        let gold = srgb(226, 170, 70);
        self.scene.put("sphere", "gold", Xf::at(center, v3(radius * 2.0, radius * 0.9, radius * 2.0)), gold, [0.0; 4]);
        for _ in 0..(radius * radius * 90.0) as usize {
            let a = self.rng.range(0.0, TAU);
            let r = radius * self.rng.f().sqrt() * 1.1;
            let h = radius * 0.45 * (1.0 - (r / (radius * 1.1)).powi(2)).max(0.0).sqrt();
            self.coin(center + v3(a.cos() * r, h + 0.01, a.sin() * r));
        }
        let b = self.brass();
        for _ in 0..2 {
            let a = self.rng.range(0.0, TAU);
            let p = center + v3(a.cos() * radius * 0.5, radius * 0.35, a.sin() * radius * 0.5);
            self.scene.put("cone", "metal", Xf::new(p, Basis::euler(0.0, self.rng.sym(0.4), PI + self.rng.sym(0.4)), v3(0.12, 0.2, 0.12)), b, [0.0; 4]);
        }
        self.block(center.x - radius, center.z - radius, center.x + radius, center.z + radius);
    }

    pub fn bookshelf(&mut self, base: V3, yaw: f32, width: f32, height: f32) {
        self.prop(base, |k| k.bookshelf_raw(base, yaw, width, height));
    }

    fn bookshelf_raw(&mut self, base: V3, yaw: f32, width: f32, height: f32) {
        let basis = Basis::rot_y(yaw);
        let d = self.wood_dark();
        for x in [-0.5, 0.5] {
            self.put_box("wood", base + basis.apply(v3(x * width, height * 0.5, 0.0)), v3(0.07, height, 0.38), basis, d);
        }
        self.put_box("wood", base + basis.apply(v3(0.0, height * 0.5, -0.17)), v3(width, height, 0.04), basis, d);
        let shelves = (height / 0.42) as usize;
        for i in 0..=shelves {
            let y = i as f32 * height / shelves as f32;
            self.put_box("wood", base + basis.apply(v3(0.0, y + 0.02, 0.0)), v3(width, 0.05, 0.38), basis, d);
            if i == shelves {
                break;
            }
            let mut x = -width * 0.5 + 0.06;
            while x < width * 0.5 - 0.08 {
                let w = self.rng.range(0.04, 0.08);
                let h = self.rng.range(0.22, 0.34);
                if self.rng.chance(0.9) {
                    let c = self.book_color();
                    let lean = Basis::rot_z(if self.rng.chance(0.15) { 0.25 } else { 0.0 });
                    self.put_box("paint", base + basis.apply(v3(x + w * 0.5, y + 0.045 + h * 0.5, 0.02)), v3(w - 0.006, h, 0.27), basis * lean, c);
                }
                x += w;
            }
        }
    }

    /// Hanging cloth banner with a brass rod; `forward` is the wall's inward normal.
    pub fn banner(&mut self, top: V3, forward: V3, width: f32, length: f32, color: [f32; 4]) {
        self.prop(top, |k| k.banner_raw(top, forward, width, length, color));
    }

    fn banner_raw(&mut self, top: V3, forward: V3, width: f32, length: f32, color: [f32; 4]) {
        let basis = Basis::looking(forward);
        let custom = [self.rng.f(), 2.0, length / width, 0.0];
        self.scene.put("box", "cloth", Xf::new(top - V3::Y * (length * 0.5) + forward * 0.03, basis, v3(width, length, 0.03)), color, custom);
        let b = self.brass();
        self.scene.put("cyl", "metal", Xf::new(top + forward * 0.05, Basis::rot_z(FRAC_PI_2) * Basis::IDENTITY, v3(0.05, width + 0.2, 0.05)), b, [0.0; 4]);
    }

    /// Patterned carpet slab lying on the floor at `y`. Pattern 0 = runner, 1 = rug.
    pub fn carpet(&mut self, x0: f32, z0: f32, x1: f32, z1: f32, y: f32, color: [f32; 4], pattern: f32) {
        let (w, d) = (x1 - x0, z1 - z0);
        let custom = [self.rng.f(), pattern, d / w, 0.0];
        self.scene.put("box", "cloth", Xf::at(v3((x0 + x1) * 0.5, y + 0.012, (z0 + z1) * 0.5), v3(w, 0.024, d)), color, custom);
    }

    pub fn rubble(&mut self, center: V3, radius: f32, count: usize) {
        for _ in 0..count {
            let a = self.rng.range(0.0, TAU);
            let r = radius * self.rng.f().sqrt();
            let s = self.rng.range(0.08, 0.3);
            let p = center + v3(a.cos() * r, s * 0.35, a.sin() * r);
            let basis = Basis::euler(self.rng.range(0.0, TAU), self.rng.sym(0.5), self.rng.sym(0.5));
            self.stone(p, v3(s * self.rng.range(0.8, 1.6), s * 0.7, s), basis, 0.95);
        }
    }

    /// Stone figure on a plinth; `glow` adds a coloured aura (shrine statues).
    pub fn statue(&mut self, base: V3, yaw: f32, scale: f32, glow: Option<[f32; 3]>) {
        self.prop(base, |k| k.statue_raw(base, yaw, scale, glow));
    }

    fn statue_raw(&mut self, base: V3, yaw: f32, scale: f32, glow: Option<[f32; 3]>) {
        self.pier(base.x, base.z, base.y, base.y + 0.5, 0.9);
        let mut f = Figure::priest();
        let tone = srgb(150, 142, 130);
        f.armor = tone;
        f.cloth = tone;
        f.trim = shade(tone, 1.1);
        f.weapon = Weapon::None;
        f.scale = scale;
        let root = Xf::new(base + V3::Y * 0.66, Basis::rot_y(yaw), V3::ONE);
        self.figure_into(root, f, true, glow);
        if let Some(c) = glow {
            self.scene.light(base + V3::Y * (1.2 * scale + 0.8) + Basis::rot_y(yaw).z * 0.6, c, 2.5, 5.0, false, 0.05);
        }
    }

    /// Painted miniature on a round base.
    pub fn figure(&mut self, base: V3, yaw: f32, f: Figure) {
        self.prop(base, |k| k.figure_raw(base, yaw, f));
    }

    fn figure_raw(&mut self, base: V3, yaw: f32, f: Figure) {
        let root = Xf::new(base, Basis::rot_y(yaw), V3::ONE);
        self.figure_into(root, f, false, None);
        self.block(base.x - 0.3, base.z - 0.3, base.x + 0.3, base.z + 0.3);
    }

    pub fn figure_into(&mut self, root: Xf, f: Figure, stone: bool, glow: Option<[f32; 3]>) {
        let s = f.scale;
        let mat = if stone { "stone" } else { "paint" };
        let metal = [0.5, 0.75, 0.0, 0.0];
        let matte = [0.5, 0.0, 0.0, 0.0];
        let put = |kit: &mut Kit, mesh: &'static str, local: Xf, color: [f32; 4], custom: [f32; 4]| {
            let scaled = Xf { basis: local.basis.scaled(V3::splat(s)), origin: local.origin * s };
            let xf = root.then(&scaled);
            let custom = if stone { [kit.rng.f(), kit.rng.f(), 0.0, 0.0] } else { custom };
            let mesh = if stone && mesh.starts_with("stone") { "stone0" } else { mesh };
            kit.scene.put(mesh, mat, xf, color, custom);
        };
        if !stone {
            put(self, "cyl", Xf::at(v3(0.0, 0.035, 0.0), v3(0.62, 0.07, 0.62)), srgb(34, 32, 30), matte);
        }
        let skin = if stone { f.armor } else { srgb(196, 150, 120) };
        let b = |x: f32, y: f32, z: f32| v3(x, y, z);
        if f.robe {
            put(self, "cone", Xf::at(b(0.0, 0.46, 0.0), v3(0.52, 0.92, 0.46)), f.cloth, matte);
            put(self, "cyl", Xf::at(b(0.0, 0.62, 0.0), v3(0.36, 0.04, 0.3)), f.trim, metal);
        } else {
            for x in [-0.1, 0.1] {
                put(self, "box", Xf::at(b(x, 0.28, 0.0), v3(0.13, 0.5, 0.16)), shade(f.cloth, 0.7), matte);
                put(self, "box", Xf::at(b(x, 0.06, 0.03), v3(0.15, 0.12, 0.22)), srgb(50, 40, 34), matte);
            }
            put(self, "cone", Xf::at(b(0.0, 0.5, 0.0), v3(0.44, 0.26, 0.34)), f.cloth, matte);
        }
        put(self, "box", Xf::at(b(0.0, 0.84, 0.0), v3(0.36, 0.44, 0.24)), f.armor, metal);
        put(self, "box", Xf::at(b(0.0, 0.64, 0.0), v3(0.38, 0.07, 0.26)), f.trim, metal);
        for x in [-1.0, 1.0] {
            put(self, "sphere", Xf::at(b(x * 0.22, 1.02, 0.0), v3(0.2, 0.17, 0.22)), f.trim, metal);
            let arm = Xf::new(b(x * 0.25, 0.8, 0.04), Basis::rot_x(-0.3) * Basis::rot_z(x * 0.12), v3(0.11, 0.42, 0.11));
            put(self, "cyl", arm, f.armor, metal);
        }
        put(self, "sphere", Xf::at(b(0.0, 1.2, 0.0), v3(0.2, 0.22, 0.2)), skin, matte);
        if f.helmet {
            put(self, "sphere", Xf::at(b(0.0, 1.25, -0.01), v3(0.24, 0.22, 0.25)), f.armor, metal);
            put(self, "box", Xf::at(b(0.0, 1.38, -0.01), v3(0.03, 0.08, 0.24)), f.trim, metal);
        } else if f.robe {
            put(self, "cone", Xf::at(b(0.0, 1.24, -0.03), v3(0.27, 0.3, 0.27)), shade(f.cloth, 0.85), matte);
        }
        if f.cape {
            put(self, "box", Xf::new(b(0.0, 0.62, -0.17), Basis::rot_x(0.12), v3(0.42, 0.82, 0.04)), shade(f.cloth, 0.9), matte);
        }
        if f.shield {
            put(self, "cyl", Xf::new(b(-0.33, 0.72, 0.08), Basis::rot_z(FRAC_PI_2), v3(0.4, 0.05, 0.4)), f.cloth, matte);
            put(self, "ring", Xf::new(b(-0.36, 0.72, 0.08), Basis::rot_z(FRAC_PI_2), v3(0.42, 0.2, 0.42)), f.trim, metal);
        }
        let steel = srgb(170, 170, 170);
        match f.weapon {
            Weapon::None => {}
            Weapon::Spear => {
                put(self, "cyl", Xf::at(b(0.3, 0.95, 0.12), v3(0.035, 1.9, 0.035)), srgb(80, 56, 36), matte);
                put(self, "cone", Xf::at(b(0.3, 1.98, 0.12), v3(0.06, 0.2, 0.06)), steel, metal);
            }
            Weapon::Sword => {
                put(self, "box", Xf::new(b(0.3, 0.98, 0.16), Basis::rot_x(0.2), v3(0.05, 0.75, 0.015)), steel, metal);
                put(self, "box", Xf::at(b(0.3, 0.62, 0.1), v3(0.18, 0.04, 0.04)), f.trim, metal);
            }
            Weapon::Axe => {
                put(self, "cyl", Xf::at(b(0.3, 0.85, 0.12), v3(0.04, 1.1, 0.04)), srgb(80, 56, 36), matte);
                put(self, "box", Xf::at(b(0.38, 1.3, 0.12), v3(0.2, 0.22, 0.03)), steel, metal);
            }
            Weapon::Staff(c) => {
                put(self, "cyl", Xf::at(b(0.3, 0.9, 0.1), v3(0.035, 1.75, 0.035)), srgb(70, 50, 34), matte);
                if !stone {
                    let orb = root.then(&Xf::at(b(0.3, 1.82, 0.1) * s, V3::splat(0.12 * s)));
                    self.scene.put("sphere", "flame", orb, [c[0], c[1], c[2], 1.0], [0.3, 2.0, 0.0, 0.0]);
                    self.scene.light(orb.origin, c, 0.8, 2.2, false, 0.05);
                }
            }
        }
        if let Some(c) = glow {
            let aura = root.then(&Xf::at(b(0.0, 0.95, 0.0) * s, v3(0.75 * s, 1.5 * s, 0.6 * s)));
            self.scene.put("sphere", "flame", aura, [c[0], c[1], c[2], 1.0], [0.0, 0.35, 0.0, 0.0]);
        }
    }

    /// Small floor clutter that fills empty corners: pots, sacks, stools,
    /// candle stubs and skulls.
    pub fn trinket(&mut self, base: V3) {
        self.prop(base, |k| k.trinket_raw(base));
    }

    fn trinket_raw(&mut self, base: V3) {
        let yaw = self.rng.range(0.0, TAU);
        match self.rng.below(7) {
            0 | 1 => {
                let clay = shade(srgb(132, 78, 50), self.rng.range(0.75, 1.1));
                let h = self.rng.range(0.25, 0.42);
                self.scene.put("barrel", "paint", Xf::new(base + V3::Y * (h * 0.5), Basis::rot_y(yaw), v3(h * 0.8, h, h * 0.8)), clay, [0.0; 4]);
                self.scene.put("cyl", "paint", Xf::at(base + V3::Y * (h + 0.02), v3(h * 0.45, 0.06, h * 0.45)), shade(clay, 0.8), [0.0; 4]);
            }
            2 | 3 => {
                let cloth = shade(srgb(150, 124, 88), self.rng.range(0.8, 1.05));
                let r = self.rng.range(0.22, 0.32);
                self.scene.put("sphere", "cloth", Xf::new(base + V3::Y * (r * 0.7), Basis::euler(yaw, 0.1, 0.0), v3(r * 1.6, r * 1.5, r * 1.3)), cloth, [self.rng.f(), 3.0, 1.0, 0.0]);
                self.scene.put("cyl", "cloth", Xf::at(base + V3::Y * (r * 1.45), v3(0.1, 0.12, 0.1)), shade(cloth, 0.8), [0.0, 3.0, 1.0, 0.0]);
            }
            4 => {
                let c = self.wood_dark();
                self.put_box("wood", base + V3::Y * 0.4, v3(0.34, 0.05, 0.34), Basis::rot_y(yaw), c);
                for i in 0..3 {
                    let a = yaw + i as f32 * TAU / 3.0;
                    self.put_box("wood", base + v3(a.cos() * 0.12, 0.2, a.sin() * 0.12), v3(0.05, 0.4, 0.05), Basis::rot_y(a), c);
                }
                self.candles(base + V3::Y * 0.43, 2, 0.06, 0.7);
            }
            5 => {
                let bone = srgb(214, 200, 170);
                self.scene.put("sphere", "paint", Xf::at(base + V3::Y * 0.09, v3(0.18, 0.16, 0.2)), bone, [0.0; 4]);
                for i in 0..3 {
                    let a = yaw + i as f32 * 1.1;
                    self.scene.put("cyl", "paint", Xf::new(base + v3(a.cos() * 0.25, 0.03, a.sin() * 0.25), Basis::rot_y(a) * Basis::rot_z(FRAC_PI_2), v3(0.04, 0.35, 0.04)), bone, [0.0; 4]);
                }
            }
            _ => {
                self.candles(base, 2 + self.rng.below(3), 0.1, 0.9);
            }
        }
        self.block(base.x - 0.2, base.z - 0.2, base.x + 0.2, base.z + 0.2);
    }
}
