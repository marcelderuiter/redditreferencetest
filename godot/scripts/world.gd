class_name World
extends RefCounted
## Environment, lights and the abyss backdrop around the level.

const AMBIENT := Color(0.5, 0.48, 0.5)
const FOG := Color8(22, 18, 18)   # near-black haze (the grade cools it slightly)
# A faint cool light on the distant masonry only (cull-masked to the backdrop
# layer): just enough for the nearest piers' faces to separate from the dark.
const ABYSS_LIGHT := Color(0.7, 0.76, 0.95)
const ABYSS_LIGHT_DIR := Vector3(-0.55, -0.65, 0.5)   # travelling down, west, towards the camera
const SUN_DIR := Vector3(0.35, -0.92, 0.12)   # travelling down, east and a little south
const SUN_DIST := 110.0
# Faint neutral fill from the camera side, level layer only, unshadowed:
# the bounce and sky light that keeps sun-shadowed faces and the shafts under
# the platforms reading as grey-brown stone instead of black or torch-orange.
const FILL := Color(1.0, 0.88, 0.74)
const FILL_DIR := Vector3(0.15, -0.3, -0.94)   # travelling away from the camera, slightly down
# Below the floors (Kit.UNDER_LAYER only, unshadowed): a warm key from the
# upper left-front that falls down the piers' front and west faces and catches
# their left arrises, and a dim cool rim from behind-right on the far faces.
# The stone's under-darkening and the height fog fade both with depth.
const PIER_KEY := Color(1.0, 0.9, 0.8)
const PIER_KEY_DIR := Vector3(0.5, -0.45, -0.74)
const PIER_RIM := Color(0.55, 0.65, 1.0)
const PIER_RIM_DIR := Vector3(-0.6, -0.35, 0.72)


## Dev-only overrides for lighting sweeps: TUNE="key=value,..." in the
## environment (keys: ambient, exposure, fog_height, fog_hd, sun, sun_spec, rim, fill,
## pier, pier_rim, candle, bump, detail). scripts/tune.py searches these.
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
	env.ambient_light_energy = tune("ambient", 0.1)
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = tune("exposure", 1.12)
	env.tonemap_white = 8.0
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.2   # only flame cores bloom, not the wax and stone they light
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 1.0)
	# Only tight halos: wide levels stack clustered flames into a haze.
	env.set_glow_level(3, 0.3)
	env.set_glow_level(4, 0.1)
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 4.0
	env.ssao_power = 1.4
	env.ssao_detail = 0.6
	env.fog_enabled = true
	env.fog_light_color = FOG
	env.fog_light_energy = 1.0
	env.fog_density = 0.0004
	# Dark height fog below the floors: each deeper plane of piers sinks
	# further into near-black, so depth (not light) separates them.
	env.fog_height = tune("fog_height", -9)
	env.fog_height_density = tune("fog_hd", 0.05)
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
	sun.light_energy = tune("sun", 1.8148)
	sun.light_specular = tune("sun_spec", 0.25)
	sun.spot_range = SUN_DIST * 2.0
	sun.spot_attenuation = 0.0
	sun.spot_angle = 18.0
	sun.spot_angle_attenuation = 0.2
	sun.shadow_enabled = OS.get_environment("NO_SUN_SHADOW") == ""
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.2
	parent.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.name = "AbyssLight"
	rim.light_color = ABYSS_LIGHT
	rim.light_energy = tune("rim", 0.42)
	rim.light_specular = 0.3
	rim.light_cull_mask = Kit.BACKDROP_LAYER
	rim.shadow_enabled = false
	rim.transform.basis = Basis.looking_at(ABYSS_LIGHT_DIR.normalized(), Vector3.UP)
	parent.add_child(rim)
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.light_color = FILL
	fill.light_energy = tune("fill", 0.2)
	fill.light_specular = 0.0
	fill.light_cull_mask = 1 | Kit.UNDER_LAYER
	fill.shadow_enabled = false
	fill.transform.basis = Basis.looking_at(FILL_DIR.normalized(), Vector3.UP)
	parent.add_child(fill)
	for spec in [["PierKey", PIER_KEY, PIER_KEY_DIR, tune("pier", 0.88)], ["PierRim", PIER_RIM, PIER_RIM_DIR, tune("pier_rim", 0.6)]]:
		var l := DirectionalLight3D.new()
		l.name = spec[0]
		l.light_color = spec[1]
		l.light_energy = spec[3]
		l.light_specular = 0.2
		l.light_cull_mask = Kit.UNDER_LAYER
		l.shadow_enabled = false
		var d: Vector3 = spec[2]
		l.transform.basis = Basis.looking_at(d.normalized(), Vector3.UP)
		parent.add_child(l)
	var out: Array[OmniLight3D] = []
	for l in lights:
		var o := OmniLight3D.new()
		o.position = l.pos
		o.light_color = l.color
		o.light_energy = l.energy
		o.omni_range = l.range
		o.omni_attenuation = l.falloff
		o.shadow_enabled = l.shadow
		# Flames above the floors keep their amber off the piers below.
		if l.pos.y > Kit.UNDER_Y:
			o.light_cull_mask = 0xFFFFF & ~Kit.UNDER_LAYER
		o.light_specular = 0.6
		o.set_meta("base_energy", l.energy)
		parent.add_child(o)
		out.append(o)
	return out


## Distant masonry towers, arches and a few far-off lights in the abyss: an
## irregular colonnade of piers filling every view down past the level (its
## sides, the gaps between its pillars, and the deep space behind it), plus a
## far ring of big towers, all fading into the height fog.
static func backdrop(kit: Kit, layout: Layout) -> void:
	var bounds := layout.rooms[0].rect
	for r in layout.rooms:
		bounds = bounds.merge(r.rect)
	var c := bounds.get_center()
	var spots: Array[Vector2] = []
	var tops: Array[float] = []
	var sizes: Array[Vector2] = []
	# Every element below draws from its own random stream (Kit.stream_rng):
	# the colonnade's rows and each row's spacing, each pier, arch and window,
	# so a change to the level only moves the piers it blocks or frees.
	# Colonnade: a jittered grid with gaps, never inside a room's footprint.
	# Piers under the level stay below its timber frames; behind it they
	# rise higher the further back they stand; beside it they stay low.
	var step := 7.0
	var rows := kit.stream_rng("backdrop:rows")
	var z := bounds.position.y - 90.0
	var iz := 0
	while z < bounds.end.y + 4.0:
		var row := kit.stream_rng("backdrop:row:%d" % iz)
		var x := c.x - 40.0
		var ix := 0
		while x < c.x + 40.0:
			var key := "backdrop:pier:%d,%d" % [iz, ix]
			var g := kit.stream_rng(key)
			ix += 1
			var p := Vector2(x + g.randf_range(-2.0, 2.0), z + g.randf_range(-2.0, 2.0))
			x += step * row.randf_range(0.8, 1.25)
			if g.randf() < 0.3:
				continue
			var blocked := false
			for r in layout.rooms:
				if r.rect.grow(0.8).has_point(p):
					blocked = true
					break
			if blocked:
				continue
			var top := g.randf_range(-30.0, -10.0)
			if bounds.grow(3.0).has_point(p):
				# Down the shafts between the rooms: deep enough that the
				# shafts first drop to darkness, then show far masonry.
				top = g.randf_range(-46.0, -24.0)
			elif p.y < bounds.position.y - 3.0:
				var back := clampf((bounds.position.y - p.y) / 80.0, 0.0, 1.0)
				top = g.randf_range(-26.0, -6.0) + back * g.randf_range(0.0, 32.0)
			var w := g.randf_range(1.8, 4.0)
			var d := g.randf_range(1.8, 4.0)
			spots.append(p)
			tops.append(top)
			sizes.append(Vector2(w, d))
			kit.stream(key + ":masonry", _tower.bind(kit, p, w, d, top))
		z += step * rows.randf_range(0.85, 1.2)
		iz += 1
	# Flanking piers just outside the level's sides, seen beside its walls.
	for side in [-1, 1]:
		var g := kit.stream_rng("backdrop:flank:%d" % side)
		var fz := bounds.end.y + 2.0
		var k := 0
		while fz > bounds.position.y - 40.0:
			var fx := bounds.position.x - g.randf_range(2.5, 7.0) if side < 0 else bounds.end.x + g.randf_range(2.5, 7.0)
			var p := Vector2(fx, fz)
			var top := g.randf_range(-24.0, -12.0)
			var w := g.randf_range(1.8, 3.5)
			var d := g.randf_range(1.8, 3.5)
			spots.append(p)
			tops.append(top)
			sizes.append(Vector2(w, d))
			kit.stream("backdrop:flank:%d:%d:masonry" % [side, k], _tower.bind(kit, p, w, d, top))
			k += 1
			fz -= g.randf_range(5.0, 9.0)
	# A far ring of big towers closes the view.
	for i in 15:
		var g := kit.stream_rng("backdrop:ring:%d" % i)
		var a := TAU * (i + g.randf_range(-0.3, 0.3)) / 15.0
		var p := c + Vector2(cos(a) * 119.0, sin(a) * 95.0) + Vector2(g.randf_range(-4, 4), g.randf_range(-4, 4))
		var w := g.randf_range(5.0, 9.0)
		var d := g.randf_range(5.0, 9.0)
		var top := g.randf_range(-6.0, 30.0)
		if p.y > c.y:
			top = g.randf_range(-34.0, -18.0)
		spots.append(p)
		tops.append(top)
		sizes.append(Vector2(w, d))
		kit.stream("backdrop:ring:%d:masonry" % i, _tower.bind(kit, p, w, d, top))
	# Arches bridging neighbouring piers deep down.
	for i in spots.size():
		var a := spots[i]
		var best := -1
		var best_d := 1e9
		for j in spots.size():
			if j != i and a.distance_to(spots[j]) < best_d:
				best_d = a.distance_to(spots[j])
				best = j
		if best >= 0 and best_d < 14.0 and i < best:
			# Arches only span between piers that rise above them.
			var ceiling := minf(tops[i], tops[best]) - 2.0
			kit.stream("backdrop:arch:%.1f,%.1f" % [a.x, a.y], _arches.bind(kit, a, spots[best], ceiling))
	# A few lit windows deep down: warm light grazing the far masonry, each
	# coming from a window you can see (on the face towards the viewer).
	var lit := 0
	for i in spots.size():
		var p := spots[i]
		if lit >= 7 or p.y > bounds.end.y:
			continue
		var key := "backdrop:window:%.1f,%.1f" % [p.x, p.y]
		var g := kit.stream_rng(key)
		if g.randf() > 0.12:
			continue
		lit += 1
		var y := minf(tops[i] - g.randf_range(2.5, 10.0), g.randf_range(-40.0, -14.0))
		kit.stream(key, _window.bind(kit, Vector3(p.x, y, p.y + sizes[i].y * 0.5 + 0.02)))
	kit.put("box", "backdrop", Vector3(c.x, Layout.ABYSS - 1.0, c.y), Vector3(400.0, 2.0, 400.0), 0.0, Color(0.5, 0.5, 0.6))
	# The sun (sky key) never reaches below the floors: a shadow-only sheet
	# just under the lowest slab (extended west, where the light comes from)
	# leaves the shafts to the lanterns and the haze, so they fall off into
	# darkness instead of showing sunlit block edges through the gaps.
	kit.put("box", "occluder", Vector3(c.x - 12.0, -2.4, c.y), Vector3(bounds.size.x + 70.0, 0.4, bounds.size.y + 50.0))


## Two arches at random depths between neighbouring piers a and b.
static func _arches(kit: Kit, a: Vector2, b: Vector2, ceiling: float) -> void:
	for k in 2:
		var y := minf(kit.rng.randf_range(-48.0, -14.0), ceiling)
		kit.span("box", "backdrop", Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector2(1.4, 1.6), Color(0.8, 0.82, 0.9))


## A lit window on a far pier's face, and the light it throws.
static func _window(kit: Kit, face: Vector3) -> void:
	kit.put("box", "window_glow", face, Vector3(0.9, 2.0, 0.06))
	kit.light(face + Vector3(0, 0, 2.0), Color(1.0, 0.55, 0.25), 5.0, 15.0)


static func _tower(kit: Kit, p: Vector2, w: float, d: float, top: float) -> void:
	var bottom := Layout.ABYSS
	kit.put("box", "backdrop", Vector3(p.x, (top + bottom) * 0.5, p.y), Vector3(w, top - bottom, d), 0.0, kit.tint(Color(0.85, 0.85, 0.9), 0.15))
	# Coarse courses and buttresses so the silhouettes read as masonry.
	var y := top
	while y > -56.0:
		kit.put("block", "backdrop", Vector3(p.x, y - 0.4, p.y), Vector3(w + 0.5, 0.8, d + 0.5), 0.0, kit.tint(Color(0.9, 0.9, 0.95), 0.1))
		y -= kit.rng.randf_range(4.0, 9.0)
	for s in [-1.0, 1.0]:
		kit.put("block", "backdrop", Vector3(p.x + s * w * 0.5, (top + bottom) * 0.5, p.y + d * 0.5), Vector3(0.9, top - bottom, 0.9), 0.0, Color(0.8, 0.8, 0.85))
	# Tall gothic window slits.
	for k in 3:
		var wy := top - kit.rng.randf_range(3.0, 20.0)
		kit.put("box", "void", Vector3(p.x + kit.rng.randf_range(-w * 0.3, w * 0.3), wy, p.y + d * 0.5 + 0.05), Vector3(0.9, 3.0, 0.1))
