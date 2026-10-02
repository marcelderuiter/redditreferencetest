//! Godot adapter. Rust owns generation and movement; Godot receives packed
//! MultiMesh buffers, base meshes and light descriptions.
use godot::prelude::*;
use platforms_test::{World, mesh, scene::{STRIDE, Scene}};

struct Extension;

#[gdextension]
unsafe impl ExtensionLibrary for Extension {}

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct PlatformsBridge {
    world: Option<World>,
    base: Base<RefCounted>,
}

fn v(p: platforms_test::math::V3) -> Vector3 {
    Vector3::new(p.x, p.y, p.z)
}

fn pack_batches(scene: &Scene) -> Array<VarDictionary> {
    let mut out = Array::new();
    for ((mesh_name, material, _), data) in &scene.batches {
        let mut d = VarDictionary::new();
        d.set("mesh", *mesh_name);
        d.set("material", *material);
        d.set("count", (data.len() / STRIDE) as i64);
        d.set("buffer", &PackedFloat32Array::from(data.as_slice()));
        out.push(&d);
    }
    out
}

#[godot_api]
impl PlatformsBridge {
    #[func]
    fn generate(&mut self, seed: i64) -> bool {
        self.world = Some(World::new(seed as u64));
        true
    }

    /// Base meshes: name -> {positions, normals, uvs, indices} (Godot winding).
    #[func]
    fn meshes(&self) -> VarDictionary {
        let mut out = VarDictionary::new();
        for (name, m) in mesh::library() {
            let mut d = VarDictionary::new();
            let positions: Vec<Vector3> = m.positions.iter().map(|p| Vector3::new(p[0], p[1], p[2])).collect();
            let normals: Vec<Vector3> = m.normals.iter().map(|p| Vector3::new(p[0], p[1], p[2])).collect();
            let uvs: Vec<Vector2> = m.uvs.iter().map(|p| Vector2::new(p[0], p[1])).collect();
            // Core meshes are counter-clockwise; Godot front faces are clockwise.
            let indices: Vec<i32> = m.indices.chunks_exact(3).flat_map(|t| [t[0] as i32, t[2] as i32, t[1] as i32]).collect();
            d.set("positions", &PackedVector3Array::from(positions.as_slice()));
            d.set("normals", &PackedVector3Array::from(normals.as_slice()));
            d.set("uvs", &PackedVector2Array::from(uvs.as_slice()));
            d.set("indices", &PackedInt32Array::from(indices.as_slice()));
            out.set(name, &d);
        }
        out
    }

    #[func]
    fn batches(&self) -> Array<VarDictionary> {
        self.world.as_ref().map_or_else(Array::new, |w| pack_batches(&w.scene))
    }

    #[func]
    fn player_batches(&self) -> Array<VarDictionary> {
        self.world.as_ref().map_or_else(Array::new, |w| pack_batches(&w.player_model))
    }

    #[func]
    fn lights(&self) -> Array<VarDictionary> {
        let mut out = Array::new();
        let Some(world) = &self.world else { return out };
        for l in &world.scene.lights {
            let mut d = VarDictionary::new();
            d.set("position", v(l.position));
            d.set("color", Color::from_rgb(l.color[0], l.color[1], l.color[2]));
            d.set("energy", l.energy);
            d.set("range", l.range);
            d.set("shadow", l.shadow);
            d.set("flicker", l.flicker);
            out.push(&d);
        }
        out
    }

    #[func]
    fn bounds(&self) -> VarDictionary {
        let mut d = VarDictionary::new();
        if let Some(w) = &self.world {
            d.set("min", v(w.scene.bounds_min));
            d.set("max", v(w.scene.bounds_max));
            d.set("spawn", v(w.scene.spawn));
        }
        d
    }

    /// Advance the player by real seconds with a world-space XZ input.
    #[func]
    fn advance(&mut self, seconds: f64, input: Vector2) -> VarDictionary {
        let mut d = VarDictionary::new();
        let Some(w) = &mut self.world else { return d };
        w.player.advance(&w.scene.walk, seconds as f32, (input.x, input.y));
        d.set("position", v(w.player.position));
        d.set("yaw", w.player.yaw);
        d.set("stride", w.player.stride);
        d
    }
}
