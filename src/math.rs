//! Minimal vector/transform math. Godot convention: metres, +Y up, -Z forward.
use std::ops::{Add, Mul, Neg, Sub};

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct V3 {
    pub x: f32,
    pub y: f32,
    pub z: f32,
}

pub const fn v3(x: f32, y: f32, z: f32) -> V3 {
    V3 { x, y, z }
}

impl V3 {
    pub const ZERO: V3 = v3(0.0, 0.0, 0.0);
    pub const ONE: V3 = v3(1.0, 1.0, 1.0);
    pub const X: V3 = v3(1.0, 0.0, 0.0);
    pub const Y: V3 = v3(0.0, 1.0, 0.0);
    pub const Z: V3 = v3(0.0, 0.0, 1.0);

    pub fn splat(v: f32) -> V3 {
        v3(v, v, v)
    }
    pub fn dot(self, o: V3) -> f32 {
        self.x * o.x + self.y * o.y + self.z * o.z
    }
    pub fn cross(self, o: V3) -> V3 {
        v3(
            self.y * o.z - self.z * o.y,
            self.z * o.x - self.x * o.z,
            self.x * o.y - self.y * o.x,
        )
    }
    pub fn length(self) -> f32 {
        self.dot(self).sqrt()
    }
    pub fn normalize(self) -> V3 {
        let l = self.length();
        if l > 1e-12 { self * (1.0 / l) } else { V3::ZERO }
    }
    pub fn mul(self, o: V3) -> V3 {
        v3(self.x * o.x, self.y * o.y, self.z * o.z)
    }
    pub fn lerp(self, o: V3, t: f32) -> V3 {
        self + (o - self) * t
    }
    pub fn arr(self) -> [f32; 3] {
        [self.x, self.y, self.z]
    }
}

impl Add for V3 {
    type Output = V3;
    fn add(self, o: V3) -> V3 {
        v3(self.x + o.x, self.y + o.y, self.z + o.z)
    }
}
impl Sub for V3 {
    type Output = V3;
    fn sub(self, o: V3) -> V3 {
        v3(self.x - o.x, self.y - o.y, self.z - o.z)
    }
}
impl Mul<f32> for V3 {
    type Output = V3;
    fn mul(self, s: f32) -> V3 {
        v3(self.x * s, self.y * s, self.z * s)
    }
}
impl Neg for V3 {
    type Output = V3;
    fn neg(self) -> V3 {
        v3(-self.x, -self.y, -self.z)
    }
}

/// Rotation basis stored as columns (local X, Y, Z axes in world space).
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Basis {
    pub x: V3,
    pub y: V3,
    pub z: V3,
}

impl Basis {
    pub const IDENTITY: Basis = Basis { x: V3::X, y: V3::Y, z: V3::Z };

    /// Yaw about +Y, then pitch about local X, then roll about local Z.
    pub fn euler(yaw: f32, pitch: f32, roll: f32) -> Basis {
        Basis::rot_y(yaw) * Basis::rot_x(pitch) * Basis::rot_z(roll)
    }
    pub fn rot_y(a: f32) -> Basis {
        let (s, c) = a.sin_cos();
        Basis { x: v3(c, 0.0, -s), y: V3::Y, z: v3(s, 0.0, c) }
    }
    pub fn rot_x(a: f32) -> Basis {
        let (s, c) = a.sin_cos();
        Basis { x: V3::X, y: v3(0.0, c, s), z: v3(0.0, -s, c) }
    }
    pub fn rot_z(a: f32) -> Basis {
        let (s, c) = a.sin_cos();
        Basis { x: v3(c, s, 0.0), y: v3(-s, c, 0.0), z: V3::Z }
    }
    /// Frame whose local +Z follows `forward`, keeping local +X horizontal.
    pub fn looking(forward: V3) -> Basis {
        let z = forward.normalize();
        let mut x = V3::Y.cross(z);
        if x.length() < 1e-5 {
            x = V3::X;
        }
        let x = x.normalize();
        let y = z.cross(x).normalize();
        Basis { x, y, z }
    }
    pub fn apply(&self, v: V3) -> V3 {
        self.x * v.x + self.y * v.y + self.z * v.z
    }
    pub fn scaled(self, s: V3) -> Basis {
        Basis { x: self.x * s.x, y: self.y * s.y, z: self.z * s.z }
    }
}

impl Mul for Basis {
    type Output = Basis;
    fn mul(self, o: Basis) -> Basis {
        Basis { x: self.apply(o.x), y: self.apply(o.y), z: self.apply(o.z) }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Xf {
    pub basis: Basis,
    pub origin: V3,
}

impl Xf {
    pub const IDENTITY: Xf = Xf { basis: Basis::IDENTITY, origin: V3::ZERO };

    pub fn new(origin: V3, basis: Basis, scale: V3) -> Xf {
        Xf { basis: basis.scaled(scale), origin }
    }
    pub fn at(origin: V3, scale: V3) -> Xf {
        Xf::new(origin, Basis::IDENTITY, scale)
    }
    pub fn point(&self, p: V3) -> V3 {
        self.basis.apply(p) + self.origin
    }
    pub fn then(&self, local: &Xf) -> Xf {
        Xf { basis: self.basis * local.basis, origin: self.point(local.origin) }
    }
    /// Godot MultiMesh row-major 3x4 layout.
    pub fn rows(&self) -> [f32; 12] {
        let b = &self.basis;
        let o = self.origin;
        [
            b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z,
        ]
    }
}

pub fn clamp(v: f32, lo: f32, hi: f32) -> f32 {
    v.max(lo).min(hi)
}

pub fn lerp(a: f32, b: f32, t: f32) -> f32 {
    a + (b - a) * t
}

pub fn smoothstep(a: f32, b: f32, x: f32) -> f32 {
    let t = clamp((x - a) / (b - a), 0.0, 1.0);
    t * t * (3.0 - 2.0 * t)
}
