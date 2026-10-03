class_name Kit
extends RefCounted
## Instanced geometry: every block, plank, coin and candle is one instance of
## a shared unit mesh inside a MultiMesh batch keyed by (mesh, material), so
## the scene can be built from tens of thousands of real pieces.

class Batch:
	var mesh := ""
	var mat := ""
	var under := false
	var count := 0
	var data := PackedFloat32Array()

	func push(xf: Transform3D, c: Color, u: Color) -> void:
		var b := xf.basis
		var o := xf.origin
		data.append_array([b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z,
			c.r, c.g, c.b, c.a, u.r, u.g, u.b, u.a])
		count += 1


const NO_SHADOW := ["flame", "glow", "ember", "window_glow", "backdrop"]
## Invisible geometry that only casts shadows (light blockers).
const SHADOW_ONLY := ["occluder"]
## Render layer bit of the pieces below the floors (piers, shaft walls, legs):
## the sun never reaches them, so World lights them with their own key.
## "stone_dark" is the masonry in the shade (back piers under the rooms,
## recessed panels): it stays off the key and reads as depth.
const UNDER_LAYER := 4
const UNDER_Y := -2.4
const NOT_UNDER := ["backdrop", "occluder", "flame", "glow", "ember", "window_glow", "void", "stone_dark"]
## Render layer bit of the distant backdrop masonry (lit by World's abyss light).
const BACKDROP_LAYER := 2
## Metric chamfer (m) of the bevelled meshes, by material. The stone and metal
## shaders rebuild the bevel at this size whatever the piece's scale (the unit
## mesh's chamfer would stretch with it), varying it per corner so blocks read
## as worn and chipped rather than machined.
const STONE_CHAMFER := {"block": 0.085, "slab": 0.045}
const CHAMFER := {"stone": STONE_CHAMFER, "stone_dark": STONE_CHAMFER, "floor": STONE_CHAMFER,
	"bronze": {"block": 0.025}, "bronze_dark": {"block": 0.025}, "gilt": {"block": 0.02}}
## Rubbed, bright edges on the bevelled pieces of the orrery's metals.
const EDGE_WEAR := {"bronze": 0.9, "bronze_dark": 0.7, "gilt": 0.5}

## The random stream of whatever is being built (see stream()).
var rng := RandomNumberGenerator.new()
## The level seed every item's stream is derived from.
var seed := 0
var meshes := {}
var materials := {}
var batches := {}
var lights: Array[Dictionary] = []


func _init(level_seed: int) -> void:
	seed = level_seed
	rng.seed = level_seed
	meshes.block = bevel_box(0.09)
	meshes.slab = bevel_box(0.05)
	meshes.plank = bevel_box(0.12)
	meshes.box = bevel_box(0.0)
	meshes.cyl = _cyl(16, 0.5, 0.5)
	meshes.cyl8 = _cyl(8, 0.5, 0.5)
	meshes.cone = _cyl(12, 0.0, 0.5)
	meshes.spire = _cyl(4, 0.0, 0.7)
	meshes.sphere = _sphere(12, 8)
	meshes.ring = _torus(20, 6, 0.42, 0.5)
	meshes.ring48 = _torus(48, 8, 0.47, 0.5)
	meshes.disc = _cyl(48, 0.5, 0.5)
	meshes.link = _torus(8, 4, 0.3, 0.5)
	meshes.flame = _sphere(8, 6)
	for m in ["stone", "stone_dark", "floor", "wood", "wood_dark", "iron", "brass", "gold", "bronze", "bronze_dark", "gilt", "cloth",
			"wax", "statue", "flame", "glow", "ember", "window_glow", "paper", "backdrop", "void", "occluder"]:
		materials[m] = _material(m)


func add(mesh: String, mat: String, xf: Transform3D, color := Color.WHITE, custom := Color(0, 0, 0, 0)) -> void:
	if custom.a == 0.0:
		custom = Color(rng.randf(), rng.randf(), rng.randf(), 1.0)
	var key := mesh + "|" + mat
	var under := xf.origin.y < UNDER_Y and not NOT_UNDER.has(mat)
	if under:
		key += "|under"
	var b: Batch = batches.get(key)
	if b == null:
		b = Batch.new()
		b.mesh = mesh
		b.mat = mat
		b.under = under
		batches[key] = b
	b.push(xf, color, custom)


## A unit mesh scaled to `size`, rotated by `basis`, centred at `center`.
func piece(mesh: String, mat: String, center: Vector3, size: Vector3, basis := Basis.IDENTITY, color := Color.WHITE) -> void:
	add(mesh, mat, Transform3D(basis * Basis.from_scale(size), center), color)


## Axis-aligned piece with a yaw (degrees).
func put(mesh: String, mat: String, center: Vector3, size: Vector3, yaw_deg := 0.0, color := Color.WHITE) -> void:
	piece(mesh, mat, center, size, Basis(Vector3.UP, deg_to_rad(yaw_deg)), color)


## Mesh stretched between two points (beams, chains, posts).
func span(mesh: String, mat: String, a: Vector3, b: Vector3, thick: Vector2, color := Color.WHITE, roll := 0.0) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.001:
		return
	var y := d / length
	var ref := Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var z := x.cross(y)
	var basis := Basis(x, y, z) * Basis(Vector3.UP, roll)
	piece(mesh, mat, (a + b) * 0.5, Vector3(thick.x, length, thick.y), basis, color)


## Runs `build` on its own random stream, seeded from the level seed and a
## stable key ("room:hall:wall:n", "link:bridge:hall-orrery", ...): an item's
## random detail depends only on the seed and its key, never on what was
## built before it or how much randomness that took. Streams nest; the outer
## one carries on where it left off.
func stream(key: String, build: Callable) -> void:
	var outer := rng
	rng = stream_rng(key)
	build.call()
	rng = outer


## A generator of its own for `key`, for code that draws from it directly.
func stream_rng(key: String) -> RandomNumberGenerator:
	var g := RandomNumberGenerator.new()
	g.seed = hash([seed, key])
	return g


func jitter(amount: float) -> float:
	return rng.randf_range(-amount, amount)


## Random tint around a base colour (value and slight warmth variation).
func tint(base: Color, value := 0.12, warm := 0.03) -> Color:
	var v := 1.0 + jitter(value)
	var w := jitter(warm)
	return Color(base.r * v * (1.0 + w), base.g * v, base.b * v * (1.0 - w), 1.0)


## falloff is the omni distance decay exponent (2 = inverse square: tight pools).
func light(pos: Vector3, color: Color, energy: float, range_m: float, shadow := false, flicker := 1.0, falloff := 1.6) -> void:
	if color == Props.CANDLE_LIGHT:
		energy *= World.tune("candle", 1.44)
	lights.append({"pos": pos, "color": color, "energy": energy, "range": range_m, "shadow": shadow, "flicker": flicker, "falloff": falloff})


func flush(parent: Node3D) -> int:
	var total := 0
	for key in batches:
		var b: Batch = batches[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = meshes[b.mesh]
		mm.instance_count = b.count
		mm.buffer = b.data
		var mmi := MultiMeshInstance3D.new()
		mmi.name = key.replace("|", "_")
		mmi.multimesh = mm
		mmi.material_override = _batch_material(b)
		if NO_SHADOW.has(b.mat):
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif SHADOW_ONLY.has(b.mat):
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		if b.mat == "backdrop":
			mmi.layers = BACKDROP_LAYER
		elif b.under:
			mmi.layers = UNDER_LAYER
		parent.add_child(mmi)
		total += b.count
	batches.clear()
	return total


## The batch's material; bevelled stone and orrery metal get a copy with a
## metric chamfer (and the metal rubbed edges).
func _batch_material(b: Batch) -> Material:
	if not (CHAMFER.has(b.mat) and CHAMFER[b.mat].has(b.mesh)):
		return materials[b.mat]
	var key := b.mat + "@" + b.mesh
	if not materials.has(key):
		var m: ShaderMaterial = materials[b.mat].duplicate()
		m.set_shader_parameter("chamfer", CHAMFER[b.mat][b.mesh])
		if EDGE_WEAR.has(b.mat):
			m.set_shader_parameter("edge_wear", EDGE_WEAR[b.mat])
		materials[key] = m
	return materials[key]


# ------------------------------------------------------------------ meshes

## Unit cube with chamfered edges and corners (flat-shaded facets), so every
## block edge catches the light. b = chamfer size (0 gives a plain cube).
static func bevel_box(b: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 0.5 - b
	for axis in 3:
		for s in [-1.0, 1.0]:
			var a1 := (axis + 1) % 3
			var a2 := (axis + 2) % 3
			var q: Array[Vector3] = []
			for uv in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var p := Vector3.ZERO
				p[axis] = s * 0.5
				p[a1] = uv.x * h
				p[a2] = uv.y * h
				q.append(p)
			var n := Vector3.ZERO
			n[axis] = s
			_quad(st, q, n)
	if b > 0.0:
		for a in 3:
			for c in range(a + 1, 3):
				var d := 3 - a - c
				for sa in [-1.0, 1.0]:
					for sc in [-1.0, 1.0]:
						var q: Array[Vector3] = []
						for sd in [-1.0, 1.0]:
							var p := Vector3.ZERO
							p[a] = sa * 0.5
							p[c] = sc * h
							p[d] = sd * h
							q.append(p)
						for sd in [1.0, -1.0]:
							var p := Vector3.ZERO
							p[a] = sa * h
							p[c] = sc * 0.5
							p[d] = sd * h
							q.append(p)
						var n := Vector3.ZERO
						n[a] = sa
						n[c] = sc
						_quad(st, q, n.normalized())
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var t: Array[Vector3] = [Vector3(sx * 0.5, sy * h, sz * h), Vector3(sx * h, sy * 0.5, sz * h), Vector3(sx * h, sy * h, sz * 0.5)]
					_tri(st, t[0], t[1], t[2], Vector3(sx, sy, sz).normalized())
	return st.commit()


## Godot treats clockwise triangles as front faces; order each triangle so
## its face points along n.
static func _tri(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, n: Vector3) -> void:
	if (p1 - p0).cross(p2 - p0).dot(n) > 0.0:
		var t := p1
		p1 = p2
		p2 = t
	for p in [p0, p1, p2]:
		st.set_normal(n)
		st.set_uv(Vector2(p.x + 0.5, p.z + 0.5))
		st.add_vertex(p)


static func _quad(st: SurfaceTool, q: Array[Vector3], n: Vector3) -> void:
	_tri(st, q[0], q[1], q[2], n)
	_tri(st, q[0], q[2], q[3], n)


## Unit-height cylinder (or cone when r_top = 0), centred, radius 0.5.
static func _cyl(sides: int, r_top: float, r_bottom: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var t0 := d0 * r_top + Vector3(0, 0.5, 0)
		var t1 := d1 * r_top + Vector3(0, 0.5, 0)
		var b0 := d0 * r_bottom - Vector3(0, 0.5, 0)
		var b1 := d1 * r_bottom - Vector3(0, 0.5, 0)
		var slope := (r_bottom - r_top)
		var n0 := (d0 + Vector3(0, slope, 0)).normalized()
		var n1 := (d1 + Vector3(0, slope, 0)).normalized()
		_smooth_tri(st, [b0, b1, t1], [n0, n1, n1])
		if r_top > 0.0:
			_smooth_tri(st, [b0, t1, t0], [n0, n1, n0])
			_tri(st, Vector3(0, 0.5, 0), t0, t1, Vector3.UP)
		_tri(st, Vector3(0, -0.5, 0), b0, b1, Vector3.DOWN)
	return st.commit()


static func _smooth_tri(st: SurfaceTool, p: Array, n: Array) -> void:
	var face: Vector3 = (n[0] + n[1] + n[2]).normalized()
	var order := [0, 1, 2]
	if (p[1] - p[0]).cross(p[2] - p[0]).dot(face) > 0.0:
		order = [0, 2, 1]
	for i in order:
		st.set_normal(n[i])
		st.set_uv(Vector2(p[i].x + 0.5, p[i].z + 0.5))
		st.add_vertex(p[i])


static func _sphere(seg: int, rings: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rings:
		var v0 := PI * r / rings
		var v1 := PI * (r + 1) / rings
		for s in seg:
			var u0 := TAU * s / seg
			var u1 := TAU * (s + 1) / seg
			var p := [_sph(u0, v0), _sph(u1, v0), _sph(u1, v1), _sph(u0, v1)]
			_smooth_tri(st, [p[0] * 0.5, p[1] * 0.5, p[2] * 0.5], [p[0], p[1], p[2]])
			_smooth_tri(st, [p[0] * 0.5, p[2] * 0.5, p[3] * 0.5], [p[0], p[2], p[3]])
	return st.commit()


static func _sph(u: float, v: float) -> Vector3:
	return Vector3(sin(v) * cos(u), cos(v), sin(v) * sin(u))


## Torus in the XZ plane, outer radius 0.5.
static func _torus(seg: int, sides: int, r_in: float, r_out: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rc := (r_in + r_out) * 0.5
	var rt := (r_out - r_in) * 0.5
	for i in seg:
		for j in sides:
			var pts := []
			var nrm := []
			for k in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				var u: float = TAU * k[0] / seg
				var v: float = TAU * k[1] / sides
				var c := Vector3(cos(u), 0, sin(u))
				var n := c * cos(v) + Vector3(0, sin(v), 0)
				pts.append(c * rc + n * rt)
				nrm.append(n)
			_smooth_tri(st, [pts[0], pts[1], pts[2]], [nrm[0], nrm[1], nrm[2]])
			_smooth_tri(st, [pts[0], pts[2], pts[3]], [nrm[0], nrm[2], nrm[3]])
	return st.commit()


# --------------------------------------------------------------- materials

func _material(kind: String) -> Material:
	var m := ShaderMaterial.new()
	match kind:
		"stone", "stone_dark", "floor", "backdrop":
			m.shader = load("res://shaders/stone.gdshader")
			m.set_shader_parameter("sun_dir", World.SUN_DIR.normalized())
			m.set_shader_parameter("under_key_dir", World.PIER_KEY_DIR.normalized())
			m.set_shader_parameter("bump", World.tune("bump", 1))
			m.set_shader_parameter("detail", World.tune("detail", 1))
			if kind == "stone_dark":
				m.set_shader_parameter("base_color", Color(0.30, 0.27, 0.25))
			elif kind == "floor":
				m.set_shader_parameter("base_color", Color(0.46, 0.41, 0.36))
				m.set_shader_parameter("wear", 0.6)
			elif kind == "backdrop":
				m.set_shader_parameter("base_color", Color(0.2, 0.19, 0.2))
				m.set_shader_parameter("under_min", 1.0)
				m.set_shader_parameter("bump", 0.4)
				m.set_shader_parameter("detail", 0.25)
		"wood", "wood_dark":
			m.shader = load("res://shaders/wood.gdshader")
			if kind == "wood_dark":
				m.set_shader_parameter("base_color", Color(0.17, 0.11, 0.07))
		"iron", "brass", "gold", "statue", "bronze", "bronze_dark", "gilt":
			m.shader = load("res://shaders/metal.gdshader")
			var p: Array = {
				"iron": [Color(0.24, 0.23, 0.22), 0.5, 0.45, 0.0],
				"brass": [Color(0.52, 0.39, 0.25), 0.42, 0.8, 0.0],
				"gold": [Color(0.84, 0.64, 0.34), 0.38, 0.7, 0.0],
				"statue": [Color(0.36, 0.34, 0.32), 0.42, 0.35, 0.0],
				# The orrery: dark bronze body, mid bronze plates, gilt rims and spokes.
				"bronze_dark": [Color(0.2, 0.175, 0.15), 0.62, 0.8, 0.0],
				"bronze": [Color(0.36, 0.31, 0.25), 0.55, 0.85, 0.0],
				"gilt": [Color(0.8, 0.67, 0.48), 0.25, 0.95, 0.0],
			}[kind]
			m.set_shader_parameter("base_color", p[0])
			m.set_shader_parameter("roughness_v", p[1])
			m.set_shader_parameter("metal", p[2])
			m.set_shader_parameter("self_lit", p[3])
		"cloth":
			m.shader = load("res://shaders/cloth.gdshader")
		"void", "occluder":
			m.shader = load("res://shaders/void.gdshader")
		"wax", "paper":
			m.shader = load("res://shaders/wax.gdshader")
			if kind == "paper":
				m.set_shader_parameter("base_color", Color(0.62, 0.52, 0.38))
				m.set_shader_parameter("glow", 0.0)
		"flame":
			m.shader = load("res://shaders/flame.gdshader")
		"glow", "ember", "window_glow":
			m.shader = load("res://shaders/glow.gdshader")
			if kind == "ember":
				m.set_shader_parameter("core", Color(1.0, 0.3, 0.05))
				m.set_shader_parameter("strength", 3.0)
			elif kind == "window_glow":
				m.set_shader_parameter("core", Color(1.0, 0.5, 0.16))
				m.set_shader_parameter("strength", 1.1)
	return m
