class_name Builder
extends RefCounted
## Turns the solved layout into instanced geometry: block-built floors,
## parapets, towers, plank bridges, stone stairs, props and lights.

const COURSE := 0.32        # masonry course height
const FLOOR_T := 0.9        # floor slab thickness below the walking surface
const ABYSS := -70.0        # towers run down to here

var b := Batch.new()
var lights := []
var rng := RandomNumberGenerator.new()
var props: Props
var solved: Dictionary
var grid: WalkGrid


func _init(solved_layout: Dictionary, walk: WalkGrid, seed: int) -> void:
	solved = solved_layout
	grid = walk
	rng.seed = seed
	props = Props.new(b, lights, rng)
	_register()


func _register() -> void:
	b.register_mesh("bbox", Meshes.bevel_box(0.09))
	b.register_mesh("bbox_s", Meshes.bevel_box(0.18))
	b.register_mesh("box", Meshes.box())
	b.register_mesh("cyl", Meshes.cylinder(16))
	b.register_mesh("cyl8", Meshes.cylinder(8))
	b.register_mesh("cone", Meshes.cylinder(12, 0.08, 0.5))
	b.register_mesh("sphere", Meshes.sphere(12))
	b.register_mesh("torus", Meshes.torus(0.46, 0.5, 64))
	b.register_mesh("flame", Meshes.flame())
	b.register_mesh("arch", Meshes.arch_panel())
	var stone := _mat("stone", {})
	b.register_material("stone", stone)
	b.register_material("stone_dark", _mat("stone", {"albedo": Color(0.22, 0.2, 0.18)}))
	b.register_material("floor", _mat("stone", {"albedo": Color(0.32, 0.28, 0.23), "bump_strength": 1.5}))
	b.register_material("marble", _mat("stone", {"albedo": Color(0.62, 0.57, 0.5), "bump_strength": 0.3, "grime": 0.25}))
	b.register_material("masonry", _mat("masonry", {}))
	b.register_material("masonry_dark", _mat("masonry", {"albedo": Color(0.16, 0.15, 0.14)}))
	var void_mat := StandardMaterial3D.new()
	void_mat.albedo_color = Color(0.015, 0.015, 0.02)
	void_mat.roughness = 1.0
	b.register_material("void", void_mat)
	b.register_material("wood", _mat("wood", {}))
	b.register_material("wood_dark", _mat("wood", {"albedo": Color(0.17, 0.125, 0.08)}))
	b.register_material("bronze", _mat("metal", {}))
	b.register_material("iron", _mat("metal", {"albedo": Color(0.2, 0.19, 0.18), "roughness_v": 0.5, "metallic_v": 0.7}))
	b.register_material("pewter", _mat("metal", {"albedo": Color(0.38, 0.34, 0.3), "roughness_v": 0.38, "tarnish": 0.6}))
	b.register_material("gold", _mat("metal", {"albedo": Color(0.85, 0.6, 0.22), "roughness_v": 0.25, "tarnish": 0.15}))
	b.register_material("cloth", _mat("cloth", {"field": Color(0.36, 0.2, 0.1)}))
	b.register_material("flame", _mat("flame", {}))
	b.register_material("glow", _mat("glow", {}))
	b.register_material("glow_dim", _mat("glow", {"energy": 0.28, "tint": Color(1.0, 0.42, 0.1)}))
	b.register_material("glow_fire", _mat("glow", {"energy": 3.0, "tint": Color(1.0, 0.4, 0.08)}))
	b.register_material("wax", _mat("wax", {}))
	b.register_material("backdrop", _mat("backdrop", {"albedo": Color(0.16, 0.17, 0.21)}))
	var parchment := StandardMaterial3D.new()
	parchment.albedo_color = Color(0.75, 0.65, 0.48)
	b.register_material("parchment", parchment)
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.roughness = 0.85
	b.register_material("paint", paint)


static func _mat(shader: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/%s.gdshader" % shader)
	for k in params:
		var v = params[k]
		if v is Color:
			v = Vector3(v.r, v.g, v.b)
		m.set_shader_parameter(k, v)
	return m


func build(parent: Node3D) -> void:
	for room in solved.rooms.values():
		if room.shape == "circle":
			_circle_floor(room)
			_rim_wall(room)
			_round_tower(room)
		else:
			_rect_floor(room)
			_walls(room)
			if room.name == "lift":
				_lift_frame(room)
			else:
				_tower(room)
	for link in solved.links:
		match link.kind:
			"bridge": _bridge(link)
			"stairs": _stairs(link)
			"door": pass
		if link.kind != "door":
			_under_ties(link)
	_props()
	_backdrop()
	print("instances: %d, lights: %d" % [b.instance_count(), lights.size()])
	b.emit(parent)
	_emit_lights(parent)


func _tint(base := 1.0, spread := 0.18) -> Color:
	# Brightness plus a warm/cool shift per block: sandstone vs grey granite.
	var v := base * (1.0 - spread * 0.5 + rng.randf() * spread)
	var warm := rng.randf_range(-1.0, 1.0)
	return Color(v * (1.0 + 0.16 * warm), v * (1.0 + 0.08 * warm), v * (1.0 - 0.24 * warm))


# --- floors -----------------------------------------------------------------

func _rect_floor(room: Dictionary) -> void:
	var r: Rect2 = room.rect
	var y: float = room.y
	var kind: String = room.floor
	if kind == "plate":
		_plate_floor(room)
		return
	var tz := 0.55 if kind == "flag" else 0.36
	var tx_base := 0.75 if kind == "flag" else 0.4
	var z := r.position.y
	var row := 0
	while z < r.end.y - 0.01:
		var dz: float = min(tz * rng.randf_range(0.85, 1.15), r.end.y - z)
		var x := r.position.x - (rng.randf() * tx_base * 0.6 if row % 2 else 0.0)
		while x < r.end.x - 0.01:
			var dx := tx_base * rng.randf_range(0.7, 1.3)
			var x0: float = max(x, r.position.x)
			var x1: float = min(x + dx, r.end.x)
			if x1 - x0 > 0.08:
				var h := rng.randf_range(0.12, 0.2)
				var top := y + rng.randf_range(-0.025, 0.02)
				var c := Vector3((x0 + x1) * 0.5, top - h * 0.5, z + dz * 0.5)
				var tb := Basis(Vector3.UP, rng.randf_range(-0.04, 0.04)) * Basis(Vector3.RIGHT, rng.randf_range(-0.05, 0.05)) * Basis(Vector3.BACK, rng.randf_range(-0.05, 0.05))
				b.add("bbox_s", "floor", Transform3D(tb * Basis.from_scale(Vector3(x1 - x0 - 0.025, h, dz - 0.025)), c), _tint(0.95, 0.8))
			x += dx
		z += dz
		row += 1
	# Slab body under the tiles, edged with a protruding course of blocks.
	b.box("box", "stone_dark", Vector3(r.get_center().x, y - 0.1 - FLOOR_T * 0.5, r.get_center().y), Vector3(r.size.x - 0.1, FLOOR_T, r.size.y - 0.1))
	if room.name == "lift":
		return
	_rim_course(Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), y, Vector2(0, -1))
	_rim_course(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), y, Vector2(0, 1))
	_rim_course(Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y), y, Vector2(-1, 0))
	_rim_course(Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), y, Vector2(1, 0))


## Two courses of blocks forming the outer face of the floor slab.
func _rim_course(a: Vector2, c: Vector2, y: float, out: Vector2) -> void:
	var dir := (c - a).normalized()
	var length := a.distance_to(c)
	var yaw := -atan2(dir.y, dir.x)
	for course in 3:
		var t := -rng.randf() * 0.4 if course % 2 else 0.0
		var cy := y - 0.12 - COURSE * (course + 0.5)
		while t < length:
			var l := rng.randf_range(0.45, 0.85)
			var t0: float = max(t, 0.0)
			var t1: float = min(t + l, length)
			if t1 - t0 > 0.1:
				var mid := a + dir * (t0 + t1) * 0.5 + out * (0.18 + 0.06 * course)
				b.box("bbox", "stone", Vector3(mid.x, cy, mid.y), Vector3(t1 - t0 - 0.03, COURSE - 0.03, 0.4), yaw, _tint(0.8, 0.3))
			t += l


func _plate_floor(room: Dictionary) -> void:
	var r: Rect2 = room.rect
	var y: float = room.y
	var x := r.position.x
	while x < r.end.x - 0.01:
		b.box("bbox", "wood", Vector3(x + 0.14, y - 0.05, r.get_center().y), Vector3(0.26, 0.1, r.size.y - 0.1), 0.0, _tint(1.0, 0.3), Color(rng.randf(), 0, 0, 0))
		x += 0.29
	for z in [r.position.y + 0.1, r.get_center().y, r.end.y - 0.1]:
		b.box("box", "bronze", Vector3(r.get_center().x, y - 0.01, z), Vector3(r.size.x, 0.04, 0.12))
	for x2 in [r.position.x + 0.08, r.end.x - 0.08]:
		b.box("box", "bronze", Vector3(x2, y - 0.01, r.get_center().y), Vector3(0.12, 0.05, r.size.y))
	b.box("box", "bronze", Vector3(r.get_center().x, y - 0.25, r.get_center().y), Vector3(r.size.x, 0.3, r.size.y))


func _circle_floor(room: Dictionary) -> void:
	var c: Vector2 = room.center
	var R: float = room.radius
	var y: float = room.y
	var rad := 0.3
	while rad < R:
		var ring_w := 0.5
		var n := maxi(6, int(TAU * rad / 0.55))
		var off := rng.randf() * TAU
		for k in n:
			var a := off + TAU * (k + 0.5) / n
			var p := c + Vector2(cos(a), sin(a)) * (rad + ring_w * 0.5)
			var w := TAU * (rad + ring_w * 0.5) / n
			b.box("bbox_s", "floor", Vector3(p.x, y - 0.08 + rng.randf_range(-0.02, 0.015), p.y), Vector3(w - 0.04, 0.16, ring_w - 0.04), -a + PI * 0.5, _tint(1.0, 0.35))
		rad += ring_w
	b.box("cyl", "stone_dark", Vector3(c.x, y - 0.1 - FLOOR_T * 0.5, c.y), Vector3(R * 2 - 0.1, FLOOR_T, R * 2 - 0.1))
	# Outer rim course.
	for course in 3:
		var n := int(TAU * R / 0.7)
		for k in n:
			var a := TAU * (k + 0.5 * (course % 2)) / n
			var p := c + Vector2(cos(a), sin(a)) * (R + 0.15)
			b.box("bbox", "stone", Vector3(p.x, y - 0.12 - COURSE * (course + 0.5), p.y), Vector3(0.4, COURSE - 0.03, TAU * R / n - 0.03), -a, _tint(0.8, 0.3))


# --- walls ------------------------------------------------------------------

func _walls(room: Dictionary) -> void:
	var r: Rect2 = room.rect
	var t := Layout.WALL_T
	var sides := {
		"n": [Vector2(r.position.x, r.position.y + t * 0.5), Vector2(r.end.x, r.position.y + t * 0.5), Vector2(0, 1)],
		"s": [Vector2(r.position.x, r.end.y - t * 0.5), Vector2(r.end.x, r.end.y - t * 0.5), Vector2(0, -1)],
		"w": [Vector2(r.position.x + t * 0.5, r.position.y), Vector2(r.position.x + t * 0.5, r.end.y), Vector2(1, 0)],
		"e": [Vector2(r.end.x - t * 0.5, r.position.y), Vector2(r.end.x - t * 0.5, r.end.y), Vector2(-1, 0)],
	}
	for side in sides:
		var h: float = room.walls.get(side, 0.0)
		if h <= 0.0:
			continue
		var a: Vector2 = sides[side][0]
		var c: Vector2 = sides[side][1]
		var axis := 0 if side in ["n", "s"] else 1
		# Solid runs between openings.
		var cuts := []
		for o in room.openings[side]:
			cuts.append(o)
		cuts.sort_custom(func(p, q): return p.x < q.x)
		var start: float = a[axis]
		var runs := []
		for o in cuts:
			runs.append(Vector2(start, o.x))
			start = o.y
		runs.append(Vector2(start, c[axis]))
		var tall: bool = side in room.tall
		for run in runs:
			if run.y - run.x < 0.2:
				continue
			var p0 := a
			var p1 := c
			p0[axis] = run.x
			p1[axis] = run.y
			_wall_run(p0, p1, room.y, h, tall, sides[side][2])
		for o in cuts:
			for edge in [o.x, o.y]:
				var p := a
				p[axis] = edge
				_post(Vector3(p.x, room.y, p.y), h + 0.35, 0.7)
	# Corner posts where walls meet.
	for corner in [[r.position, "n", "w"], [Vector2(r.end.x, r.position.y), "n", "e"],
			[Vector2(r.position.x, r.end.y), "s", "w"], [r.end, "s", "e"]]:
		var h1: float = room.walls.get(corner[1], 0.0)
		var h2: float = room.walls.get(corner[2], 0.0)
		if max(h1, h2) <= 0.0:
			continue
		var p: Vector2 = corner[0]
		var inward := Vector2(1 if p.x < r.get_center().x else -1, 1 if p.y < r.get_center().y else -1)
		var q := p + inward * 0.38
		_post(Vector3(q.x, room.y, q.y), max(h1, h2) + 0.6, 0.85)


## Masonry wall from a to c (centre line), height h, inner face toward `inward`.
func _wall_run(a: Vector2, c: Vector2, y: float, h: float, tall: bool, inward: Vector2) -> void:
	var dir := (c - a).normalized()
	var length := a.distance_to(c)
	var yaw := -atan2(dir.y, dir.x)
	var t := Layout.WALL_T
	var courses := maxi(2, int(round(h / COURSE)))
	# Ruined / irregular tops on low walls: each ~1.5 m segment loses 0-1 courses.
	var seg_len := 1.4
	var windows := []
	if tall:
		var n := maxi(1, int(length / 2.6))
		for k in n:
			windows.append(length * (k + 0.5) / n)
	for course in courses + 2:
		var cy := y + COURSE * (course + 0.5)
		var tpos := -rng.randf() * 0.35 if course % 2 else 0.0
		while tpos < length:
			var l := rng.randf_range(0.42, 0.8)
			var t0: float = max(tpos, 0.0)
			var t1: float = min(tpos + l, length)
			tpos += l
			if t1 - t0 < 0.12:
				continue
			var mid_t := (t0 + t1) * 0.5
			var seg := int(mid_t / seg_len)
			var drop := 0
			if not tall:
				var hsh := int(abs(sin(seg * 12.9898 + a.x * 78.233 + a.y * 3.1)) * 43758.5)
				drop = [0, 0, 1, 2, -1, 0, 1, -2][hsh % 8]
			if course >= courses - drop or (tall and course >= courses):
				continue
			# Crenellations on the top course of low walls.
			if not tall and course == courses - 1 - drop and courses >= 3 and int(mid_t / 0.7) % 2 == 1:
				continue
			var in_window := false
			for w in windows:
				if abs(mid_t - w) < 0.55 and cy > y + 0.6 and cy < y + h - 0.7:
					in_window = true
			if in_window:
				continue
			var mid := a + dir * mid_t
			var depth := t - rng.randf_range(0.0, 0.06)
			b.box("bbox", "stone", Vector3(mid.x, cy, mid.y), Vector3(t1 - t0 - 0.025, COURSE - 0.025, depth), yaw, _tint(0.95, 0.3))
	# Buttress posts along low walls, like the reference's square piers.
	if not tall and length > 3.0:
		var n_posts := int(length / 2.8)
		for k in range(1, n_posts + 1):
			var pt := length * k / (n_posts + 1)
			var pp := a + dir * pt
			_post(Vector3(pp.x, y, pp.y), h + rng.randf_range(0.3, 0.9), 0.62)
	# Cap stones on tall walls.
	if tall:
		var tpos := 0.0
		while tpos < length - 0.1:
			var l: float = min(0.9, length - tpos)
			var mid := a + dir * (tpos + l * 0.5)
			b.box("bbox", "stone", Vector3(mid.x, y + courses * COURSE + 0.09, mid.y), Vector3(l - 0.03, 0.18, t + 0.12), yaw, _tint(0.85))
			tpos += l
		for w in windows:
			var p: Vector2 = a + dir * w
			var back: Vector2 = p - inward * (t * 0.5 - 0.02)
			var wy := y + 0.6
			var wh := h - 1.3
			var basis: Basis
			if inward.x != 0:
				basis = Basis(Vector3.UP, PI * 0.5 * inward.x)
			else:
				basis = Basis(Vector3.UP, 0.0 if inward.y > 0 else PI)
			b.add("arch", "glow_dim", Transform3D(basis * Basis.from_scale(Vector3(1.05, wh, 1)), Vector3(back.x, wy, back.y)), Color(1, 1, 1) * rng.randf_range(0.5, 1.0))
			# Mullion and sill.
			var front: Vector2 = p + inward * (t * 0.5 - 0.05)
			b.box("box", "stone", Vector3(front.x, wy + wh * 0.45, front.y), Vector3(0.08, wh * 0.9, 0.08), yaw)
			b.box("bbox", "stone", Vector3(front.x, wy - 0.05, front.y), Vector3(1.3, 0.12, 0.3), yaw)


## Square pier with cap; optionally carries candles.
func _post(p: Vector3, h: float, w: float) -> void:
	var courses := int(h / 0.45)
	for k in courses:
		var s := w - (0.04 if k % 2 else 0.0)
		b.box("bbox", "stone", p + Vector3(0, 0.45 * (k + 0.5), 0), Vector3(s, 0.43, s), rng.randf_range(-0.03, 0.03), _tint(0.95, 0.3))
	var top := p + Vector3(0, courses * 0.45, 0)
	b.box("bbox", "stone", top + Vector3(0, 0.08, 0), Vector3(w + 0.14, 0.16, w + 0.14), 0.0, _tint(0.8))
	if rng.randf() < 0.45:
		props.candle_cluster(top + Vector3(0, 0.16, 0), rng.randi_range(1, 3), 0.15, rng.randf() < 0.4)


func _rim_wall(room: Dictionary) -> void:
	var c: Vector2 = room.center
	var R: float = room.radius - Layout.WALL_T * 0.5
	var h: float = room.walls.rim
	var courses := int(h / COURSE)
	var n := int(TAU * R / 0.6)
	for course in courses:
		for k in n:
			var a := TAU * (k + 0.5 * (course % 2)) / n
			var open := false
			for o in room.openings.rim:
				if WalkGrid._ang_in(a, o):
					open = true
			if open:
				continue
			var p := c + Vector2(cos(a), sin(a)) * R
			b.box("bbox", "stone", Vector3(p.x, room.y + COURSE * (course + 0.5), p.y), Vector3(Layout.WALL_T, COURSE - 0.025, TAU * R / n - 0.03), -a, _tint(0.95, 0.3))
	for o in room.openings.rim:
		for a in [o.x, o.y]:
			var p := c + Vector2(cos(a), sin(a)) * R
			_post(Vector3(p.x, room.y, p.y), h + 0.5, 0.65)


# --- substructure -----------------------------------------------------------

func _tower(room: Dictionary) -> void:
	# The room is a slab on a few tall pillars: an apron of blocks around the
	# slab edge, square pillars at the corners (and mid-span on long sides),
	# timber X-bracing between pillars, open void everywhere else.
	var r: Rect2 = room.rect
	var top: float = room.y - 0.1 - FLOOR_T
	b.box("box", "stone_dark", Vector3(r.get_center().x, top - 0.7, r.get_center().y), Vector3(r.size.x - 0.6, 1.4, r.size.y - 0.6))
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for side in 4:
		_rim_course(corners[side], corners[(side + 1) % 4], top - 0.0, _outward(corners[side], corners[(side + 1) % 4], r))
	var ps := 2.0 if min(r.size.x, r.size.y) > 6.0 else 1.5
	var line := r.grow(-ps * 0.5 - 0.15)
	var xs := _spread(line.position.x, line.end.x, 7.0)
	var zs := _spread(line.position.y, line.end.y, 7.0)
	var pillars := []
	for x in xs:
		for z in zs:
			if x in [xs[0], xs[-1]] or z in [zs[0], zs[-1]]:
				pillars.append(Vector2(x, z))
	for p in pillars:
		_pier(Vector3(p.x, top - 1.2, p.y), top - 1.2 - ABYSS, ps)
	# Bracing along the perimeter between neighbouring pillars.
	for axis in 2:
		var along: Array = xs if axis == 0 else zs
		var others: Array = [zs[0], zs[-1]] if axis == 0 else [xs[0], xs[-1]]
		for o in others:
			for k in along.size() - 1:
				var a3 := Vector3(along[k], 0, o) if axis == 0 else Vector3(o, 0, along[k])
				var c3 := Vector3(along[k + 1], 0, o) if axis == 0 else Vector3(o, 0, along[k + 1])
				var d := (c3 - a3).normalized() * ps * 0.5
				for level in 2:
					var y0 := top - 1.6 - level * 5.0
					var y1 := y0 - 4.5
					_strut(a3 + d + Vector3(0, y0, 0), c3 - d + Vector3(0, y1, 0), 0.22, "wood_dark")
					_strut(a3 + d + Vector3(0, y1, 0), c3 - d + Vector3(0, y0, 0), 0.22, "wood_dark")
					_strut(a3 + d + Vector3(0, y0, 0), c3 - d + Vector3(0, y0, 0), 0.26, "wood_dark")
				# Bronze tie rod just under the apron.
				_strut(a3 + d + Vector3(0, top - 1.45, 0), c3 - d + Vector3(0, top - 1.45, 0), 0.1, "bronze")


static func _spread(a: float, c: float, max_gap: float) -> Array:
	var n := maxi(1, int(ceil((c - a) / max_gap)))
	var out := []
	for k in n + 1:
		out.append(lerpf(a, c, float(k) / n))
	return out


static func _outward(a: Vector2, c: Vector2, r: Rect2) -> Vector2:
	var mid := (a + c) * 0.5
	var d := mid - r.get_center()
	if abs(d.x) / r.size.x > abs(d.y) / r.size.y:
		return Vector2(sign(d.x), 0)
	return Vector2(0, sign(d.y))


func _pier(top: Vector3, h: float, w := 1.1) -> void:
	b.box("box", "masonry", top + Vector3(0, -1.0 - (h - 1.0) * 0.5, 0), Vector3(w, h - 1.0, w), 0.0, Color(0.95, 0.92, 0.88))
	for k in 10:
		var s := w + 0.06 + (0.05 if k % 2 else 0.0)
		b.box("bbox", "stone", top + Vector3(0, -0.25 - 0.45 * k, 0), Vector3(s, 0.43, s), rng.randf_range(-0.02, 0.02), _tint(0.85 - k * 0.04, 0.3))


func _round_tower(room: Dictionary) -> void:
	var c: Vector2 = room.center
	var top: float = room.y - 0.1 - FLOOR_T
	var h := top - ABYSS
	b.box("cyl", "masonry", Vector3(c.x, top - h * 0.5, c.y), Vector3(room.radius * 1.5, h, room.radius * 1.5))
	for k in 8:
		var a := TAU * k / 8.0
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * room.radius * 0.8
		b.box("box", "masonry", Vector3(p.x, top - 1.0 - (h - 1.0) * 0.5, p.y), Vector3(1.1, h - 1.0, 1.1), -a)
		for j in 6:
			b.box("bbox", "stone", Vector3(p.x, top - 1.2 - 0.5 * j, p.y), Vector3(1.2, 0.47, 1.2), -a, _tint(0.7 - j * 0.05, 0.25))


func _lift_frame(room: Dictionary) -> void:
	var r: Rect2 = room.rect
	var top: float = room.y - 0.4
	for p in [r.position + Vector2(0.3, 0.3), Vector2(r.end.x - 0.3, r.position.y + 0.3), Vector2(r.position.x + 0.3, r.end.y - 0.3), r.end - Vector2(0.3, 0.3)]:
		b.box("box", "bronze", Vector3(p.x, (top + ABYSS) * 0.5, p.y), Vector3(0.22, top - ABYSS, 0.22))
	for k in 6:
		var y := top - 1.5 - k * 3.0
		for z in [r.position.y + 0.3, r.end.y - 0.3]:
			b.box("box", "bronze", Vector3(r.get_center().x, y, z), Vector3(r.size.x - 0.6, 0.14, 0.14))
		for x in [r.position.x + 0.3, r.end.x - 0.3]:
			b.box("box", "bronze", Vector3(x, y, r.get_center().y), Vector3(0.14, 0.14, r.size.y - 0.6))
	# Chains running down the shaft.
	for p in [r.get_center() + Vector2(-0.8, 0), r.get_center() + Vector2(0.8, 0)]:
		b.box("box", "iron", Vector3(p.x, top - 10.0, p.y), Vector3(0.06, 20.0, 0.06))


# --- connections ------------------------------------------------------------

func _bridge(link: Dictionary) -> void:
	var dir := Vector3(link.dir.x, 0, link.dir.y)
	var cross := Vector3(-dir.z, 0, dir.x)
	var p0: Vector3 = link.p0 - dir * 0.35
	var p1: Vector3 = link.p1 + dir * 0.35
	var length := Vector2(p0.x, p0.z).distance_to(Vector2(p1.x, p1.z))
	var w: float = link.width
	var yaw := -atan2(dir.z, dir.x)
	var slope := atan2(p1.y - p0.y, length)
	var iron: bool = link.style == "iron"
	var deck_mat := "iron" if iron else "wood"
	# Deck planks (across the span).
	var t := 0.0
	while t < length:
		var pc := p0.lerp(p1, (t + 0.14) / length)
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, slope) * Basis.from_scale(Vector3(0.26, 0.08, w + rng.randf_range(-0.05, 0.05)))
		var pos := pc + Vector3(0, -0.05 + rng.randf_range(-0.012, 0.012), 0) + cross * rng.randf_range(-0.03, 0.03)
		b.add("bbox", deck_mat, Transform3D(basis, pos), _tint(1.0, 0.45), Color(rng.randf(), 0, 0, 0))
		t += 0.3
	var mid := (p0 + p1) * 0.5
	var beam_basis := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, slope)
	# Stringers and bronze edge straps.
	for s in [-1.0, 1.0]:
		var off: Vector3 = cross * (w * 0.5 - 0.1) * s
		b.add("box", "wood_dark", Transform3D(beam_basis * Basis.from_scale(Vector3(length, 0.3, 0.22)), mid + off + Vector3(0, -0.25, 0)), Color(1, 1, 1), Color(rng.randf(), 0, 0, 0))
		b.add("box", "bronze", Transform3D(beam_basis * Basis.from_scale(Vector3(length, 0.07, 0.05)), mid + cross * (w * 0.5 + 0.02) * s + Vector3(0, -0.12, 0)))
		# Railing: posts, top and mid rail.
		var n := maxi(2, int(length / 1.3) + 1)
		for k in n:
			var pp: Vector3 = p0.lerp(p1, float(k) / (n - 1)) + cross * (w * 0.5 - 0.05) * s
			b.box("box", "bronze", pp + Vector3(0, 0.45, 0), Vector3(0.1, 0.95, 0.1), yaw)
			b.box("bbox", "bronze", pp + Vector3(0, 0.95, 0), Vector3(0.16, 0.08, 0.16), yaw)
		b.add("box", "bronze", Transform3D(beam_basis * Basis.from_scale(Vector3(length, 0.07, 0.07)), mid + cross * (w * 0.5 - 0.05) * s + Vector3(0, 0.9, 0)))
		b.add("box", "iron", Transform3D(beam_basis * Basis.from_scale(Vector3(length, 0.04, 0.04)), mid + cross * (w * 0.5 - 0.05) * s + Vector3(0, 0.5, 0)))
	# Truss under the deck: bottom chord plus diagonals.
	var depth := 1.2
	for s in [-1.0, 1.0]:
		var off: Vector3 = cross * (w * 0.5 - 0.15) * s
		b.add("box", "bronze", Transform3D(beam_basis * Basis.from_scale(Vector3(length - 0.8, 0.12, 0.12)), mid + off + Vector3(0, -depth, 0)))
		var n := maxi(2, int(length / 1.2))
		for k in n:
			var ta := float(k) / n
			var tb := float(k + 1) / n
			var top_a := p0.lerp(p1, ta) + off + Vector3(0, -0.35, 0)
			var bot_b := p0.lerp(p1, tb) + off + Vector3(0, -depth, 0)
			if k % 2:
				top_a = p0.lerp(p1, tb) + off + Vector3(0, -0.35, 0)
				bot_b = p0.lerp(p1, ta) + off + Vector3(0, -depth, 0)
			_strut(top_a, bot_b, 0.08, "bronze")
		for k in n + 1:
			var pa := p0.lerp(p1, float(k) / n) + off
			_strut(pa + Vector3(0, -0.35, 0), pa + Vector3(0, -depth, 0), 0.09, "bronze")
	# Cross ties under the deck.
	var n2 := maxi(2, int(length / 1.5))
	for k in n2 + 1:
		var pc := p0.lerp(p1, float(k) / n2)
		b.box("box", "bronze", pc + Vector3(0, -depth, 0), Vector3(0.1, 0.1, w - 0.3) if dir.x != 0 else Vector3(w - 0.3, 0.1, 0.1))
	# A few chains hanging into the abyss from long spans.
	if length > 3.5 and not iron:
		for k in 2:
			var pc := p0.lerp(p1, 0.3 + 0.4 * k) + cross * (w * 0.5 - 0.15) * (1.0 if k else -1.0)
			var ch := rng.randf_range(3.0, 7.0)
			b.box("box", "iron", pc + Vector3(0, -depth - ch * 0.5, 0), Vector3(0.05, ch, 0.05))


## Lower cross-ties between the two rooms' substructures under a connection:
## timber beams anchored in the slab aprons / pillars on both sides, with chains.
func _under_ties(link: Dictionary) -> void:
	var dir := Vector3(link.dir.x, 0, link.dir.y)
	var cross := Vector3(-dir.z, 0, dir.x)
	var a: Vector3 = link.p0 - dir * 0.6
	var c: Vector3 = link.p1 + dir * 0.6
	var low: float = min(a.y, c.y)
	for k in 2:
		var y := low - 5.0 - k * rng.randf_range(4.0, 7.0)
		var off: Vector3 = cross * rng.randf_range(-1.0, 1.0)
		_strut(Vector3(a.x, y, a.z) + off, Vector3(c.x, y, c.z) + off, 0.3, "wood_dark")
		_strut(Vector3(a.x, y - 0.4, a.z) + off, Vector3(c.x, y - 0.4, c.z) + off, 0.12, "bronze")
		var mid := (Vector3(a.x, y, a.z) + Vector3(c.x, y, c.z)) * 0.5 + off
		var ch := rng.randf_range(2.0, 5.0)
		b.box("box", "iron", mid + Vector3(0, -ch * 0.5, 0), Vector3(0.05, ch, 0.05))


func _strut(a: Vector3, c: Vector3, thick: float, mat: String) -> void:
	var d := c - a
	var length := d.length()
	if length < 0.01:
		return
	var y := d / length
	var x := y.cross(Vector3.UP if abs(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var basis := Basis(x * thick, y * length, z * thick)
	b.add("box", mat, Transform3D(basis, (a + c) * 0.5))


func _stairs(link: Dictionary) -> void:
	var dir := Vector3(link.dir.x, 0, link.dir.y)
	var cross := Vector3(-dir.z, 0, dir.x)
	var p0: Vector3 = link.p0
	var p1: Vector3 = link.p1
	var run := Vector2(p0.x, p0.z).distance_to(Vector2(p1.x, p1.z))
	var dy := p1.y - p0.y
	var n := maxi(2, int(ceil(abs(dy) / 0.19)))
	var w: float = link.width
	var yaw := -atan2(dir.z, dir.x)
	var low: float = min(p0.y, p1.y)
	for k in n:
		# Tread k spans [k, k+1]/n of the run at the height of its upper edge.
		var t0 := float(k) / n
		var t1 := float(k + 1) / n
		var y_top: float = p0.y + dy * ((k + 0.5) / n)
		var c0 := p0.lerp(p1, t0)
		var c1 := p0.lerp(p1, t1)
		var cc := (c0 + c1) * 0.5
		var hh: float = y_top - (low - 0.6)
		var x := -w * 0.5
		while x < w * 0.5 - 0.05:
			var l: float = min(rng.randf_range(0.5, 0.9), w * 0.5 - x)
			var pos := cc + cross * (x + l * 0.5)
			b.box("bbox", "stone", Vector3(pos.x, y_top - 0.09, pos.z), Vector3(run / n + 0.04, 0.18, l - 0.03), yaw, _tint(1.0, 0.3))
			x += l
		b.box("box", "stone_dark", Vector3(cc.x, y_top - 0.18 - (hh - 0.18) * 0.5, cc.z), Vector3(run / n + 0.02, hh - 0.18, w), yaw)
	# Side parapets (stepped blocks) and a supporting arch block below.
	for s in [-1.0, 1.0]:
		for k in n:
			var tm := (k + 0.5) / n
			var pc: Vector3 = p0.lerp(p1, tm) + cross * (w * 0.5 + 0.22) * s
			var yt: float = p0.y + dy * tm
			b.box("bbox", "stone", Vector3(pc.x, yt + 0.25, pc.z), Vector3(run / n + 0.03, 0.75, 0.42), yaw, _tint(0.9, 0.3))
	var mid := (p0 + p1) * 0.5
	b.box("box", "masonry", Vector3(mid.x, low - 0.6 - 2.0, mid.z), Vector3(run + 0.2, 4.0, w + 0.9), yaw)


# --- props, lights, backdrop -----------------------------------------------

## Clutter against the walls (barrels, crates, candles, rubble). Placement uses
## a fixed seed so the walk check and the game agree; returns [kind, pos, radius].
static func plan_clutter(solved_layout: Dictionary) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	var out := []
	var kinds := ["barrel", "crate", "candles", "rubble", "candles", "rubble", "sack"]
	for room in solved_layout.rooms.values():
		if room.shape != "rect" or min(room.rect.size.x, room.rect.size.y) < 5.0:
			continue
		var rect: Rect2 = room.rect
		var inset := Layout.WALL_T + 0.3
		var sides := {"n": [Vector2(rect.position.x, rect.position.y + inset), Vector2(1, 0), 0],
			"s": [Vector2(rect.position.x, rect.end.y - inset), Vector2(1, 0), 0],
			"w": [Vector2(rect.position.x + inset, rect.position.y), Vector2(0, 1), 1],
			"e": [Vector2(rect.end.x - inset, rect.position.y), Vector2(0, 1), 1]}
		for side in sides:
			if room.walls.get(side, 0.0) <= 0.0:
				continue
			var axis: int = sides[side][2]
			var length: float = rect.size[axis]
			var t := 2.4
			while t < length - 2.4:
				var p: Vector2 = sides[side][0] + sides[side][1] * t
				var near_open := false
				for o in room.openings[side]:
					if p[axis] > o.x - 1.4 and p[axis] < o.y + 1.4:
						near_open = true
				if not near_open and r.randf() < 0.5:
					var kind: String = kinds[r.randi() % kinds.size()]
					out.append([kind, Vector3(p.x, room.y, p.y), 0.4])
				t += r.randf_range(1.2, 2.4)
	return out


func _props() -> void:
	for c in plan_clutter(solved):
		match c[0]:
			"barrel": props.barrel(c[1])
			"crate": props.crate(c[1], rng.randf() * TAU)
			"candles": props.candle_cluster(c[1], rng.randi_range(2, 5), 0.25, rng.randf() < 0.35)
			"rubble": _rubble(c[1])
			"sack": props.sack(c[1])
	for room_name in Layout.PROPS:
		var room: Dictionary = solved.rooms[room_name]
		for entry in Layout.PROPS[room_name]:
			var kind: String = entry[0]
			var pos := Layout.prop_pos(room, entry[1], entry[2])
			props.build(kind, pos, entry[3], entry[4] if entry.size() > 4 else null)


func _rubble(p: Vector3) -> void:
	for k in rng.randi_range(3, 6):
		var s := rng.randf_range(0.18, 0.4)
		var q := p + Vector3(rng.randf_range(-0.35, 0.35), s * 0.4, rng.randf_range(-0.35, 0.35))
		var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.4, 0.4)) * Basis.from_scale(Vector3(s * 1.3, s * 0.8, s))
		b.add("bbox", "stone", Transform3D(basis, q), _tint(0.85, 0.3))


func _emit_lights(parent: Node3D) -> void:
	for l in lights:
		var o := OmniLight3D.new()
		o.position = l.pos
		o.light_color = l.color
		o.light_energy = l.energy
		o.omni_range = l.range
		o.omni_attenuation = 1.4
		o.shadow_enabled = false
		parent.add_child(o)


func _backdrop() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 99
	for k in 46:
		var a := r.randf_range(-PI * 0.95, -PI * 0.05)   # behind and to the sides
		var dist := r.randf_range(55.0, 120.0)
		var p := Vector2(cos(a) * dist * 1.2, sin(a) * dist * 0.8 - 10.0)
		var w := r.randf_range(5.0, 13.0)
		var top := r.randf_range(-30.0, 25.0)
		var bottom := -140.0
		b.box("box", "backdrop", Vector3(p.x, (top + bottom) * 0.5, p.y), Vector3(w, top - bottom, w * r.randf_range(0.7, 1.3)), r.randf() * 0.3, Color(1, 1, 1, 1.0 if r.randf() < 0.5 else 0.0))
		# Spire on some.
		if r.randf() < 0.5:
			b.box("cone", "backdrop", Vector3(p.x, top + w * 0.6, p.y), Vector3(w * 0.9, w * 1.2, w * 0.9), 0.0, Color(1, 1, 1, 0))
	# Near pillars rising from the abyss under and around the keep.
	for k in 40:
		var p := Vector2(r.randf_range(-45, 45), r.randf_range(-40, 25))
		var inside := false
		for room in solved.rooms.values():
			if room.rect.grow(3.0).has_point(p):
				inside = true
		if inside:
			continue
		var w := r.randf_range(2.5, 5.0)
		var top := r.randf_range(-25.0, -6.0)
		b.box("box", "backdrop", Vector3(p.x, (top - 140.0) * 0.5, p.y), Vector3(w, top + 140.0, w), 0.0, Color(1.3, 1.25, 1.2, 0.0))
