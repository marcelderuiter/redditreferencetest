class_name Kit
extends RefCounted
## Procedural building kit. Everything is collected into instance batches keyed
## by mesh + material, then turned into MultiMeshes by `build_into`.

const STONE := Color(0.37, 0.35, 0.33)
const STONE_DARK := Color(0.27, 0.26, 0.25)
const FLAG := Color(0.4, 0.375, 0.35)
const WOOD := Color(0.36, 0.22, 0.12)
const WOOD_DARK := Color(0.22, 0.14, 0.08)
const BRASS := Color(0.78, 0.52, 0.24)
const IRON := Color(0.22, 0.21, 0.2)
const GOLD := Color(1.0, 0.72, 0.3)
const WAX := Color(0.93, 0.84, 0.66)
const FLAME := Color(1.0, 0.55, 0.18)
const RED_CLOTH := Color(0.42, 0.12, 0.07)

var rng := RandomNumberGenerator.new()
var batches := {}
var lights: Array = []  # {pos, color, energy, range}
var walk: Array = []  # walk shapes, see Walk
var blockers: Array = []  # Vector3(x, z, radius)
## Translation applied to everything added (lets a room be moved as a unit).
var offset := Vector3.ZERO

func _init(seed_value: int) -> void:
	rng.seed = seed_value

func r(a: float, b: float) -> float:
	return rng.randf_range(a, b)

func chance(p: float) -> bool:
	return rng.randf() < p

func jit(c: Color, amount: float) -> Color:
	var k := r(1.0 - amount, 1.0 + amount)
	var w := r(-amount, amount) * 0.3
	return Color(c.r * k * (1.0 + w), c.g * k, c.b * k * (1.0 - w))

static func xform(pos: Vector3, size: Vector3, yaw := 0.0, pitch := 0.0, roll := 0.0) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(pitch, yaw, roll)) * Basis.from_scale(size), pos)

func put(mesh: String, mat: String, xf: Transform3D, col: Color) -> void:
	xf.origin += offset
	var key := mesh + "|" + mat
	if not batches.has(key):
		batches[key] = {"mesh": mesh, "mat": mat, "xf": [], "col": []}
	batches[key]["xf"].append(xf)
	batches[key]["col"].append(col)

func shape(mesh: String, mat: String, pos: Vector3, size: Vector3, col: Color, yaw := 0.0, pitch := 0.0, roll := 0.0) -> void:
	put(mesh, mat, xform(pos, size, yaw, pitch, roll), col)

func box(mat: String, pos: Vector3, size: Vector3, col: Color, yaw := 0.0, pitch := 0.0, roll := 0.0) -> void:
	put("box", mat, xform(pos, size, yaw, pitch, roll), col)

## Box spanning two corners (axis aligned).
func span(mat: String, a: Vector3, b: Vector3, col: Color) -> void:
	box(mat, (a + b) * 0.5, (b - a).abs(), col)

func cyl(mat: String, pos: Vector3, radius: float, height: float, col: Color, mesh := "cyl") -> void:
	put(mesh, mat, xform(pos, Vector3(radius * 2.0, height, radius * 2.0)), col)

## Beam (box) from a to b with a square section.
func beam(mat: String, a: Vector3, b: Vector3, w: float, h: float, col: Color, mesh := "box") -> void:
	var d := b - a
	var length := d.length()
	if length < 0.001:
		return
	var fwd := d / length
	var up := Vector3.UP if absf(fwd.y) < 0.95 else Vector3.RIGHT
	var x := up.cross(fwd).normalized()
	var y := fwd.cross(x).normalized()
	var basis := Basis(x * w, y * h, fwd * length)
	if mesh != "box":
		basis = Basis(x * w, fwd * length, -y * h)
	put(mesh, mat, Transform3D(basis, (a + b) * 0.5), col)

func light(pos: Vector3, energy := 1.6, rng_ := 4.0, col := Color(1.0, 0.7, 0.46)) -> void:
	lights.append({"pos": pos + offset, "color": col, "energy": energy, "range": rng_})

func add_walk(w: Walk) -> void:
	w.a += Vector2(offset.x, offset.z)
	w.b += Vector2(offset.x, offset.z)
	w.h0 += offset.y
	w.h1 += offset.y
	walk.append(w)

func add_block(x: float, z: float, radius: float) -> void:
	blockers.append(Vector3(x + offset.x, z + offset.z, radius))

# ---------------------------------------------------------------- masonry

## Irregular flagstone floor covering a rectangle with its top at y.
func flagstones(x0: float, z0: float, x1: float, z1: float, y: float, col := FLAG) -> void:
	box("brick", Vector3((x0 + x1) * 0.5, y - 0.12, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.1, z1 - z0), Color(0.1, 0.09, 0.08))
	var z := z0
	while z < z1 - 0.05:
		var rh := minf(r(0.35, 0.8), z1 - z)
		var x := x0 + r(-0.3, 0.0)
		while x < x1 - 0.05:
			var w := r(0.35, 0.95)
			var a := maxf(x, x0)
			var b := minf(x + w, x1)
			if b - a > 0.08:
				var gap := 0.06
				var c := jit(col, 0.22)
				if chance(0.12):
					c = c.darkened(0.3)
				elif chance(0.1):
					c = c.lightened(0.15)
				box("flag", Vector3((a + b) * 0.5, y - 0.06 + r(-0.012, 0.012), z + rh * 0.5),
					Vector3(b - a - gap, 0.12, rh - gap), c, r(-0.03, 0.03), r(-0.02, 0.02), r(-0.02, 0.02))
			x += w
		z += rh

## Masonry wall from p0 to p1 (xz), standing on base, with a ragged block top.
func wall(p0: Vector2, p1: Vector2, base: float, height: float, thick := 0.45, ragged := true, col := STONE) -> void:
	var d := p1 - p0
	var length := d.length()
	if length < 0.05:
		return
	var dir := d / length
	var yaw := atan2(-dir.y, dir.x)
	var core_h := height - (0.28 if ragged else 0.0)
	var mid := (p0 + p1) * 0.5
	box("brick", Vector3(mid.x, base + core_h * 0.5, mid.y), Vector3(length, core_h, thick), jit(col, 0.05), yaw)
	var nrm := Vector2(-dir.y, dir.x)
	# Proud blocks on both faces give the hand-carved relief.
	var count := int(length * maxf(core_h, 0.3) * 1.1)
	for i in count:
		var t := r(0.0, length)
		var bw := r(0.35, 0.62)
		t = clampf(t, bw * 0.5, length - bw * 0.5)
		var bh := r(0.2, 0.32)
		var y := base + r(0.05, maxf(core_h - bh * 0.5, 0.1))
		var side := 1.0 if chance(0.5) else -1.0
		var p := p0 + dir * t + nrm * side * (thick * 0.5 + r(-0.02, 0.035))
		box("stone", Vector3(p.x, y, p.y), Vector3(bw, bh, 0.12), jit(col, 0.15), yaw + r(-0.04, 0.04), 0.0, r(-0.03, 0.03))
	if ragged:
		var t := 0.0
		while t < length - 0.05:
			var bw := minf(r(0.32, 0.6), length - t)
			if not chance(0.12):
				var p := p0 + dir * (t + bw * 0.5)
				var bh := r(0.22, 0.32)
				box("stone", Vector3(p.x, base + core_h + bh * 0.5, p.y), Vector3(bw - 0.03, bh, thick + r(-0.04, 0.06)), jit(col, 0.16), yaw + r(-0.05, 0.05), r(-0.04, 0.04), r(-0.04, 0.04))
				if chance(0.3):
					var bh2 := r(0.18, 0.28)
					box("stone", Vector3(p.x, base + core_h + bh + bh2 * 0.5, p.y), Vector3(bw * r(0.5, 0.9), bh2, thick * r(0.6, 1.0)), jit(col, 0.16), yaw + r(-0.12, 0.12))
			t += bw

## Square tower / buttress block with a stepped cap.
func tower(x: float, z: float, base: float, top: float, w: float, col := STONE) -> void:
	box("brick", Vector3(x, (base + top) * 0.5, z), Vector3(w, top - base, w), jit(col, 0.06))
	box("stone", Vector3(x, top + 0.08, z), Vector3(w + 0.16, 0.16, w + 0.16), jit(col, 0.1))
	for i in 4:
		var a := i * PI * 0.5 + PI * 0.25
		var o := Vector2(cos(a), sin(a)) * w * 0.42
		box("stone", Vector3(x + o.x, top + 0.3, z + o.y), Vector3(w * 0.32, 0.28, w * 0.32), jit(col, 0.15), r(-0.1, 0.1))

## Masonry pier from top down into the abyss, with a corbelled capital.
func pier(x: float, z: float, top: float, w: float, bottom := -60.0, col := Color(0.2, 0.19, 0.19)) -> void:
	box("brick", Vector3(x, (top + bottom) * 0.5, z), Vector3(w, top - bottom, w), jit(col, 0.06))
	for k in 3:
		var s := w + 0.5 - k * 0.18
		box("stone", Vector3(x, top - 0.18 - k * 0.3, z), Vector3(s, 0.26, s), jit(col, 0.1))
	var y := top - 3.5
	while y > maxf(bottom, -26.0):
		box("stone", Vector3(x, y, z), Vector3(w + 0.14, 0.3, w + 0.14), jit(col, 0.1))
		y -= r(3.0, 5.0)

## Stone slab under a room floor: visible edge band of masonry.
func slab(x0: float, z0: float, x1: float, z1: float, y: float, depth := 1.0) -> void:
	box("brick", Vector3((x0 + x1) * 0.5, y - 0.1 - depth * 0.5, (z0 + z1) * 0.5), Vector3(x1 - x0, depth, z1 - z0), jit(STONE_DARK, 0.04))
	# corbel course under the edge
	box("stone", Vector3((x0 + x1) * 0.5, y - 0.1 - depth - 0.15, (z0 + z1) * 0.5), Vector3(x1 - x0 - 0.3, 0.3, z1 - z0 - 0.3), STONE_DARK.darkened(0.2))

## Stairs climbing from h0 to h1 between two xz corners along the given axis.
func stairs(x0: float, z0: float, x1: float, z1: float, h0: float, h1: float, along_x: bool, col := FLAG) -> void:
	var n := maxi(2, int(ceil(absf(h1 - h0) / 0.22)))
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var h := lerpf(h0, h1, (i + 0.5) / n)
		var top := lerpf(h0, h1, t1) if h1 > h0 else lerpf(h0, h1, t0)
		var low := minf(h0, h1) - 0.3
		if along_x:
			var a := lerpf(x0, x1, t0)
			var b := lerpf(x0, x1, t1)
			box("flag", Vector3((a + b) * 0.5, (top + low) * 0.5, (z0 + z1) * 0.5), Vector3(absf(b - a) + 0.02, top - low, z1 - z0 - 0.06), jit(col, 0.1))
		else:
			var a := lerpf(z0, z1, t0)
			var b := lerpf(z0, z1, t1)
			box("flag", Vector3((x0 + x1) * 0.5, (top + low) * 0.5, (a + b) * 0.5), Vector3(x1 - x0 - 0.06, top - low, absf(b - a) + 0.02), jit(col, 0.1))

	add_walk(Walk.ramp(x0, z0, x1, z1, h0, h1, along_x))

# ---------------------------------------------------------------- timber

## Timber bridge from a to b (deck top heights a.y, b.y), width w.
func bridge(a: Vector3, b: Vector3, w: float, rails := true, brass := true, trestle_bottom := -40.0) -> void:
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length := d.length()
	var fwd := d / length
	var side := Vector3(-fwd.z, 0.0, fwd.x)
	var yaw := atan2(-fwd.z, fwd.x)
	var slope := atan2(b.y - a.y, length)
	var n := int(length / 0.34)
	for i in n:
		var t := (i + 0.5) / n
		var p := a.lerp(b, t)
		box("wood", p + Vector3(0, -0.06, 0), Vector3(0.3, 0.1, w + r(-0.08, 0.08)), jit(WOOD, 0.2), yaw + r(-0.03, 0.03), 0.0, slope)
	for s in [-1.0, 1.0]:
		var o: Vector3 = side * (w * 0.5 + 0.05) * s
		beam("wood", a + o + Vector3(0, -0.2, 0), b + o + Vector3(0, -0.2, 0), 0.22, 0.3, jit(WOOD_DARK, 0.1))
		if brass:
			var k := 0.0
			while k <= length:
				var p := a.lerp(b, k / length) + o + Vector3(0, -0.2, 0)
				box("brass", p, Vector3(0.12, 0.34, 0.26), jit(BRASS, 0.1), yaw + PI * 0.5, 0.0, 0.0)
				k += 1.6
		if rails:
			var m := maxi(2, int(length / 1.4) + 1)
			for i in m:
				var p := a.lerp(b, float(i) / (m - 1)) + o
				box("wood", p + Vector3(0, 0.4, 0), Vector3(0.14, 0.8, 0.14), jit(WOOD_DARK, 0.15))
				if brass:
					box("brass", p + Vector3(0, 0.82, 0), Vector3(0.18, 0.06, 0.18), BRASS)
			beam("wood", a + o + Vector3(0, 0.78, 0), b + o + Vector3(0, 0.78, 0), 0.1, 0.1, jit(WOOD, 0.1))
			beam("wood", a + o + Vector3(0, 0.42, 0), b + o + Vector3(0, 0.42, 0), 0.07, 0.07, jit(WOOD_DARK, 0.1))
	# Under-structure: cross beams and posts down into the dark.
	var k2 := 0.8
	while k2 < length - 0.4:
		var p := a.lerp(b, k2 / length)
		beam("wood", p - side * (w * 0.5 + 0.3) + Vector3(0, -0.45, 0), p + side * (w * 0.5 + 0.3) + Vector3(0, -0.45, 0), 0.2, 0.22, jit(WOOD_DARK, 0.1))
		k2 += 2.0
	if trestle_bottom > -100.0 and length > 3.0:
		var mid := a.lerp(b, 0.5)
		trestle(mid, side, w + 0.6, trestle_bottom)
	add_walk(Walk.seg(Vector2(a.x, a.z), Vector2(b.x, b.z), w, a.y, b.y))

## Timber tower of posts and braces going down from top.
func trestle(top: Vector3, side: Vector3, w: float, bottom: float) -> void:
	var fwd := Vector3(side.z, 0.0, -side.x)
	var posts := [side * w * 0.5 + fwd * 0.4, -side * w * 0.5 + fwd * 0.4, side * w * 0.5 - fwd * 0.4, -side * w * 0.5 - fwd * 0.4]
	for o in posts:
		var p: Vector3 = top + o
		box("wood", Vector3(p.x, (top.y - 0.4 + bottom) * 0.5, p.z), Vector3(0.24, top.y - 0.4 - bottom, 0.24), jit(WOOD_DARK, 0.1))
	var y := top.y - 0.8
	var flip := 1.0
	while y > bottom + 3.0:
		var y2 := y - 2.6
		beam("wood", top + side * w * 0.5 * flip + fwd * 0.45 + Vector3(0, y - top.y, 0), top - side * w * 0.5 * flip + fwd * 0.45 + Vector3(0, y2 - top.y, 0), 0.14, 0.18, jit(WOOD_DARK, 0.15))
		beam("wood", top + side * w * 0.5 + fwd * 0.45 + Vector3(0, y - top.y, 0), top - side * w * 0.5 + fwd * 0.45 + Vector3(0, y - top.y, 0), 0.16, 0.2, jit(WOOD_DARK, 0.15))
		box("brass", top + fwd * 0.45 + Vector3(0, y - top.y, 0), Vector3(0.3, 0.26, 0.3), jit(BRASS, 0.1))
		y = y2
		flip = -flip

func chain(a: Vector3, b: Vector3) -> void:
	var d := b - a
	var n := int(d.length() / 0.22)
	for i in n:
		var p := a.lerp(b, (i + 0.5) / n)
		var yaw := PI * 0.5 * (i % 2)
		put("torus", "iron", Transform3D(Basis.from_euler(Vector3(PI * 0.5, yaw, 0)) * Basis.from_scale(Vector3(0.14, 0.14, 0.22)), p), IRON)

## Loose pebbles and chips scattered over a floor rectangle.
func debris(x0: float, z0: float, x1: float, z1: float, y: float, n: int) -> void:
	for i in n:
		var s := r(0.05, 0.14)
		box("stone", Vector3(r(x0, x1), y + s * 0.3, r(z0, z1)), Vector3(s, s * 0.6, s * r(0.7, 1.3)), jit(STONE, 0.2), r(0, TAU), r(-0.4, 0.4), r(-0.4, 0.4))

# ---------------------------------------------------------------- props

func candle(pos: Vector3, h := 0.0, with_light := true, energy := 1.0) -> void:
	if h <= 0.0:
		h = r(0.18, 0.5)
	cyl("wax", pos + Vector3(0, h * 0.5, 0), r(0.045, 0.065), h, jit(WAX, 0.06))
	shape("sphere", "flame", pos + Vector3(0, h + 0.09, 0), Vector3(0.07, 0.18, 0.07), FLAME)
	shape("sphere", "flame", pos + Vector3(0, h + 0.07, 0), Vector3(0.035, 0.08, 0.035), Color(1.0, 0.9, 0.7))
	if with_light:
		light(pos + Vector3(0, h + 0.25, 0), 1.1 * energy, 3.2)

## Cluster of candles with one shared light.
func candles(pos: Vector3, count: int, radius := 0.2, energy := 1.0) -> void:
	for i in count:
		var a := r(0, TAU)
		var d := r(0.0, radius)
		candle(pos + Vector3(cos(a) * d, 0, sin(a) * d), 0.0, false)
	light(pos + Vector3(0, 0.55, 0), 1.4 * energy * sqrt(count), 3.6 + radius * 2.0)

func candelabra(pos: Vector3, energy := 1.0) -> void:
	cyl("iron", pos + Vector3(0, 0.05, 0), 0.13, 0.1, IRON)
	cyl("iron", pos + Vector3(0, 0.45, 0), 0.03, 0.8, IRON)
	box("iron", pos + Vector3(0, 0.82, 0), Vector3(0.5, 0.04, 0.04), IRON)
	for x in [-0.22, 0.0, 0.22]:
		candle(pos + Vector3(x, 0.84 + (0.08 if x == 0.0 else 0.0), 0), 0.16, false)
	light(pos + Vector3(0, 1.3, 0), 2.0 * energy, 4.5)

func carpet(x0: float, z0: float, x1: float, z1: float, y: float, col := RED_CLOTH) -> void:
	box("carpet", Vector3((x0 + x1) * 0.5, y + 0.015, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.03, z1 - z0), col)

func table(pos: Vector3, w: float, d: float, yaw := 0.0, h := 0.55) -> void:
	var b := Basis.from_euler(Vector3(0, yaw, 0))
	box("wood", pos + Vector3(0, h, 0), Vector3(w, 0.07, d), jit(WOOD, 0.1), yaw)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			box("wood", pos + b * Vector3(sx * (w * 0.5 - 0.08), h * 0.5, sz * (d * 0.5 - 0.08)), Vector3(0.08, h, 0.08), WOOD_DARK, yaw)
	add_block(pos.x, pos.z, maxf(w, d) * 0.5)

func chair(pos: Vector3, yaw: float) -> void:
	var b := Basis.from_euler(Vector3(0, yaw, 0))
	box("wood", pos + Vector3(0, 0.3, 0), Vector3(0.32, 0.05, 0.32), jit(WOOD, 0.1), yaw)
	box("wood", pos + b * Vector3(0, 0.55, -0.15), Vector3(0.32, 0.5, 0.05), jit(WOOD, 0.1), yaw)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			box("wood", pos + b * Vector3(sx * 0.13, 0.15, sz * 0.13), Vector3(0.05, 0.3, 0.05), WOOD_DARK, yaw)

func chest(pos: Vector3, yaw: float, open := false) -> void:
	var b := Basis.from_euler(Vector3(0, yaw, 0))
	box("wood", pos + Vector3(0, 0.2, 0), Vector3(0.7, 0.4, 0.45), jit(WOOD, 0.1), yaw)
	shape("cyl", "wood", pos + Vector3(0, 0.4, 0), Vector3(0.45, 0.7, 0.45), jit(WOOD, 0.1), yaw + PI * 0.5, 0.0, PI * 0.5)
	for x in [-0.25, 0.0, 0.25]:
		box("brass", pos + b * Vector3(x, 0.32, 0), Vector3(0.06, 0.5, 0.48), BRASS, yaw)
	if open:
		gold_pile(pos + Vector3(0, 0.38, 0), 0.25, 10)
	add_block(pos.x, pos.z, 0.4)

func barrel(pos: Vector3) -> void:
	cyl("wood", pos + Vector3(0, 0.3, 0), 0.22, 0.6, jit(WOOD, 0.12), "barrel")
	for y in [0.1, 0.5]:
		cyl("iron", pos + Vector3(0, y, 0), 0.235, 0.05, IRON)
	add_block(pos.x, pos.z, 0.25)

func crate(pos: Vector3, s := 0.45) -> void:
	box("wood", pos + Vector3(0, s * 0.5, 0), Vector3(s, s, s), jit(WOOD, 0.15), r(-0.3, 0.3))
	add_block(pos.x, pos.z, s * 0.6)

func gold_pile(pos: Vector3, radius: float, n: int) -> void:
	for i in n:
		var a := r(0, TAU)
		var d := sqrt(rng.randf()) * radius
		var h := (1.0 - d / radius) * radius * 0.6
		shape("cyl", "gold", pos + Vector3(cos(a) * d, h, sin(a) * d), Vector3(0.09, 0.025, 0.09), jit(GOLD, 0.1), 0.0, r(-0.5, 0.5), r(-0.5, 0.5))

func bookshelf(pos: Vector3, yaw: float, w := 1.2) -> void:
	var b := Basis.from_euler(Vector3(0, yaw, 0))
	box("wood", pos + Vector3(0, 0.8, 0), Vector3(w, 1.6, 0.35), WOOD_DARK, yaw)
	for k in 4:
		var y := 0.25 + k * 0.38
		var x := -w * 0.5 + 0.08
		while x < w * 0.5 - 0.1:
			var bw := r(0.05, 0.09)
			var bh := r(0.2, 0.3)
			var c := Color.from_hsv(r(0.0, 0.12), r(0.4, 0.7), r(0.25, 0.5))
			box("plain", pos + b * Vector3(x + bw * 0.5, y + bh * 0.5, 0.06), Vector3(bw, bh, 0.24), c, yaw)
			x += bw + 0.01
	add_block(pos.x, pos.z, w * 0.5)

func rubble(pos: Vector3, radius: float, n: int, col := STONE) -> void:
	for i in n:
		var a := r(0, TAU)
		var d := sqrt(rng.randf()) * radius
		var s := r(0.15, 0.35)
		box("stone", pos + Vector3(cos(a) * d, s * 0.3, sin(a) * d), Vector3(s * r(1.0, 1.6), s * 0.7, s), jit(col, 0.15), r(0, TAU), r(-0.3, 0.3), r(-0.3, 0.3))

## Painted miniature figure on a round base. Scale 1 is ~0.9 units tall.
func figure(pos: Vector3, yaw: float, s := 1.0, col := Color(0.45, 0.42, 0.38), mat := "paint", block := true) -> void:
	s *= 1.25
	var b := Basis.from_euler(Vector3(0, yaw, 0))
	var f := func(v: Vector3) -> Vector3: return pos + b * (v * s)
	cyl("iron", pos + Vector3(0, 0.04 * s, 0), 0.32 * s, 0.08 * s, Color(0.12, 0.11, 0.1))
	var trim := Color(0.7, 0.5, 0.25)
	var cape := jit(Color(0.35, 0.1, 0.07), 0.2) if mat == "paint" else col.darkened(0.1)
	# legs
	for sx in [-1.0, 1.0]:
		box(mat, f.call(Vector3(sx * 0.08, 0.24, 0)), Vector3(0.1, 0.32, 0.12) * s, col.darkened(0.2), yaw)
	# robe / torso
	shape("cone", mat, f.call(Vector3(0, 0.36, 0)), Vector3(0.36, 0.3, 0.3) * s, col.darkened(0.1), yaw)
	box(mat, f.call(Vector3(0, 0.58, 0)), Vector3(0.3, 0.32, 0.2) * s, col, yaw)
	box("brass" if mat == "paint" else mat, f.call(Vector3(0, 0.44, 0.0)), Vector3(0.32, 0.05, 0.22) * s, trim if mat == "paint" else col, yaw)
	# shoulders and head
	for sx in [-1.0, 1.0]:
		shape("sphere", mat, f.call(Vector3(sx * 0.18, 0.72, 0)), Vector3(0.15, 0.13, 0.15) * s, col.lightened(0.05))
		box(mat, f.call(Vector3(sx * 0.21, 0.56, 0.04)), Vector3(0.08, 0.26, 0.09) * s, col, yaw, 0.0, sx * 0.15)
	shape("sphere", mat, f.call(Vector3(0, 0.86, 0)), Vector3(0.15, 0.17, 0.15) * s, col.lightened(0.08))
	shape("cone", mat, f.call(Vector3(0, 0.95, 0)), Vector3(0.17, 0.12, 0.17) * s, col.darkened(0.05))
	# cape
	box(mat, f.call(Vector3(0, 0.48, -0.13)), Vector3(0.3, 0.6, 0.04) * s, cape, yaw, -0.12)
	# weapon and shield
	box("iron" if mat == "paint" else mat, f.call(Vector3(0.27, 0.62, 0.12)), Vector3(0.04, 0.75, 0.04) * s, Color(0.55, 0.53, 0.5) if mat == "paint" else col, yaw, 0.0, -0.1)
	shape("cyl", mat, f.call(Vector3(-0.26, 0.5, 0.06)), Vector3(0.28, 0.04, 0.28) * s, col.darkened(0.15), yaw, 0.0, PI * 0.5)
	if block:
		add_block(pos.x, pos.z, 0.35 * s)

func statue(pos: Vector3, yaw: float, s := 2.2) -> void:
	box("stone", pos + Vector3(0, 0.3, 0), Vector3(0.9, 0.6, 0.9) * s * 0.55, jit(STONE, 0.05), yaw)
	box("stone", pos + Vector3(0, 0.66, 0), Vector3(0.75, 0.12, 0.75) * s * 0.55, jit(STONE, 0.05), yaw)
	figure(pos + Vector3(0, 0.66 + 0.06 * s * 0.55, 0), yaw, s, Color(0.55, 0.52, 0.48), "stone", false)
	add_block(pos.x, pos.z, 0.3 * s)

## Ruined arched window or door frame in a wall plane (yaw rotates it).
func arch(pos: Vector3, yaw: float, w: float, h: float, glow_col := Color(0, 0, 0), col := STONE) -> void:
	var b := Basis.from_euler(Vector3(0, yaw, 0))
	if glow_col.r > 0.0:
		box("glow", pos + b * Vector3(0, h * 0.45, 0.0), Vector3(w * 0.8, h * 0.85, 0.06), glow_col, yaw)
	else:
		box("plain", pos + b * Vector3(0, h * 0.45, 0.0), Vector3(w * 0.8, h * 0.85, 0.06), Color(0.04, 0.035, 0.03), yaw)
	for sx in [-1.0, 1.0]:
		box("stone", pos + b * Vector3(sx * w * 0.45, h * 0.35, 0.05), Vector3(w * 0.14, h * 0.7, 0.14), jit(col, 0.1), yaw)
		box("stone", pos + b * Vector3(sx * w * 0.22, h * 0.82, 0.05), Vector3(w * 0.5, 0.12, 0.14), jit(col, 0.1), yaw, 0.0, -sx * 0.7)

# ---------------------------------------------------------------- output

func build_into(parent: Node3D, meshes: Dictionary, materials: Dictionary, shadows := true) -> void:
	for key in batches:
		var bt: Dictionary = batches[key]
		var xfs: Array = bt["xf"]
		var cols: Array = bt["col"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = meshes[bt["mesh"]]
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
			mm.set_instance_color(i, cols[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = materials[bt["mat"]]
		mi.name = key.replace("|", "_")
		var no_shadow: bool = bt["mat"] == "flame" or bt["mat"] == "glow" or not shadows
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if no_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		parent.add_child(mi)
