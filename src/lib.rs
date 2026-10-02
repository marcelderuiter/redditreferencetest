//! Platforms visual test: seeded diorama generation and player movement.
//! Everything here runs headlessly; Godot only presents the output.
pub mod kit;
pub mod layout;
pub mod math;
pub mod mesh;
pub mod player;
pub mod props;
pub mod rng;
pub mod scene;
pub mod walk;

use kit::Kit;
use math::V3;
use props::Figure;
use scene::Scene;

pub struct World {
    pub seed: u64,
    pub scene: Scene,
    pub player: player::Player,
    /// The player's miniature in its own local space.
    pub player_model: Scene,
}

impl World {
    pub fn new(seed: u64) -> World {
        let scene = layout::generate(seed);
        let player = player::Player::new(scene.spawn);
        let mut kit = Kit::new(seed ^ 0xF1_6E);
        kit.prop_scale = layout::PROP_SCALE;
        kit.figure(V3::ZERO, 0.0, Figure::hero());
        World { seed, scene, player, player_model: kit.scene }
    }

    pub fn player_position(&self) -> V3 {
        self.player.position
    }
}
