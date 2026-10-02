//! Scene output: instance batches keyed by (mesh, material), point lights and
//! the walkable height grid. Godot consumes these unchanged.
use crate::math::{V3, Xf};
use crate::walk::WalkGrid;
use std::collections::BTreeMap;

/// Floats per instance in a Godot MultiMesh buffer: 3x4 transform, colour, custom.
pub const STRIDE: usize = 20;

pub type BatchKey = (&'static str, &'static str, [i32; 3]);

/// Chunk size in metres (x, y, z).
pub const CHUNK: [f32; 3] = [12.0, 14.0, 12.0];

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Light {
    pub position: V3,
    pub color: [f32; 3],
    pub energy: f32,
    pub range: f32,
    pub shadow: bool,
    /// 0 for a steady light; otherwise flicker amount for candle/fire.
    pub flicker: f32,
}

#[derive(Clone, Debug)]
pub struct Room {
    pub name: &'static str,
    pub center: V3,
}

#[derive(Default)]
pub struct Scene {
    /// (mesh, material, spatial chunk) -> packed instance data. Chunks keep
    /// frustum and shadow culling effective for large batches.
    pub batches: BTreeMap<BatchKey, Vec<f32>>,
    pub lights: Vec<Light>,
    pub rooms: Vec<Room>,
    pub walk: WalkGrid,
    pub spawn: V3,
    pub bounds_min: V3,
    pub bounds_max: V3,
}

impl Scene {
    pub fn put(&mut self, mesh: &'static str, material: &'static str, xf: Xf, color: [f32; 4], custom: [f32; 4]) {
        let o = xf.origin;
        let chunk = [(o.x / CHUNK[0]).floor() as i32, (o.y / CHUNK[1]).floor() as i32, (o.z / CHUNK[2]).floor() as i32];
        let data = self.batches.entry((mesh, material, chunk)).or_default();
        data.extend_from_slice(&xf.rows());
        data.extend_from_slice(&color);
        data.extend_from_slice(&custom);
    }

    pub fn light(&mut self, position: V3, color: [f32; 3], energy: f32, range: f32, shadow: bool, flicker: f32) {
        self.lights.push(Light { position, color, energy, range, shadow, flicker });
    }

    pub fn instance_count(&self) -> usize {
        self.batches.values().map(|d| d.len() / STRIDE).sum()
    }
}
