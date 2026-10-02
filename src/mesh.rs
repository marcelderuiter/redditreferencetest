//! Procedural base meshes shared by every instance batch. Triangles are
//! counter-clockwise from the front; the Godot adapter converts winding.
use crate::math::{V3, v3};
use crate::rng::noise3;
use std::collections::HashMap;

#[derive(Clone, Debug, Default)]
pub struct Mesh {
    pub positions: Vec<[f32; 3]>,
    pub normals: Vec<[f32; 3]>,
    pub uvs: Vec<[f32; 2]>,
    pub indices: Vec<u32>,
}

/// Every base mesh by name. Instances refer to these names.
pub fn library() -> Vec<(&'static str, Mesh)> {
    vec![
        ("stone0", rough_box(0.14, 3, 0.035, 11)),
        ("stone1", rough_box(0.12, 3, 0.045, 23)),
        ("stone2", rough_box(0.16, 3, 0.030, 37)),
        ("stone3", rough_box(0.10, 3, 0.050, 53)),
        ("flag0", rough_box(0.05, 3, 0.012, 71)),
        ("flag1", rough_box(0.06, 3, 0.016, 83)),
        ("box", rounded_box(0.05)),
        ("slab", rounded_box(0.12)),
        ("cyl", lathe(&capped(&[(0.5, 0.5), (0.5, -0.5)], 0.05), 16)),
        ("barrel", lathe(&barrel_profile(), 16)),
        ("cone", lathe(&capped(&[(0.32, 0.5), (0.5, -0.5)], 0.04), 16)),
        ("sphere", lathe(&sphere_profile(10), 16)),
        ("ring", lathe(&ring_profile(0.86, 0.5, 0.5), 48)),
        ("ring_wide", lathe(&ring_profile(0.62, 0.5, 0.5), 48)),
        ("flame", lathe(&flame_profile(), 10)),
    ]
}

fn push_quad_ccw(indices: &mut Vec<u32>, a: u32, b: u32, c: u32, d: u32) {
    indices.extend_from_slice(&[a, b, c, a, c, d]);
}

const FACES: [(V3, V3, V3); 6] = [
    (V3::X, v3(0.0, 0.0, -1.0), V3::Y),
    (v3(-1.0, 0.0, 0.0), V3::Z, V3::Y),
    (V3::Y, V3::X, v3(0.0, 0.0, -1.0)),
    (v3(0.0, -1.0, 0.0), V3::X, V3::Z),
    (V3::Z, V3::X, V3::Y),
    (v3(0.0, 0.0, -1.0), v3(-1.0, 0.0, 0.0), V3::Y),
];

/// Face grid: optional mid-bevel rows, then `interior` spans across the face.
fn grid_coords(r: f32, interior: usize, smooth_bevel: bool) -> Vec<f32> {
    let mut c = vec![-0.5];
    if smooth_bevel {
        c.push(-0.5 + r * 0.3);
    }
    c.push(-0.5 + r);
    for i in 1..interior {
        c.push(-0.5 + r + (1.0 - 2.0 * r) * i as f32 / interior as f32);
    }
    c.push(0.5 - r);
    if smooth_bevel {
        c.push(0.5 - r * 0.3);
    }
    c.push(0.5);
    c
}

/// Unit cube with rounded edges of radius `r`, analytic normals and per-face UVs.
pub fn rounded_box(r: f32) -> Mesh {
    let coords = grid_coords(r, 1, false);
    let n = coords.len();
    let mut m = Mesh::default();
    for (normal, u, v) in FACES {
        let base = m.positions.len() as u32;
        for (j, &cv) in coords.iter().enumerate() {
            for &cu in &coords {
                let p = normal * 0.5 + u * cu + v * cv;
                let (pos, nrm) = round_point(p, r, normal);
                m.positions.push(pos.arr());
                m.normals.push(nrm.arr());
                m.uvs.push([cu + 0.5, 1.0 - (cv + 0.5)]);
                let _ = j;
            }
        }
        for j in 0..n - 1 {
            for i in 0..n - 1 {
                let a = base + (j * n + i) as u32;
                push_quad_ccw(&mut m.indices, a, a + 1, a + 1 + n as u32, a + n as u32);
            }
        }
    }
    m
}

fn round_point(p: V3, r: f32, face: V3) -> (V3, V3) {
    let lim = 0.5 - r;
    let inner = v3(p.x.clamp(-lim, lim), p.y.clamp(-lim, lim), p.z.clamp(-lim, lim));
    let d = p - inner;
    if d.length() < 1e-6 {
        (p, face)
    } else {
        let n = d.normalize();
        (inner + n * r, n)
    }
}

/// Chunky hand-cut stone: rounded box, skewed and displaced by seeded noise,
/// welded so smooth normals follow the bumps.
pub fn rough_box(r: f32, interior: usize, amp: f32, seed: u64) -> Mesh {
    let coords = grid_coords(r, interior, false);
    let n = coords.len();
    let skew = (noise3(seed, 0.3, 0.1, 0.2) * 0.08, noise3(seed, 1.3, 2.1, 0.2) * 0.08);
    let mut positions: Vec<V3> = Vec::new();
    let mut uvs = Vec::new();
    let mut indices = Vec::new();
    let mut weld: HashMap<[i32; 3], u32> = HashMap::new();
    for (normal, u, v) in FACES {
        let mut ids = Vec::with_capacity(n * n);
        for &cv in &coords {
            for &cu in &coords {
                let p = normal * 0.5 + u * cu + v * cv;
                let key = [
                    (p.x * 4096.0).round() as i32,
                    (p.y * 4096.0).round() as i32,
                    (p.z * 4096.0).round() as i32,
                ];
                let id = *weld.entry(key).or_insert_with(|| {
                    let (pos, nrm) = round_point(p, r, normal);
                    let f = 3.1;
                    let bump = noise3(seed, p.x * f, p.y * f, p.z * f) * 0.7
                        + noise3(seed ^ 7, p.x * 7.0, p.y * 7.0, p.z * 7.0) * 0.3;
                    // Chipped corners: pull corners in more than faces.
                    let corner = (p.x.abs() + p.y.abs() + p.z.abs() - 1.0).max(0.0);
                    let mut q = pos + nrm * (bump * amp - corner * 0.05);
                    q.x += q.y * skew.0;
                    q.z += q.y * skew.1;
                    positions.push(q);
                    uvs.push([cu + 0.5, cv + 0.5]);
                    positions.len() as u32 - 1
                });
                ids.push(id);
            }
        }
        for j in 0..n - 1 {
            for i in 0..n - 1 {
                let a = ids[j * n + i];
                let b = ids[j * n + i + 1];
                let c = ids[(j + 1) * n + i + 1];
                let d = ids[(j + 1) * n + i];
                push_quad_ccw(&mut indices, a, b, c, d);
            }
        }
    }
    let mut normals = vec![V3::ZERO; positions.len()];
    for t in indices.chunks_exact(3) {
        let (a, b, c) = (positions[t[0] as usize], positions[t[1] as usize], positions[t[2] as usize]);
        let fnrm = (b - a).cross(c - a);
        for &i in t {
            normals[i as usize] = normals[i as usize] + fnrm;
        }
    }
    Mesh {
        positions: positions.iter().map(|p| p.arr()).collect(),
        normals: normals.iter().map(|n| n.normalize().arr()).collect(),
        uvs,
        indices,
    }
}

/// Profile (radius, y) from the top centre outward, down, then to the bottom
/// centre. Repeated points make hard edges.
pub fn lathe(profile: &[(f32, f32)], segments: usize) -> Mesh {
    let mut m = Mesh::default();
    let count = profile.len();
    let mut lengths = vec![0.0f32; count];
    for i in 1..count {
        let (a, b) = (profile[i - 1], profile[i]);
        lengths[i] = lengths[i - 1] + ((b.0 - a.0).powi(2) + (b.1 - a.1).powi(2)).sqrt();
    }
    let total = lengths[count - 1].max(1e-6);
    let same = |a: (f32, f32), b: (f32, f32)| (a.0 - b.0).abs() < 1e-6 && (a.1 - b.1).abs() < 1e-6;
    for (i, &p) in profile.iter().enumerate() {
        let prev = (i > 0 && !same(profile[i - 1], p)).then(|| (p.0 - profile[i - 1].0, p.1 - profile[i - 1].1));
        let next = (i + 1 < count && !same(profile[i + 1], p)).then(|| (profile[i + 1].0 - p.0, profile[i + 1].1 - p.1));
        let norm2 = |t: (f32, f32)| {
            let l = (t.0 * t.0 + t.1 * t.1).sqrt().max(1e-9);
            (t.0 / l, t.1 / l)
        };
        let t = match (prev, next) {
            (Some(a), Some(b)) => {
                let (a, b) = (norm2(a), norm2(b));
                (a.0 + b.0, a.1 + b.1)
            }
            (Some(a), None) => a,
            (None, Some(b)) => b,
            (None, None) => (0.0, -1.0),
        };
        let t = norm2(t);
        let (nr, ny) = (-t.1, t.0);
        for s in 0..=segments {
            let a = s as f32 / segments as f32 * std::f32::consts::TAU;
            let (sin, cos) = a.sin_cos();
            m.positions.push([p.0 * cos, p.1, p.0 * sin]);
            m.normals.push(v3(nr * cos, ny, nr * sin).normalize().arr());
            m.uvs.push([s as f32 / segments as f32, lengths[i] / total]);
        }
    }
    let row = (segments + 1) as u32;
    for i in 0..count - 1 {
        if same(profile[i], profile[i + 1]) {
            continue;
        }
        for s in 0..segments as u32 {
            let a = i as u32 * row + s;
            let b = a + row;
            // Column s+1 lies counter-clockwise when viewed from above.
            m.indices.extend_from_slice(&[a, a + 1, b + 1, a, b + 1, b]);
        }
    }
    m
}

/// Closes an outline with flat caps and chamfered rims of size `c`.
fn capped(side: &[(f32, f32)], c: f32) -> Vec<(f32, f32)> {
    let (top, bottom) = (side[0], side[side.len() - 1]);
    let mut p = vec![(0.0, top.1), (top.0 - c, top.1), (top.0 - c, top.1), (top.0, top.1 - c), (top.0, top.1 - c)];
    p.extend_from_slice(&side[1..side.len() - 1]);
    p.extend_from_slice(&[(bottom.0, bottom.1 + c), (bottom.0, bottom.1 + c), (bottom.0 - c, bottom.1), (bottom.0 - c, bottom.1), (0.0, bottom.1)]);
    p
}

fn barrel_profile() -> Vec<(f32, f32)> {
    let mut side = Vec::new();
    for i in 0..=8 {
        let y = 0.5 - i as f32 / 8.0;
        side.push((0.42 + 0.08 * (1.0 - (2.0 * y).powi(2)), y));
    }
    capped(&side, 0.03)
}

fn sphere_profile(rings: usize) -> Vec<(f32, f32)> {
    (0..=rings)
        .map(|i| {
            let a = i as f32 / rings as f32 * std::f32::consts::PI;
            (0.5 * a.sin(), 0.5 * a.cos())
        })
        .collect()
}

fn ring_profile(inner: f32, outer: f32, half: f32) -> Vec<(f32, f32)> {
    let h = half * 0.2;
    vec![
        (inner, h), (outer, h), (outer, h), (outer, -h), (outer, -h), (inner, -h), (inner, -h), (inner, h),
    ]
}

fn flame_profile() -> Vec<(f32, f32)> {
    let mut p = vec![(0.0, 0.5)];
    for i in 1..=8 {
        let t = i as f32 / 8.0;
        let y = 0.5 - t;
        let r = 0.5 * (t * std::f32::consts::PI).sin() * (0.35 + 0.65 * t);
        p.push((r.max(0.0), y));
    }
    p.push((0.0, -0.5));
    p
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn triangles_face_their_vertex_normals() {
        for (name, mesh) in library() {
            let mut bad = 0;
            let tris = mesh.indices.len() / 3;
            for t in mesh.indices.chunks_exact(3) {
                let p = |i: u32| V3 { x: mesh.positions[i as usize][0], y: mesh.positions[i as usize][1], z: mesh.positions[i as usize][2] };
                let n = |i: u32| V3 { x: mesh.normals[i as usize][0], y: mesh.normals[i as usize][1], z: mesh.normals[i as usize][2] };
                let face = (p(t[1]) - p(t[0])).cross(p(t[2]) - p(t[0]));
                if face.length() < 1e-6 {
                    continue;
                }
                if face.dot(n(t[0]) + n(t[1]) + n(t[2])) <= 0.0 {
                    bad += 1;
                }
            }
            assert!(bad * 50 <= tris, "{name}: {bad}/{tris} triangles face away from normals");
        }
    }
}
