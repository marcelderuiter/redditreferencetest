class_name World
extends RefCounted
## Environment, lights and the abyss backdrop around the level.

const AMBIENT := Color(0.5, 0.48, 0.5)
const FOG := Color8(29, 31, 42)
const SUN_DIR := Vector3(0.15, -0.97, -0.2)   # travelling down, east and north
const SUN_DIST := 110.0


## Dev-only overrides for lighting sweeps: TUNE="key=value,..." in the
## environment (keys: ambient, exposure, fog_height, fog_hd, sun).
static func tune(key: String, value: float) -> float:
	for kv in OS.get_environment("TUNE").split(",", false):
		var p := kv.split("=")
		if p.size() == 2 and p[0] == key:
			return p[1].to_float()
	return value


static func environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color8(24, 26, 36)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT
	env.ambient_light_energy = tune("ambient", 0.2)
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = tune("exposure", 1.12)
	env.tonemap_white = 8.0
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.3)
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 4.0
	env.ssao_power = 1.4
	env.ssao_detail = 0.6
	env.fog_enabled = true
	env.fog_light_color = FOG
	env.fog_light_energy = 1.0
	env.fog_density = 0.0004
	env.fog_height = tune("fog_height", -7.0)
	env.fog_height_density = tune("fog_hd", 0.052)
	env.fog_sky_affect = 0.0
	return env


static func setup(parent: Node3D, lights: Array[Dictionary]) -> Array[OmniLight3D]:
	var we := WorldEnvironment.new()
	we.environment = environment()
	parent.add_child(we)
	# The "sun" is a distant spotlight rather than a DirectionalLight3D:
	# directional shadow splits are fitted to a symmetric frustum and miss
	# parts of the shifted (keystone) matched view. A spot has its own map.
	var sun := SpotLight3D.new()
	sun.name = "Sun"
	var dir := SUN_DIR.normalized()
	var target := Vector3(0.5, 0.0, -3.5)
	sun.position = target - dir * SUN_DIST
	sun.look_at_from_position(sun.position, target, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)
	sun.light_color = Color(1.0, 0.9, 0.82)
	sun.light_energy = tune("sun", 2.0)
	sun.spot_range = SUN_DIST * 2.0
	sun.spot_attenuation = 0.0
	sun.spot_angle = 18.0
	sun.spot_angle_attenuation = 0.2
	sun.shadow_enabled = OS.get_environment("NO_SUN_SHADOW") == ""
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.2
	parent.add_child(sun)
	var out: Array[OmniLight3D] = []
	for l in lights:
		var o := OmniLight3D.new()
		o.position = l.pos
		o.light_color = l.color
		o.light_energy = l.energy
		o.omni_range = l.range
		o.omni_attenuation = 1.4
		o.shadow_enabled = l.shadow
		o.light_specular = 0.6
		o.set_meta("base_energy", l.energy)
		parent.add_child(o)
		out.append(o)
	return out


## Distant masonry towers, arches and a few far-off lights in the abyss.
static func backdrop(kit: Kit, layout: Layout) -> void:
	var bounds := layout.rooms[0].rect
	for r in layout.rooms:
		bounds = bounds.merge(r.rect)
	var c := bounds.get_center()
	var rng := kit.rng
	var spots: Array[Vector2] = []
	# Two loose rings of towers, never inside the level's footprint.
	for ring in [[34.0, 9], [60.0, 13], [95.0, 15]]:
		var rad: float = ring[0]
		var n: int = ring[1]
		for i in n:
			var a := TAU * (i + rng.randf_range(-0.3, 0.3)) / n
			var p := c + Vector2(cos(a) * rad * 1.25, sin(a) * rad) + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
			if bounds.grow(6.0).has_point(p):
				continue
			spots.append(p)
	# A closer ring of pillars that stay below the level, seen through gaps.
	for i in 22:
		var a := TAU * (i + rng.randf_range(-0.35, 0.35)) / 22.0
		var p := c + Vector2(cos(a) * rng.randf_range(20.0, 30.0) * 1.2, sin(a) * rng.randf_range(16.0, 24.0))
		_tower(kit, p, rng.randf_range(2.5, 5.0), rng.randf_range(2.5, 5.0), rng.randf_range(-24.0, -7.0))
	var tops: Array[float] = []
	var sizes: Array[Vector2] = []
	for p in spots:
		var w := rng.randf_range(4.0, 9.0)
		var d := rng.randf_range(4.0, 9.0)
		sizes.append(Vector2(w, d))
		var top := rng.randf_range(-6.0, 30.0)
		# Towers between the camera and the level stay deep in the fog.
		if p.y > c.y - 4.0 and absf(p.x - c.x) < bounds.size.x * 0.5 + 25.0:
			top = rng.randf_range(-34.0, -18.0)
		tops.append(top)
		_tower(kit, p, w, d, top)
	# Arches bridging neighbouring towers deep down.
	for i in spots.size():
		var a := spots[i]
		var best := -1
		var best_d := 1e9
		for j in spots.size():
			if j != i and a.distance_to(spots[j]) < best_d:
				best_d = a.distance_to(spots[j])
				best = j
		if best >= 0 and best_d < 30.0 and i < best:
			var b := spots[best]
			# Arches only span between towers that rise above them.
			var ceiling := minf(tops[i], tops[best]) - 2.0
			for k in 2:
				var y := minf(rng.randf_range(-40.0, -14.0), ceiling)
				kit.span("box", "backdrop", Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector2(2.4, 2.0), Color(0.8, 0.82, 0.9))
	# Lit windows on some towers: warm light grazing the far masonry, and a
	# few glimmers deep in the shaft, each coming from a window you can see.
	for i in spots.size():
		if rng.randf() > 0.4:
			continue
		var p := spots[i]
		var to_c := c - p
		var y := minf(tops[i] - rng.randf_range(2.5, 10.0), rng.randf_range(-30.0, 8.0))
		var n := Vector3(signf(to_c.x), 0, 0) if absf(to_c.x) > absf(to_c.y) else Vector3(0, 0, signf(to_c.y))
		var half := sizes[i] * 0.5
		var face := Vector3(p.x, y, p.y) + n * ((half.x if n.x != 0.0 else half.y) + 0.02)
		kit.put("box", "window_glow", face, Vector3(0.06, 2.0, 0.9) if n.x != 0.0 else Vector3(0.9, 2.0, 0.06))
		kit.light(face + n * 2.0, Color(1.0, 0.55, 0.25), 5.0, 15.0)
	kit.put("box", "backdrop", Vector3(c.x, Layout.ABYSS - 1.0, c.y), Vector3(400.0, 2.0, 400.0), 0.0, Color(0.5, 0.5, 0.6))


static func _tower(kit: Kit, p: Vector2, w: float, d: float, top: float) -> void:
	var bottom := Layout.ABYSS
	kit.put("box", "backdrop", Vector3(p.x, (top + bottom) * 0.5, p.y), Vector3(w, top - bottom, d), 0.0, kit.tint(Color(0.85, 0.85, 0.9), 0.15))
	# Coarse courses and buttresses so the silhouettes read as masonry.
	var y := top
	while y > -40.0:
		kit.put("block", "backdrop", Vector3(p.x, y - 0.4, p.y), Vector3(w + 0.5, 0.8, d + 0.5), 0.0, kit.tint(Color(0.9, 0.9, 0.95), 0.1))
		y -= kit.rng.randf_range(4.0, 9.0)
	for s in [-1.0, 1.0]:
		kit.put("block", "backdrop", Vector3(p.x + s * w * 0.5, (top + bottom) * 0.5, p.y + d * 0.5), Vector3(0.9, top - bottom, 0.9), 0.0, Color(0.8, 0.8, 0.85))
	# Tall gothic window slits.
	for k in 3:
		var wy := top - kit.rng.randf_range(3.0, 20.0)
		kit.put("box", "void", Vector3(p.x + kit.rng.randf_range(-w * 0.3, w * 0.3), wy, p.y + d * 0.5 + 0.05), Vector3(0.9, 3.0, 0.1))
