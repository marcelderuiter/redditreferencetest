//! The authored diorama: rooms on masonry towers over an abyss, joined by
//! timber bridges. Macro layout is fixed to mirror the visual reference; the
//! seed varies every stone, plank, candle and clutter detail.
use crate::kit::{Kit, Side, mix, shade, srgb};
use crate::math::{Basis, V3, Xf, lerp, v3};
use crate::props::{CANDLE, Figure};
use crate::scene::{Room, Scene};
use crate::walk::WalkGrid;
use std::f32::consts::{FRAC_PI_2, PI, TAU};

pub const ABYSS: f32 = -48.0;
/// Furniture and figures relative to masonry; chunky like the reference.
pub const PROP_SCALE: f32 = 1.45;
const WALL: f32 = 0.8;

struct RoomSpec {
    name: &'static str,
    x0: f32,
    z0: f32,
    x1: f32,
    z1: f32,
    y: f32,
    back: f32,
    front: f32,
    /// (side, centre along that side, width)
    gaps: Vec<(Side, f32, f32)>,
}

impl RoomSpec {
    fn center(&self) -> V3 {
        v3((self.x0 + self.x1) * 0.5, self.y, (self.z0 + self.z1) * 0.5)
    }
}

pub fn generate(seed: u64) -> Scene {
    let mut kit = Kit::new(seed);
    kit.prop_scale = PROP_SCALE;
    kit.scene.walk = WalkGrid::new((-8.0, -8.0), (70.0, 48.0));
    kit.scene.bounds_min = v3(-4.0, ABYSS, -2.0);
    kit.scene.bounds_max = v3(66.0, 8.0, 44.0);

    use Side::*;
    let rooms = vec![
        RoomSpec { name: "gatehouse", x0: 1.0, z0: 0.0, x1: 11.0, z1: 10.0, y: 3.0, back: 2.8, front: 1.0, gaps: vec![(East, 6.5, 2.2), (South, 6.0, 2.2)] },
        RoomSpec { name: "study", x0: 14.0, z0: 1.0, x1: 23.0, z1: 10.0, y: 2.5, back: 2.6, front: 0.9, gaps: vec![(West, 6.5, 2.2), (South, 17.0, 2.2), (East, 6.0, 2.2)] },
        RoomSpec { name: "forge", x0: -1.0, z0: 13.0, x1: 10.0, z1: 22.0, y: 2.0, back: 2.4, front: 0.9, gaps: vec![(North, 6.0, 2.2), (East, 17.0, 2.2)] },
        RoomSpec { name: "hall", x0: 13.0, z0: 13.0, x1: 21.0, z1: 33.0, y: 1.0, back: 1.6, front: 0.8, gaps: vec![(North, 17.0, 2.2), (West, 17.0, 2.2), (East, 22.0, 2.2), (West, 30.0, 2.2), (East, 31.0, 2.2)] },
        RoomSpec { name: "ruin", x0: 28.0, z0: 3.0, x1: 36.0, z1: 11.0, y: 2.0, back: 2.0, front: 0.6, gaps: vec![(West, 6.0, 2.2), (East, 7.0, 2.2)] },
        RoomSpec { name: "chapel", x0: 39.0, z0: 0.0, x1: 50.0, z1: 11.0, y: 2.5, back: 3.4, front: 0.9, gaps: vec![(West, 7.0, 2.2), (East, 8.0, 2.2), (South, 44.5, 2.4)] },
        RoomSpec { name: "treasury", x0: 53.0, z0: 2.0, x1: 63.0, z1: 13.0, y: 2.0, back: 2.8, front: 0.9, gaps: vec![(West, 8.0, 2.2), (South, 58.0, 2.2)] },
        RoomSpec { name: "barracks", x0: 54.0, z0: 18.0, x1: 63.0, z1: 27.0, y: 1.5, back: 2.0, front: 0.8, gaps: vec![(North, 58.0, 2.2), (West, 22.0, 2.2)] },
        RoomSpec { name: "shrine", x0: -2.0, z0: 26.0, x1: 9.0, z1: 35.0, y: 0.5, back: 2.2, front: 0.8, gaps: vec![(East, 30.0, 2.2)] },
        RoomSpec { name: "storage", x0: 40.0, z0: 31.0, x1: 53.0, z1: 41.0, y: 0.0, back: 1.8, front: 0.8, gaps: vec![(North, 44.0, 2.2), (West, 32.0, 2.2)] },
    ];

    for spec in &rooms {
        build_room(&mut kit, spec);
        kit.scene.rooms.push(Room { name: spec.name, center: spec.center() });
    }

    // Round mechanism platform.
    let mech = v3(44.0, 1.0, 22.0);
    build_mechanism(&mut kit, mech, 6.0);
    kit.scene.rooms.push(Room { name: "mechanism", center: mech + v3(-3.5, 0.0, 0.0) });

    // Hanging lift between the hall and storage.
    let lift = v3(28.5, -0.5, 31.5);
    build_lift(&mut kit, lift);
    kit.scene.rooms.push(Room { name: "lift", center: lift });

    // Bridges: endpoints at walk height on each room's floor edge.
    let w = 1.9;
    kit.bridge(v3(11.0 - WALL, 3.0, 6.5), v3(14.0 + WALL, 2.5, 6.5), w, false);
    kit.bridge(v3(23.0 - WALL, 2.5, 6.0), v3(28.0 + WALL, 2.0, 6.0), w, true);
    kit.bridge(v3(36.0 - WALL, 2.0, 7.0), v3(39.0 + WALL, 2.5, 7.0), w, false);
    kit.bridge(v3(50.0 - WALL, 2.5, 8.0), v3(53.0 + WALL, 2.0, 8.0), w, false);
    kit.bridge(v3(10.0 - WALL, 2.0, 17.0), v3(13.0 + WALL, 1.0, 17.0), w, false);
    kit.bridge(v3(21.0 - WALL, 1.0, 22.0), v3(38.6, 1.0, 22.0), w, true);
    kit.bridge(v3(49.3, 1.0, 22.0), v3(54.0 + WALL, 1.5, 22.0), w, false);
    kit.bridge(v3(58.0, 2.0, 13.0 - WALL), v3(58.0, 1.5, 18.0 + WALL), w, true);
    kit.bridge(v3(9.0 - WALL, 0.5, 30.0), v3(13.0 + WALL, 1.0, 30.0), w, false);
    kit.bridge(v3(21.0 - WALL, 1.0, 31.0), v3(26.6, -0.5, 31.0), w, false);
    kit.bridge(v3(30.4, -0.5, 32.0), v3(40.0 + WALL, 0.0, 32.0), w, true);
    kit.bridge(v3(44.0, 1.0, 27.4), v3(44.0, 0.0, 31.0 + WALL), w, false);
    // Brass pipe run alongside the upper bridge, like a machine conduit.
    let b = kit.brass();
    for z in [4.6, 7.4] {
        kit.scene.put("cyl", "metal", Xf::new(v3(25.5, 2.9, z), Basis::rot_z(FRAC_PI_2), v3(0.22, 6.2, 0.22)), b, [0.0; 4]);
    }

    // Stairs between rooms at different heights.
    kit.stairs(v3(6.0, 3.0, 10.0 - WALL), V3::Z, 3.0 + 2.0 * WALL, 2.0, 2.0);
    kit.stairs(v3(17.0, 2.5, 10.0 - WALL), V3::Z, 3.0 + 2.0 * WALL, 2.0, 1.0);
    kit.stairs(v3(44.5, 2.5, 11.0 - WALL), V3::Z, 5.0 + WALL + 0.6, 2.4, 1.0);

    furnish(&mut kit, &rooms);
    backdrop(&mut kit);

    kit.scene.spawn = v3(17.0, 1.0, 26.0);
    kit.scene
}

fn build_room(kit: &mut Kit, r: &RoomSpec) {
    kit.floor(r.x0, r.z0, r.x1, r.z1, r.y);
    kit.tower(r.x0, r.z0, r.x1, r.z1, r.y - 0.2, ABYSS);
    kit.scene.walk.fill(r.x0 + WALL, r.z0 + WALL, r.x1 - WALL, r.z1 - WALL, |_, _| r.y);
    let h = WALL * 0.5;
    let depth = r.z1 - r.z0;
    let side_height = move |z: f32| lerp(r.back, r.front, ((z - r.z0) / depth).clamp(0.0, 1.0));
    let gaps_on = |side: Side, origin: f32| -> Vec<(f32, f32)> {
        r.gaps.iter().filter(|g| g.0 == side).map(|g| (g.1 - origin - g.2 * 0.5, g.1 - origin + g.2 * 0.5)).collect()
    };
    let back = r.back;
    let front = r.front;
    // North (back) and south (front) run west to east; sides run north to south.
    // Lancet windows in tall back walls, spaced clear of doorways.
    let mut windows = Vec::new();
    if r.back >= 2.4 {
        let span = r.x1 - r.x0 - 2.0 * WALL;
        let n = (span / 2.6).floor() as usize;
        for i in 0..n {
            let c = (i as f32 + 0.5) * span / n as f32;
            let x = r.x0 + WALL + c;
            if r.gaps.iter().any(|g| g.0 == Side::North && (g.1 - x).abs() < g.2) {
                continue;
            }
            windows.push((c, 0.62, 0.7, r.back - 0.45));
        }
    }
    kit.wall((r.x0 + WALL, r.z0 + h), (r.x1 - WALL, r.z0 + h), r.y, WALL, &move |_| back, &gaps_on(Side::North, r.x0 + WALL), &windows);
    kit.wall((r.x0 + WALL, r.z1 - h), (r.x1 - WALL, r.z1 - h), r.y, WALL, &move |_| front, &gaps_on(Side::South, r.x0 + WALL), &[]);
    let z0 = r.z0 + WALL;
    kit.wall((r.x0 + h, z0), (r.x0 + h, r.z1 - WALL), r.y, WALL, &move |s| side_height(z0 + s), &gaps_on(Side::West, z0), &[]);
    kit.wall((r.x1 - h, z0), (r.x1 - h, r.z1 - WALL), r.y, WALL, &move |s| side_height(z0 + s), &gaps_on(Side::East, z0), &[]);
    // Corner piers rise above the walls.
    for (x, z, top) in [(r.x0, r.z0, r.back), (r.x1, r.z0, r.back), (r.x0, r.z1, r.front), (r.x1, r.z1, r.front)] {
        let px = if x == r.x0 { x + h } else { x - h };
        let pz = if z == r.z0 { z + h } else { z - h };
        let extra = if z == r.z0 { kit.rng.range(0.6, 1.4) } else { kit.rng.range(0.2, 0.6) };
        kit.pier(px, pz, r.y, r.y + top + extra, WALL + 0.25);
        if kit.rng.chance(0.55) {
            kit.candles(v3(px, r.y + top + extra + 0.16, pz), 2 + kit.rng.below(3), 0.1, 1.0);
        }
    }
    // Door piers flank each gap.
    for &(side, c, w) in &r.gaps {
        let (a, b) = match side {
            Side::North => ((c - w * 0.5 - 0.3, r.z0 + h), (c + w * 0.5 + 0.3, r.z0 + h)),
            Side::South => ((c - w * 0.5 - 0.3, r.z1 - h), (c + w * 0.5 + 0.3, r.z1 - h)),
            Side::West => ((r.x0 + h, c - w * 0.5 - 0.3), (r.x0 + h, c + w * 0.5 + 0.3)),
            Side::East => ((r.x1 - h, c - w * 0.5 - 0.3), (r.x1 - h, c + w * 0.5 + 0.3)),
        };
        let top = match side {
            Side::North => r.back,
            Side::South => r.front,
            _ => side_height(c),
        };
        for p in [a, b] {
            kit.pier(p.0, p.1, r.y, r.y + (top + 0.4).max(1.3), 0.6);
        }
        // Open the floor through the wall band.
        let (x0, z0, x1, z1) = match side {
            Side::North => (c - w * 0.5 + 0.15, r.z0 - 0.1, c + w * 0.5 - 0.15, r.z0 + WALL + 0.1),
            Side::South => (c - w * 0.5 + 0.15, r.z1 - WALL - 0.1, c + w * 0.5 - 0.15, r.z1 + 0.1),
            Side::West => (r.x0 - 0.1, c - w * 0.5 + 0.15, r.x0 + WALL + 0.1, c + w * 0.5 - 0.15),
            Side::East => (r.x1 - WALL - 0.1, c - w * 0.5 + 0.15, r.x1 + 0.1, c + w * 0.5 - 0.15),
        };
        kit.scene.walk.fill(x0, z0, x1, z1, |_, _| r.y);
    }
    // Warm fill: the reference reads as if every room glows from many
    // candles at once, so a coarse grid of soft lights lifts the floors.
    let (nx, nz) = (((r.x1 - r.x0) / 4.5).round().max(1.0) as usize, ((r.z1 - r.z0) / 4.5).round().max(1.0) as usize);
    for j in 0..nz {
        for i in 0..nx {
            let x = r.x0 + (i as f32 + 0.5) * (r.x1 - r.x0) / nx as f32;
            let z = r.z0 + (j as f32 + 0.5) * (r.z1 - r.z0) / nz as f32;
            kit.scene.light(v3(x, r.y + 3.4, z), CANDLE, 0.55, 6.5, false, 0.03);
        }
    }
    // Warm spill down the upper tower faces.
    for (x, z) in [(r.x0 - 1.2, (r.z0 + r.z1) * 0.5), (r.x1 + 1.2, (r.z0 + r.z1) * 0.5), ((r.x0 + r.x1) * 0.5, r.z1 + 1.2)] {
        kit.scene.light(v3(x, r.y - 1.0, z), CANDLE, 1.0, 5.5, false, 0.0);
    }
    // Wall-top candles on the back wall.
    let n = ((r.x1 - r.x0) / 3.5) as usize;
    for i in 0..n {
        if kit.rng.chance(0.5) {
            let x = r.x0 + WALL + (i as f32 + 0.5) * (r.x1 - r.x0 - 2.0 * WALL) / n as f32;
            if r.gaps.iter().any(|g| g.0 == Side::North && (g.1 - x).abs() < g.2) {
                continue;
            }
            kit.candles(v3(x, r.y + 0.0, r.z0 + WALL + 0.25), 1 + kit.rng.below(2), 0.08, 0.8);
        }
    }
}

fn build_mechanism(kit: &mut Kit, c: V3, radius: f32) {
    // Circular flagstone floor: tiles clipped to the circle.
    let tile = 0.5;
    let n = (radius / tile).ceil() as i32;
    for j in -n..n {
        for i in -n..n {
            let (x, z) = ((i as f32 + 0.5) * tile, (j as f32 + 0.5) * tile);
            if (x * x + z * z).sqrt() > radius - 0.35 {
                continue;
            }
            let basis = Basis::euler(kit.rng.sym(0.03), kit.rng.sym(0.01), kit.rng.sym(0.01));
            kit.flag(v3(c.x + x, c.y - 0.08, c.z + z), v3(tile - 0.035, 0.16, tile - 0.035), basis, 1.0);
        }
    }
    kit.scene.walk.fill(c.x - radius, c.z - radius, c.x + radius, c.z + radius, |x, z| {
        if ((x - c.x).powi(2) + (z - c.z).powi(2)).sqrt() < radius - 0.5 { c.y } else { f32::NAN }
    });
    // Curved coping and a cylindrical tower.
    let ring = |kit: &mut Kit, r: f32, y: f32, h: f32, depth: f32, len: f32, tone: f32| {
        let count = (TAU * r / len).ceil() as usize;
        let offset = kit.rng.f();
        for i in 0..count {
            let a = (i as f32 + offset) / count as f32 * TAU;
            let p = v3(c.x + a.cos() * (r - depth * 0.5), y, c.z + a.sin() * (r - depth * 0.5));
            let l = TAU * r / count as f32 - 0.04;
            kit.stone(p, v3(depth, h, l), Basis::rot_y(-a), tone);
        }
    };
    ring(kit, radius, c.y - 0.08, 0.2, 0.45, 0.7, 1.05);
    ring(kit, radius, c.y - 0.42, 0.42, 0.4, 0.8, 0.92);
    ring(kit, radius - 0.2, c.y - 0.84, 0.4, 0.4, 0.8, 0.92);
    let mut y = c.y - 1.3;
    let mut k = 0;
    while y > ABYSS {
        ring(kit, radius - 0.6, y, 0.52, 0.55, if k % 12 == 11 { 0.6 } else { 1.2 }, 0.9);
        y -= 0.55;
        k += 1;
    }
    let core = srgb(28, 27, 27);
    kit.scene.put("cyl", "stone", Xf::at(v3(c.x, (c.y - 0.3 + ABYSS - 60.0) * 0.5, c.z), v3((radius - 1.0) * 2.0, c.y - 0.3 - ABYSS + 60.0, (radius - 1.0) * 2.0)), core, [0.0; 4]);
    // Low parapet with gaps for the west, east and south bridges.
    let count = 44;
    for i in 0..count {
        let a = i as f32 / count as f32 * TAU;
        let gap = [0.0, PI, FRAC_PI_2, PI + FRAC_PI_2].iter().any(|&g: &f32| {
            let d = (a - g).rem_euclid(TAU);
            d.min(TAU - d) < 0.24
        });
        if gap {
            continue;
        }
        let r = radius - 0.25;
        let p = v3(c.x + a.cos() * r, c.y, c.z + a.sin() * r);
        let h = if i % 4 == 0 { 0.9 } else { 0.45 + kit.rng.range(0.0, 0.15) };
        kit.stone(p + V3::Y * (h * 0.5), v3(0.42, h, TAU * r / count as f32 - 0.06), Basis::rot_y(-a), 1.0);
        if i % 8 == 0 {
            kit.candles(p + V3::Y * (h + 0.02), 2, 0.06, 0.9);
        }
    }
    // Brass rings, spokes, gear teeth and the central column.
    let brass = kit.brass();
    let flat = |r: f32, w: f32| v3(r * 2.0, w, r * 2.0);
    for (r, mesh) in [(4.3, "ring"), (3.3, "ring"), (2.2, "ring_wide"), (1.2, "ring_wide")] {
        let tone = shade(brass, kit.rng.range(0.85, 1.05));
        kit.scene.put(mesh, "metal", Xf::at(c + V3::Y * 0.04, flat(r, 0.35)), tone, [0.0; 4]);
    }
    for i in 0..12 {
        let a = i as f32 / 12.0 * TAU;
        let p = c + v3(a.cos() * 2.75, 0.05, a.sin() * 2.75);
        kit.put_box("metal", p, v3(0.08, 0.06, 2.1), Basis::rot_y(-a + FRAC_PI_2), brass);
    }
    for i in 0..48 {
        let a = i as f32 / 48.0 * TAU;
        let p = c + v3(a.cos() * 4.45, 0.06, a.sin() * 4.45);
        kit.put_box("metal", p, v3(0.26, 0.1, 0.14), Basis::rot_y(-a), brass);
    }
    // Rune marks between rings.
    for i in 0..24 {
        let a = (i as f32 + 0.5) / 24.0 * TAU;
        let p = c + v3(a.cos() * 3.8, 0.03, a.sin() * 3.8);
        kit.put_box("metal", p, v3(0.18, 0.03, 0.08), Basis::rot_y(-a + kit.rng.sym(0.6)), shade(brass, 0.8));
    }
    let iron = kit.iron();
    for (y, r, h, color) in [(0.15, 1.1, 0.3, iron), (0.6, 0.8, 0.6, brass), (1.4, 0.55, 1.0, brass), (2.1, 0.7, 0.12, iron), (2.5, 0.45, 0.7, brass), (2.95, 0.6, 0.1, iron)] {
        let rough = if color == iron { 1.0 } else { 0.0 };
        kit.scene.put("cyl", "metal", Xf::at(c + V3::Y * y, v3(r * 2.0, h, r * 2.0)), color, [0.0, rough, 0.0, 0.0]);
    }
    kit.scene.put("cone", "metal", Xf::at(c + V3::Y * 3.3, v3(0.6, 0.5, 0.6)), brass, [0.0; 4]);
    kit.scene.walk.block(c.x - 1.3, c.z - 1.3, c.x + 1.3, c.z + 1.3);
    kit.scene.light(c + V3::Y * 4.0, CANDLE, 3.0, 9.0, true, 0.04);
    // Corbel supports under the rim.
    for i in 0..16 {
        let a = i as f32 / 16.0 * TAU;
        let p = v3(c.x + a.cos() * (radius - 0.8), c.y - 1.5, c.z + a.sin() * (radius - 0.8));
        kit.stone(p, v3(0.5, 0.9, 0.5), Basis::rot_y(-a), 0.9);
    }
}

fn build_lift(kit: &mut Kit, c: V3) {
    // Timber platform with brass frame hanging from an overhead gantry.
    let (hw, hd) = (1.9, 2.5);
    let mut x = -hw;
    while x < hw {
        let w = kit.rng.range(0.22, 0.3).min(hw - x);
        let color = kit.wood();
        kit.put_box("wood", c + v3(x + w * 0.5, -0.045, 0.0), v3(w - 0.025, 0.07, hd * 2.0), Basis::IDENTITY, color);
        x += w;
    }
    let b = kit.brass();
    for (px, pz, sx, sz) in [(0.0, -hd, hw * 2.0 + 0.1, 0.12), (0.0, hd, hw * 2.0 + 0.1, 0.12), (-hw, 0.0, 0.12, hd * 2.0), (hw, 0.0, 0.12, hd * 2.0)] {
        kit.put_box("metal", c + v3(px, -0.06, pz), v3(sx, 0.14, sz), Basis::IDENTITY, b);
    }
    // Diagonal brass cross bracing on the deck.
    let diag = (hw * hw + hd * hd).sqrt() * 2.0;
    let ang = (hw / hd).atan();
    for s in [-1.0, 1.0] {
        kit.put_box("metal", c + v3(0.0, 0.0, 0.0), v3(0.07, 0.03, diag), Basis::rot_y(s * ang), shade(b, 0.9));
    }
    kit.scene.put("ring_wide", "metal", Xf::at(c + V3::Y * 0.01, v3(1.2, 0.2, 1.2)), b, [0.0; 4]);
    kit.scene.walk.fill(c.x - hw, c.z - hd + 0.2, c.x + hw, c.z + hd - 0.2, |_, _| c.y);
    // Gantry posts on the deck corners up to a beam, plus chains.
    let top = c.y + 6.5;
    let iron = kit.iron();
    for (sx, sz) in [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)] {
        let p = c + v3(sx * (hw - 0.1), 0.0, sz * (hd - 0.1));
        kit.put_box("metal", p + V3::Y * 0.6, v3(0.1, 1.2, 0.1), Basis::IDENTITY, iron);
        kit.chain(v3(p.x, top, p.z), top - c.y - 1.2);
    }
    for sz in [-1.0, 1.0] {
        let color = kit.wood_dark();
        kit.put_box("wood", v3(c.x, top + 0.2, c.z + sz * (hd - 0.1)), v3(9.4, 0.35, 0.3), Basis::IDENTITY, color);
    }
    for sx in [-4.5, 4.5] {
        for sz in [-1.0, 1.0] {
            let color = kit.wood_dark();
            kit.put_box("wood", v3(c.x + sx, (top + ABYSS) * 0.5, c.z + sz * (hd - 0.1)), v3(0.35, top - ABYSS, 0.35), Basis::IDENTITY, color);
        }
    }
    // A pulley wheel.
    kit.scene.put("ring_wide", "metal", Xf::new(v3(c.x, top - 0.3, c.z), Basis::rot_x(FRAC_PI_2), v3(0.9, 0.5, 0.9)), b, [0.0; 4]);
    // Chains continue below the deck.
    for sx in [-1.0, 1.0] {
        kit.chain(c + v3(sx * 1.2, -0.2, 0.0), 6.0);
    }
    kit.candles(c + v3(hw - 0.4, 0.0, -hd + 0.4), 2, 0.07, 1.0);
}

fn furnish(kit: &mut Kit, rooms: &[RoomSpec]) {
    let red = srgb(104, 34, 26);
    let room = |name: &str| rooms.iter().find(|r| r.name == name).unwrap();

    // Gatehouse: raised dais, braziers, guard, banners.
    let g = room("gatehouse");
    kit.floor(g.x0 + WALL, g.z0 + WALL, g.x1 - WALL, g.z0 + 3.5, g.y + 0.8);
    kit.stairs(v3(6.0, g.y + 0.8, g.z0 + 3.5), V3::Z, 1.8, 3.0, g.y);
    kit.scene.walk.fill(g.x0 + WALL, g.z0 + WALL, g.x1 - WALL, g.z0 + 3.5, |_, _| g.y + 0.8);
    // Dais front face.
    let mut x = g.x0 + WALL;
    while x < g.x1 - WALL - 0.1 {
        let w = kit.rng.range(0.4, 0.7).min(g.x1 - WALL - x);
        if !(4.5..7.5).contains(&(x + w * 0.5)) {
            kit.stone(v3(x + w * 0.5, g.y + 0.4, g.z0 + 3.4), v3(w - 0.03, 0.78, 0.25), Basis::IDENTITY, 0.95);
        }
        x += w;
    }
    kit.brazier(v3(g.x0 + 1.6, g.y + 0.8, g.z0 + 1.5), 1.4);
    kit.brazier(v3(g.x1 - 1.6, g.y + 0.8, g.z0 + 1.5), 1.4);
    kit.figure(v3(6.0, g.y + 0.8, g.z0 + 2.0), 0.1, Figure::guard());
    kit.banner(v3(3.5, g.y + 3.0, g.z0 + WALL), V3::Z, 0.8, 1.5, red);
    kit.banner(v3(8.5, g.y + 3.0, g.z0 + WALL), V3::Z, 0.8, 1.5, red);
    kit.barrel(v3(g.x0 + 1.4, g.y, g.z1 - 1.6), 1.0);
    kit.crate_box(v3(g.x1 - 1.6, g.y, g.z1 - 1.7), 0.7, 0.3);
    kit.rubble(v3(g.x0 + 2.0, g.y, 7.0), 0.6, 8);

    // Study: table, chairs, shelves, carpet, scholar.
    let s = room("study");
    kit.carpet(16.0, 3.5, 21.0, 8.5, s.y, red, 1.0);
    kit.table(v3(18.5, s.y, 5.5), (2.2, 1.0), 0.0);
    kit.chair(v3(18.5, s.y, 6.6), PI);
    kit.chair(v3(17.0, s.y, 4.4), 0.0);
    kit.figure(v3(20.3, s.y, 6.2), -2.4, Figure::priest());
    kit.bookshelf(v3(16.0, s.y, s.z0 + WALL + 0.22), 0.0, 1.8, 2.0);
    kit.bookshelf(v3(20.8, s.y, s.z0 + WALL + 0.22), 0.0, 1.8, 2.0);
    kit.scene.walk.block(15.0, s.z0, 22.0, s.z0 + WALL + 0.5);
    kit.candelabra(v3(15.3, s.y, 8.6));
    kit.barrel(v3(22.0, s.y, 8.8), 0.8);

    // Forge: hearth in the back wall, anvil, workbench, barrels.
    let f = room("forge");
    let hx = 2.2;
    for (dx, h) in [(-1.3, 2.4), (1.3, 2.4)] {
        kit.pier(hx + dx, f.z0 + 1.1, f.y, f.y + h, 0.7);
    }
    kit.stone(v3(hx, f.y + 2.25, f.z0 + 1.1), v3(3.4, 0.5, 0.9), Basis::IDENTITY, 0.9);
    kit.stone(v3(hx, f.y + 2.7, f.z0 + 0.9), v3(2.6, 0.5, 0.8), Basis::IDENTITY, 0.85);
    kit.stone(v3(hx, f.y + 0.15, f.z0 + 1.1), v3(1.9, 0.3, 0.9), Basis::IDENTITY, 0.8);
    kit.fire(v3(hx, f.y + 0.3, f.z0 + 1.1), 0.55, 9.0, 9.0, true);
    kit.scene.walk.block(hx - 1.7, f.z0, hx + 1.7, f.z0 + 1.8);
    let iron = kit.iron();
    let anvil = v3(4.2, f.y, 16.5);
    kit.put_box("metal", anvil + V3::Y * 0.25, v3(0.3, 0.5, 0.3), Basis::IDENTITY, iron);
    kit.put_box("metal", anvil + V3::Y * 0.58, v3(0.7, 0.18, 0.26), Basis::IDENTITY, iron);
    kit.scene.walk.block(anvil.x - 0.5, anvil.z - 0.4, anvil.x + 0.5, anvil.z + 0.4);
    kit.table(v3(7.2, f.y, 15.4), (1.6, 0.9), FRAC_PI_2);
    kit.table(v3(2.0, f.y, 19.5), (1.8, 0.9), 0.0);
    kit.barrel(v3(0.4, f.y, 15.2), 1.0);
    kit.barrel(v3(0.5, f.y, 16.4), 0.9);
    kit.crate_box(v3(8.6, f.y, 20.5), 0.6, 0.2);
    kit.figure(v3(5.4, f.y, 18.0), -0.6, Figure::brute());

    // Hall: long runner, wall candles, knight.
    let h = room("hall");
    kit.carpet(15.6, 15.0, 18.4, 31.0, h.y, red, 0.0);
    for z in [15.5, 19.5, 24.5, 28.5] {
        kit.candelabra(v3(h.x0 + WALL + 0.45, h.y, z));
        kit.candelabra(v3(h.x1 - WALL - 0.45, h.y, z + 1.5));
    }
    kit.figure(v3(17.0, h.y, 20.0), 0.3, Figure::knight());
    kit.rubble(v3(14.3, h.y, 27.0), 0.5, 7);

    // Ruin: collapsed corner, rubble heaps, scattered stores, guard.
    let r = room("ruin");
    kit.rubble(v3(r.x1 - 1.8, r.y, r.z0 + 1.8), 1.4, 40);
    kit.rubble(v3(r.x0 + 2.0, r.y, r.z1 - 1.6), 0.9, 18);
    kit.barrel(v3(29.6, r.y, 4.6), 1.0);
    kit.barrel(v3(30.5, r.y, 4.4), 0.9);
    kit.crate_box(v3(34.6, r.y, 9.6), 0.6, 0.6);
    kit.figure(v3(31.8, r.y, 7.6), 0.4, Figure::guard());

    // Chapel: statue niche, altar, candle banks, runner, priest.
    let c = room("chapel");
    kit.statue(v3(44.5, c.y, c.z0 + 1.6), 0.0, 1.6, None);
    for dx in [-1.5, 1.5] {
        kit.pier(44.5 + dx, c.z0 + 1.2, c.y, c.y + 3.6, 0.6);
    }
    kit.stone(v3(44.5, c.y + 3.75, c.z0 + 1.2), v3(3.7, 0.4, 0.8), Basis::IDENTITY, 1.0);
    let altar = v3(44.5, c.y, c.z0 + 3.6);
    kit.stone(altar + V3::Y * 0.45, v3(2.4, 0.9, 0.9), Basis::IDENTITY, 1.05);
    kit.carpet(43.2, c.z0 + 3.15, 45.8, c.z0 + 4.05, c.y + 0.9, red, 2.0);
    kit.scene.walk.block(42.8, c.z0, 46.2, c.z0 + 4.2);
    for dx in [-0.9, -0.3, 0.3, 0.9] {
        kit.candles(altar + v3(dx, 0.92, 0.0), 2, 0.08, 0.7);
    }
    for (x, z) in [(41.5, 3.0), (47.5, 3.0), (41.2, 5.5), (47.8, 5.5)] {
        kit.candles(v3(x, c.y, z), 5, 0.22, 1.2);
    }
    kit.carpet(43.3, c.z0 + 4.6, 45.7, c.z1 - 0.2, c.y, red, 0.0);
    kit.figure(v3(46.0, c.y, 6.6), -0.4, Figure::priest());
    kit.banner(v3(41.0, c.y + 3.2, c.z0 + WALL), V3::Z, 0.7, 1.4, red);
    kit.banner(v3(48.0, c.y + 3.2, c.z0 + WALL), V3::Z, 0.7, 1.4, red);

    // Treasury: gold heaps, open chests, shelves, two figures.
    let t = room("treasury");
    kit.gold_pile(v3(56.5, t.y, 5.2), 1.0);
    kit.gold_pile(v3(60.2, t.y, 4.8), 0.8);
    kit.gold_pile(v3(58.6, t.y, 8.6), 0.6);
    kit.chest(v3(55.0, t.y, 9.4), 0.4, true);
    kit.chest(v3(61.4, t.y, 7.6), -1.2, true);
    kit.chest(v3(61.2, t.y, 10.6), -0.5, false);
    kit.bookshelf(v3(55.5, t.y, t.z0 + WALL + 0.22), 0.0, 1.6, 2.2);
    kit.bookshelf(v3(60.8, t.y, t.z0 + WALL + 0.22), 0.0, 1.6, 2.2);
    kit.carpet(55.0, 10.5, 59.0, 12.1, t.y, srgb(40, 70, 52), 1.0);
    kit.figure(v3(57.2, t.y, 7.2), 2.6, Figure::brute());
    kit.figure(v3(59.5, t.y, 11.2), -2.8, Figure::knight());
    kit.candles(v3(54.2, t.y, 3.4), 4, 0.18, 1.2);
    kit.candles(v3(62.0, t.y, 12.0), 3, 0.15, 1.0);

    // Barracks: weapon racks, bunk crates, fighter, candles.
    let b = room("barracks");
    kit.figure(v3(59.0, b.y, 23.0), -2.0, Figure::brute());
    kit.crate_box(v3(61.6, b.y, 20.0), 0.7, 0.1);
    kit.crate_box(v3(61.5, b.y, 21.0), 0.55, 0.5);
    kit.barrel(v3(55.5, b.y, 25.6), 1.0);
    kit.table(v3(60.5, b.y, 25.2), (1.6, 0.8), 0.0);
    kit.candelabra(v3(55.4, b.y, 19.6));
    kit.banner(v3(57.0, b.y + 2.0, b.z0 + WALL), V3::Z, 0.6, 1.2, red);

    // Shrine: glowing violet statue among candles.
    let sh = room("shrine");
    kit.statue(v3(2.0, sh.y, 29.6), 0.5, 1.4, Some([0.55, 0.25, 1.0]));
    for (x, z) in [(0.4, 28.2), (3.8, 28.0), (0.6, 31.8), (4.2, 31.4)] {
        kit.candles(v3(x, sh.y, z), 4, 0.15, 1.0);
    }
    kit.carpet(4.8, 29.0, 8.2, 31.0, sh.y, srgb(70, 36, 90), 1.0);
    kit.figure(v3(5.6, sh.y, 32.4), -0.9, Figure::mage());
    kit.rubble(v3(0.5, sh.y, 33.5), 0.6, 9);
    kit.crate_box(v3(7.8, sh.y, 27.4), 0.6, 0.4);

    // Storage: crates, table, green rug, guard.
    let st = room("storage");
    kit.carpet(48.0, 35.5, 51.5, 39.0, st.y, srgb(36, 72, 54), 1.0);
    kit.table(v3(49.6, st.y, 37.2), (1.6, 0.9), 0.0);
    for (x, z, s) in [(41.6, 37.8, 0.8), (42.5, 38.9, 0.6), (41.5, 39.2, 0.6), (42.4, 37.6, 0.5)] {
        kit.crate_box(v3(x, st.y, z), s, kit.rng.sym(0.3));
    }
    kit.barrel(v3(51.6, st.y, 33.2), 1.0);
    kit.barrel(v3(50.6, st.y, 32.9), 0.9);
    kit.chest(v3(45.5, st.y, 39.4), 0.0, false);
    kit.figure(v3(46.2, st.y, 35.0), 0.6, Figure::guard());
    kit.candles(v3(51.8, st.y, 39.6), 4, 0.2, 1.2);
    kit.candles(v3(44.0, st.y + 0.0, 32.6), 3, 0.15, 1.0);

    // Mechanism: a few figures around the dial.
    kit.figure(v3(41.0, 1.0, 19.6), 0.8, Figure::knight());
    kit.figure(v3(47.4, 1.0, 25.0), -2.2, Figure::guard());
    // Bridge traveller.
    kit.figure(v3(27.0, 1.0, 22.0), 1.6, Figure::priest());

    // Clutter along the inner walls, kept clear of doorways and other props.
    for r in rooms {
        let doors: Vec<(f32, f32)> = r.gaps.iter().map(|&(side, c, _)| match side {
            Side::North => (c, r.z0),
            Side::South => (c, r.z1),
            Side::West => (r.x0, c),
            Side::East => (r.x1, c),
        }).collect();
        let perimeter = 2.0 * (r.x1 - r.x0 + r.z1 - r.z0);
        let mut placed = 0;
        let target = (perimeter / 3.2) as usize;
        for _ in 0..target * 6 {
            if placed >= target {
                break;
            }
            let band = WALL + 0.35;
            let (x, z) = match kit.rng.below(4) {
                0 => (kit.rng.range(r.x0 + band, r.x1 - band), r.z0 + band),
                1 => (kit.rng.range(r.x0 + band, r.x1 - band), r.z1 - band),
                2 => (r.x0 + band, kit.rng.range(r.z0 + band, r.z1 - band)),
                _ => (r.x1 - band, kit.rng.range(r.z0 + band, r.z1 - band)),
            };
            if doors.iter().any(|&(dx, dz)| (dx - x).hypot(dz - z) < 2.2) {
                continue;
            }
            let clear = [(-0.45, 0.0), (0.45, 0.0), (0.0, -0.45), (0.0, 0.45), (0.0, 0.0)]
                .iter()
                .all(|&(ox, oz)| kit.scene.walk.height(x + ox, z + oz).is_some_and(|h| (h - r.y).abs() < 0.05));
            if !clear {
                continue;
            }
            kit.trinket(v3(x, r.y, z));
            placed += 1;
        }
    }
    // Scatter a few stray stones over every room for wear.
    for r in rooms {
        for _ in 0..3 {
            let p = v3(kit.rng.range(r.x0 + 1.2, r.x1 - 1.2), r.y, kit.rng.range(r.z0 + 1.2, r.z1 - 1.2));
            kit.rubble(p, 0.25, 3);
        }
    }
    let _ = mix;
}

/// Distant gothic piers and arches dissolving into the blue haze.
fn backdrop(kit: &mut Kit) {
    let dark = srgb(54, 58, 66);
    // Gothic pier: core, corner ribs, string courses, lancet windows, pinnacle.
    let place = |kit: &mut Kit, x: f32, z: f32, w: f32, top: f32| {
        let put = |kit: &mut Kit, p: V3, size: V3, tone: f32| {
            kit.scene.put("box", "backdrop", Xf::at(p, size), shade(dark, tone), [0.0; 4]);
        };
        let bottom = ABYSS - 40.0;
        put(kit, v3(x, (top + bottom) * 0.5, z), v3(w, top - bottom, w), 1.0);
        for (dx, dz) in [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)] {
            put(kit, v3(x + dx * w * 0.5, (top + 2.0 + bottom) * 0.5, z + dz * w * 0.5), v3(w * 0.22, top + 2.0 - bottom, w * 0.22), 0.85);
        }
        let mut y = top - 3.0;
        let mut k = 0;
        while y > bottom {
            put(kit, v3(x, y, z), v3(w + 0.5, 0.45, w + 0.5), 1.1);
            // Lancet windows on the faces toward the diorama.
            if k % 2 == 0 {
                for (fx, fz, sx, sz) in [(0.0, 1.0, 1.0, 0.0), (1.0, 0.0, 0.0, 1.0), (-1.0, 0.0, 0.0, 1.0)] {
                    for o in [-0.22, 0.22] {
                        let c = v3(x + fx * (w * 0.5 + 0.02) + sx * o * w, y - 3.4, z + fz * (w * 0.5 + 0.02) + sz * o * w);
                        let size = v3(if sx > 0.0 { w * 0.16 } else { 0.1 }, 4.2, if sz > 0.0 { w * 0.16 } else { 0.1 });
                        kit.scene.put("box", "backdrop", Xf::at(c, size), shade(dark, 0.18), [0.0; 4]);
                        let apex = Basis::rot_x(if sz > 0.0 { std::f32::consts::FRAC_PI_4 } else { 0.0 }) * Basis::rot_z(if sx > 0.0 { std::f32::consts::FRAC_PI_4 } else { 0.0 });
                        kit.scene.put("box", "backdrop", Xf::new(c + V3::Y * 2.1, apex, v3(if sx > 0.0 { w * 0.113 } else { 0.1 }, w * 0.113, if sz > 0.0 { w * 0.113 } else { 0.1 })), shade(dark, 0.18), [0.0; 4]);
                    }
                }
            }
            y -= 7.0;
            k += 1;
        }
        // Stepped pinnacle and spire.
        for (i, f) in [0.8f32, 0.6, 0.42].iter().enumerate() {
            put(kit, v3(x, top + 0.8 + i as f32 * 1.6, z), v3(w * f, 1.6, w * f), 1.0 + i as f32 * 0.05);
        }
        kit.scene.put("cone", "backdrop", Xf::at(v3(x, top + 4.8 + w * 0.6, z), v3(w * 0.25, w * 1.6, w * 0.25)), shade(dark, 1.05), [0.0; 4]);
    };
    for (x, z, w, top) in [
        (-30.0, -36.0, 9.0, 40.0), (2.0, -54.0, 11.0, 44.0), (34.0, -62.0, 12.0, 52.0), (66.0, -54.0, 10.0, 44.0),
        (96.0, -34.0, 9.0, 38.0), (-40.0, 14.0, 8.0, 14.0), (104.0, 14.0, 8.0, 16.0), (20.0, -30.0, 6.0, -12.0),
        (50.0, -28.0, 7.0, -8.0), (-16.0, 56.0, 7.0, -20.0), (82.0, 62.0, 8.0, -18.0),
        (-24.0, -30.0, 6.0, 44.0), (86.0, -28.0, 6.0, 44.0), (-26.0, 30.0, 6.0, -6.0), (90.0, 34.0, 6.0, -4.0),
    ] {
        place(kit, x, z, w, top);
    }
    // Arches spanning between far piers.
    for (x0, x1, z, y) in [(2.0, 34.0, -58.0, 20.0), (34.0, 66.0, -58.0, 16.0), (-18.0, 2.0, -40.0, 10.0)] {
        let n = 26;
        for i in 0..n {
            let t = i as f32 / (n - 1) as f32;
            let a = t * PI;
            let p = v3(lerp(x0, x1, t), y + a.sin() * (x1 - x0) * 0.32, z);
            let slope = (a.cos() * PI * 0.32).atan();
            kit.scene.put("box", "backdrop", Xf::new(p, Basis::rot_z(slope), v3(2.2, 2.0, 3.0)), shade(dark, 0.9), [0.0; 4]);
        }
    }
    // Cold light rising from the abyss rims the lower towers in blue.
    for (x, z) in [(12.0, 12.0), (26.0, 24.0), (37.0, 14.0), (52.0, 16.0), (32.0, 38.0), (10.0, 38.0), (60.0, 30.0), (-4.0, 24.0), (66.0, 10.0)] {
        kit.scene.light(v3(x, -14.0, z), [0.35, 0.5, 1.0], 12.0, 30.0, false, 0.0);
    }
    // Faint warm windows far below.
    for (x, y, z) in [(-6.0, -14.0, 40.0), (30.0, -22.0, 46.0), (70.0, -18.0, 30.0)] {
        kit.scene.light(v3(x, y, z), CANDLE, 2.0, 6.0, false, 0.1);
        kit.candles(v3(x, y - 0.6, z), 3, 0.12, 0.0);
    }
}
