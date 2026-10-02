//! Headless CLI: generate a seed, report scene statistics and validate that
//! every room is reachable on foot.
use platforms_test::{World, mesh, scene::STRIDE};

fn main() {
    let mut seed = 7u64;
    let mut walk_ticks = 0usize;
    let mut args = std::env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--seed" => seed = args.next().and_then(|v| v.parse().ok()).expect("--seed N"),
            "--walk" => walk_ticks = args.next().and_then(|v| v.parse().ok()).expect("--walk TICKS"),
            "--help" | "-h" => {
                println!("Usage: platforms-test [--seed N] [--walk TICKS]\nPrints batch/light statistics and room reachability.");
                return;
            }
            other => panic!("unknown argument {other}"),
        }
    }
    let start = std::time::Instant::now();
    let mut world = World::new(seed);
    let built = start.elapsed();
    let scene = &world.scene;
    println!("seed {seed}: built in {:.1} ms", built.as_secs_f64() * 1000.0);
    let mut vertices = 0usize;
    let library = mesh::library();
    let mut totals: std::collections::BTreeMap<(&str, &str), usize> = Default::default();
    for ((mesh_name, material, _), data) in &scene.batches {
        *totals.entry((mesh_name, material)).or_default() += data.len() / STRIDE;
    }
    for ((mesh_name, material), count) in &totals {
        let tris = library.iter().find(|(n, _)| n == mesh_name).map_or(0, |(_, m)| m.indices.len() / 3);
        vertices += count * tris;
        println!("  {mesh_name:>10} / {material:<6} {count:>7} instances");
    }
    println!("batches {}", scene.batches.len());
    println!("instances {}  triangles {:.2} M  lights {} (shadowed {})", scene.instance_count(), vertices as f64 / 1e6,
        scene.lights.len(), scene.lights.iter().filter(|l| l.shadow).count());
    let reach = scene.walk.reachable((scene.spawn.x, scene.spawn.z));
    println!("walkable cells {}  reachable {}", scene.walk.walkable_cells(), reach.iter().filter(|&&r| r).count());
    let mut ok = true;
    for room in &scene.rooms {
        let reached = scene.walk.is_reached(&reach, room.center.x, room.center.z)
            || (-4..=4).any(|d| scene.walk.is_reached(&reach, room.center.x + d as f32 * 0.5, room.center.z + 1.5));
        println!("  {:<10} {}", room.name, if reached { "reachable" } else { "UNREACHABLE" });
        ok &= reached;
    }
    if walk_ticks > 0 {
        for i in 0..walk_ticks {
            let a = i as f32 * 0.004;
            world.player.tick(&world.scene.walk, (a.cos(), a.sin()));
        }
        println!("player after {walk_ticks} ticks: {:?}", world.player.position);
    }
    if !ok {
        std::process::exit(1);
    }
}
