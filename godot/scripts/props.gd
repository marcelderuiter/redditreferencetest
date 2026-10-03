class_name Props
extends RefCounted
## Props built from primitives. Each adds instances to a Batch and light
## requests ({pos, color, energy, range}) to `lights`.

const FOOTPRINT := {
	"candelabra": 0.35, "knight": 0.6, "candles": 0.3, "desk": 1.0, "bookcase": 0.7, "hearth": 1.3,
	"anvil": 0.5, "table": 0.9, "barrel": 0.45, "crate": 0.5, "statue_big": 1.0, "statue_small": 0.5,
	"shrine_statue": 1.3, "altar": 1.1, "orrery": 1.9, "gold": 0.7, "chest": 0.6, "winch": 0.4,
}

const CANDLE_LIGHT := Color(1.0, 0.66, 0.2)

var b: Batch
var lights: Array
var rng: RandomNumberGenerator


func _init(batch: Batch, light_list: Array, random: RandomNumberGenerator) -> void:
	b = batch
	lights = light_list
	rng = random


func build(kind: String, pos: Vector3, yaw_deg: float, extra = null) -> void:
	var yaw := deg_to_rad(yaw_deg)
	match kind:
		"candelabra": candelabra(pos)
		"knight": knight(pos, yaw)
		"candles": candle_cluster(pos, rng.randi_range(3, 6), 0.35, true)
		"banner": pass
		"desk": desk(pos, yaw)
		"carpet": carpet(pos, yaw, extra)
		"bookcase": bookcase(pos, yaw)
		"hearth": hearth(pos)
		"anvil": anvil(pos, yaw)
		"table": desk(pos, yaw)
		"barrel": barrel(pos)
		"crate": crate(pos, yaw)
		"statue_big": statue_big(pos, yaw)
		"statue_small": knight(pos, yaw, 0.75)
		"shrine_statue": shrine_statue(pos)
		"altar": altar(pos)
		"orrery": orrery(pos)
		"gold": gold(pos)
		"chest": chest(pos, yaw)
		"winch": winch(pos)
		_: push_error("unknown prop " + kind)


func _xf(origin: Vector3, yaw: float, local: Vector3) -> Vector3:
	return origin + Basis(Vector3.UP, yaw) * local


func light(pos: Vector3, energy := 1.0, rng_ := 3.6, color := CANDLE_LIGHT) -> void:
	lights.append({"pos": pos, "color": color, "energy": energy, "range": rng_})


## One candle: wax cylinder + flame. Height h.
func candle(p: Vector3, h := 0.25, r := 0.045) -> void:
	b.box("cyl8", "wax", p + Vector3(0, h * 0.5, 0), Vector3(r * 2, h, r * 2), 0.0, Color(1, 1, 1).darkened(rng.randf() * 0.15))
	var fh := r * 3.2
	b.add("flame", "flame", Transform3D(Basis.from_scale(Vector3(r * 2.2, fh, r * 2.2)), p + Vector3(0, h + 0.01, 0)))


func candle_cluster(p: Vector3, n: int, spread: float, with_light: bool) -> void:
	for i in n:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * spread
		candle(p + Vector3(cos(a) * d, 0, sin(a) * d), rng.randf_range(0.12, 0.38), rng.randf_range(0.035, 0.06))
	if with_light:
		light(p + Vector3(0, 0.6, 0), 2.6, 5.0)


func candelabra(p: Vector3) -> void:
	# Stone pedestal with an iron candle stand on top.
	b.box("bbox", "stone", p + Vector3(0, 0.12, 0), Vector3(0.6, 0.24, 0.6), 0.0, Color(0.9, 0.88, 0.85))
	b.box("bbox", "stone", p + Vector3(0, 0.7, 0), Vector3(0.36, 0.95, 0.36), 0.0, Color(0.95, 0.92, 0.88))
	b.box("bbox", "stone", p + Vector3(0, 1.22, 0), Vector3(0.5, 0.12, 0.5))
	b.box("cyl8", "bronze", p + Vector3(0, 1.32, 0), Vector3(0.36, 0.06, 0.36))
	candle_cluster(p + Vector3(0, 1.35, 0), 3, 0.11, false)
	light(p + Vector3(0, 1.9, 0), 3.2, 6.0)


func knight(p: Vector3, yaw: float, s := 1.0) -> void:
	var tint := Color(1, 1, 1).darkened(rng.randf() * 0.2)
	b.box("cyl", "stone_dark", p + Vector3(0, 0.1 * s, 0), Vector3(1.0, 0.2, 1.0) * s)
	b.box("cyl", "bronze", p + Vector3(0, 0.205 * s, 0), Vector3(0.92, 0.03, 0.92) * s)
	var m := "pewter"
	for side in [-1.0, 1.0]:
		b.box("bbox", m, _xf(p, yaw, Vector3(0.12 * side, 0.55, 0) * s), Vector3(0.16, 0.65, 0.2) * s, yaw, tint)
		b.box("sphere", m, _xf(p, yaw, Vector3(0.27 * side, 1.25, 0) * s), Vector3(0.24, 0.22, 0.24) * s, yaw, tint)
	b.box("bbox", m, _xf(p, yaw, Vector3(0, 1.05, 0) * s), Vector3(0.46, 0.55, 0.3) * s, yaw, tint)
	b.box("cyl", m, _xf(p, yaw, Vector3(0, 0.82, 0) * s), Vector3(0.52, 0.18, 0.36) * s, yaw, tint)
	b.box("sphere", m, _xf(p, yaw, Vector3(0, 1.5, 0) * s), Vector3(0.26, 0.3, 0.26) * s, yaw, tint)
	b.box("cyl", "bronze", _xf(p, yaw, Vector3(0, 1.6, 0) * s), Vector3(0.12, 0.12, 0.12) * s, yaw)
	# Shield on the left arm, sword or spear on the right.
	var sb := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(0.5, 0.06, 0.62) * s)
	b.add("cyl", "bronze", Transform3D(sb, _xf(p, yaw, Vector3(-0.36, 1.0, -0.12) * s)))
	if rng.randf() < 0.5:
		b.box("box", "iron", _xf(p, yaw, Vector3(0.38, 1.05, -0.1) * s), Vector3(0.05, 1.9, 0.05) * s, yaw)
		b.box("bbox", "bronze", _xf(p, yaw, Vector3(0.38, 2.05, -0.1) * s), Vector3(0.1, 0.22, 0.04) * s, yaw)
	else:
		b.box("box", "iron", _xf(p, yaw, Vector3(0.36, 1.0, -0.2) * s), Vector3(0.07, 0.85, 0.03) * s, yaw)
		b.box("box", "bronze", _xf(p, yaw, Vector3(0.36, 1.45, -0.2) * s), Vector3(0.24, 0.04, 0.06) * s, yaw)


func statue_big(p: Vector3, yaw: float) -> void:
	b.box("bbox", "stone", p + Vector3(0, 0.3, 0), Vector3(1.6, 0.6, 1.6), yaw, Color(0.85, 0.82, 0.78))
	b.box("bbox", "stone", p + Vector3(0, 0.7, 0), Vector3(1.3, 0.2, 1.3), yaw)
	var m := "marble"
	b.box("cone", m, p + Vector3(0, 1.75, 0), Vector3(1.1, 1.9, 1.0), yaw)
	b.box("bbox", m, _xf(p, yaw, Vector3(0, 2.6, 0)), Vector3(0.75, 0.5, 0.45), yaw)
	b.box("sphere", m, p + Vector3(0, 3.05, 0), Vector3(0.38, 0.44, 0.38))
	b.box("cone", m, p + Vector3(0, 3.35, 0), Vector3(0.36, 0.3, 0.36))
	b.box("box", "iron", _xf(p, yaw, Vector3(0, 2.0, -0.35)), Vector3(0.08, 2.4, 0.06), yaw)
	b.box("box", "bronze", _xf(p, yaw, Vector3(0, 2.6, -0.35)), Vector3(0.5, 0.06, 0.08), yaw)
	for k in 6:
		var a := float(k) / 6.0 * TAU
		candle(p + Vector3(cos(a) * 0.95, 0.6, sin(a) * 0.95), rng.randf_range(0.15, 0.3), 0.05)
	light(p + Vector3(0, 1.4, 1.2), 2.2, 5.0)


func shrine_statue(p: Vector3) -> void:
	# Tall gothic alcove against the north wall with a robed figure inside.
	var back := p + Vector3(0, 0, -0.9)
	b.box("bbox", "stone", back + Vector3(0, 0.3, 0.6), Vector3(3.0, 0.6, 1.6), 0.0, Color(0.9, 0.86, 0.8))
	for side in [-1.0, 1.0]:
		b.box("bbox", "stone", back + Vector3(side * 1.55, 2.6, 0.2), Vector3(0.5, 5.2, 0.6))
		b.box("cone", "stone", back + Vector3(side * 1.55, 5.55, 0.2), Vector3(0.45, 0.8, 0.45))
	b.add("arch", "glow_dim", Transform3D(Basis.from_scale(Vector3(2.6, 4.6, 1)), back + Vector3(0, 0.6, -0.02)))
	b.add("arch", "stone", Transform3D(Basis.from_scale(Vector3(3.1, 5.3, 1)), back + Vector3(0, 0.3, -0.12)), Color(0.8, 0.75, 0.7))
	var m := "marble"
	var f := back + Vector3(0, 0.6, 0.55)
	b.box("cone", m, f + Vector3(0, 1.25, 0), Vector3(1.15, 2.5, 0.9))
	b.box("bbox", m, f + Vector3(0, 2.55, 0), Vector3(0.85, 0.55, 0.5))
	b.box("sphere", m, f + Vector3(0, 3.05, 0.02), Vector3(0.42, 0.5, 0.42))
	b.box("cone", m, f + Vector3(0, 3.0, -0.08), Vector3(0.62, 0.9, 0.5))
	for side in [-1.0, 1.0]:
		var ab := Basis(Vector3.FORWARD, side * 0.5) * Basis.from_scale(Vector3(0.2, 0.9, 0.2))
		b.add("cyl", m, Transform3D(ab, f + Vector3(side * 0.42, 2.25, 0.18)))
	for k in 8:
		candle(back + Vector3(-1.3 + k * 0.37, 0.6, 1.25), rng.randf_range(0.18, 0.45), 0.05)
	light(back + Vector3(0, 2.0, 2.0), 3.0, 7.0, Color(1.0, 0.62, 0.32))


func altar(p: Vector3) -> void:
	b.box("bbox", "stone", p + Vector3(0, 0.45, 0), Vector3(2.2, 0.9, 1.0), 0.0, Color(0.9, 0.85, 0.8))
	b.box("bbox", "stone", p + Vector3(0, 0.95, 0), Vector3(2.4, 0.1, 1.15))
	b.box("box", "cloth", p + Vector3(0, 0.6, 0.51), Vector3(1.2, 0.7, 0.03))
	for k in 9:
		candle(p + Vector3(-1.0 + k * 0.25, 1.0, rng.randf_range(-0.35, 0.35)), rng.randf_range(0.12, 0.4), 0.045)
	for side in [-1.0, 1.0]:
		candle_cluster(p + Vector3(side * 1.6, 0, 0.4), 4, 0.25, false)
	light(p + Vector3(0, 1.6, 0.8), 2.0, 5.0)


func desk(p: Vector3, yaw: float) -> void:
	b.box("bbox", "wood", _xf(p, yaw, Vector3(0, 0.8, 0)), Vector3(1.8, 0.1, 1.0), yaw, Color(1, 1, 1), Color(rng.randf(), 0, 0, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.box("box", "wood_dark", _xf(p, yaw, Vector3(sx * 0.78, 0.38, sz * 0.4)), Vector3(0.1, 0.76, 0.1), yaw)
	b.box("box", "parchment", _xf(p, yaw, Vector3(-0.3, 0.86, 0.1)), Vector3(0.5, 0.01, 0.35), yaw + 0.2)
	b.box("bbox", "wood_dark", _xf(p, yaw, Vector3(0.4, 0.95, -0.2)), Vector3(0.35, 0.2, 0.28), yaw)
	candle_cluster(_xf(p, yaw, Vector3(0.65, 0.85, 0.25)), 2, 0.08, true)


func carpet(p: Vector3, yaw: float, size) -> void:
	var s: Vector2 = size if size is Vector2 else Vector2(2, 3)
	b.box("box", "cloth", p + Vector3(0, 0.075, 0), Vector3(s.x, 0.02, s.y), yaw)


func bookcase(p: Vector3, yaw: float) -> void:
	b.box("bbox", "wood_dark", _xf(p, yaw, Vector3(0, 1.0, 0)), Vector3(1.6, 2.0, 0.45), yaw)
	for row in 4:
		var x := -0.68
		while x < 0.66:
			var w := rng.randf_range(0.06, 0.12)
			var h := rng.randf_range(0.28, 0.38)
			var c := Color.from_hsv(rng.randf_range(0.0, 0.12), rng.randf_range(0.4, 0.8), rng.randf_range(0.25, 0.6))
			b.box("box", "paint", _xf(p, yaw, Vector3(x + w * 0.5, 0.2 + row * 0.45 + h * 0.5, 0.12)), Vector3(w * 0.9, h, 0.3), yaw, c)
			x += w
	candle(_xf(p, yaw, Vector3(0.5, 2.0, 0.05)), 0.2, 0.04)


func hearth(p: Vector3) -> void:
	# Forge: stone hearth with a glowing fire bed and a hood.
	b.box("bbox", "stone", p + Vector3(0, 0.45, 0), Vector3(2.4, 0.9, 1.6), 0.0, Color(0.8, 0.72, 0.65))
	b.box("box", "glow_fire", p + Vector3(0, 0.92, 0.05), Vector3(1.7, 0.06, 1.1))
	for k in 7:
		var q := p + Vector3(rng.randf_range(-0.7, 0.7), 0.92, rng.randf_range(-0.4, 0.45))
		b.add("flame", "flame", Transform3D(Basis.from_scale(Vector3(0.35, rng.randf_range(0.5, 0.9), 0.35)), q))
	for side in [-1.0, 1.0]:
		b.box("bbox", "stone", p + Vector3(side * 1.1, 1.6, -0.55), Vector3(0.3, 1.5, 0.5))
	b.box("bbox", "stone", p + Vector3(0, 2.5, -0.55), Vector3(2.6, 0.5, 0.7), 0.0, Color(0.6, 0.5, 0.45))
	b.box("bbox", "stone", p + Vector3(0, 3.3, -0.65), Vector3(1.2, 1.2, 0.5), 0.0, Color(0.6, 0.5, 0.45))
	light(p + Vector3(0, 1.6, 0.8), 4.0, 8.0, Color(1.0, 0.52, 0.2))


func anvil(p: Vector3, yaw: float) -> void:
	b.box("cyl8", "wood_dark", p + Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 0.6))
	b.box("bbox", "iron", _xf(p, yaw, Vector3(0, 0.7, 0)), Vector3(0.8, 0.22, 0.3), yaw)
	b.box("cone", "iron", _xf(p, yaw, Vector3(0.48, 0.72, 0)), Vector3(0.18, 0.2, 0.18), yaw)


func barrel(p: Vector3) -> void:
	b.box("cyl", "wood", p + Vector3(0, 0.45, 0), Vector3(0.75, 0.9, 0.75), rng.randf() * TAU, Color(1, 1, 1), Color(rng.randf(), 0, 0, 0))
	for y in [0.15, 0.75]:
		b.box("cyl", "iron", p + Vector3(0, y, 0), Vector3(0.78, 0.05, 0.78))


func crate(p: Vector3, yaw: float) -> void:
	var s := rng.randf_range(0.6, 0.85)
	b.box("bbox", "wood", p + Vector3(0, s * 0.5, 0), Vector3(s, s, s), yaw, Color(1, 1, 1), Color(rng.randf(), 0, 0, 0))
	if rng.randf() < 0.5:
		var s2 := s * 0.7
		b.box("bbox", "wood", p + Vector3(0.05, s + s2 * 0.5, 0), Vector3(s2, s2, s2), yaw + 0.5, Color(0.9, 0.9, 0.9), Color(rng.randf(), 0, 0, 0))


func sack(p: Vector3) -> void:
	for k in rng.randi_range(1, 3):
		var q := p + Vector3(rng.randf_range(-0.25, 0.25), 0.22, rng.randf_range(-0.25, 0.25))
		b.box("sphere", "parchment", q, Vector3(0.5, 0.5, 0.45), rng.randf() * TAU, Color(0.55, 0.45, 0.35))


func chest(p: Vector3, yaw: float) -> void:
	var y := yaw
	b.box("bbox", "wood", p + Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 0.62), y, Color(1, 1, 1), Color(rng.randf(), 0, 0, 0))
	b.box("cyl", "wood", _xf(p, y, Vector3(0, 0.6, 0)), Vector3(0.6, 1.0, 0.6), y, Color(1, 1, 1))
	for x in [-0.35, 0.35]:
		b.box("box", "bronze", _xf(p, y, Vector3(x, 0.45, 0)), Vector3(0.08, 0.92, 0.66), y)
	b.box("box", "gold", _xf(p, y, Vector3(0, 0.62, 0.3)), Vector3(0.95, 0.15, 0.1), y)


func gold(p: Vector3) -> void:
	for k in 60:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 0.75
		var h := (1.0 - d / 0.75) * 0.45
		b.box("cyl8", "gold", p + Vector3(cos(a) * d, h * rng.randf() + 0.03, sin(a) * d), Vector3(0.14, 0.03, 0.14), 0.0, Color(1, 1, 1))
	b.box("sphere", "gold", p + Vector3(0, 0.0, 0), Vector3(1.5, 0.75, 1.5))
	b.box("bbox", "gold", p + Vector3(0.3, 0.45, 0.1), Vector3(0.3, 0.2, 0.2), 0.4)


func orrery(p: Vector3) -> void:
	# Inlaid bronze rings, radial spokes, central pillar mechanism.
	for r in [1.4, 2.3, 3.2, 3.9]:
		b.box("torus", "bronze", p + Vector3(0, 0.1, 0), Vector3(r * 2.0, 0.6, r * 2.0))
	for k in 16:
		var a := float(k) / 16.0 * TAU
		b.box("box", "bronze", p + Vector3(cos(a), 0, sin(a)) * 2.6 + Vector3(0, 0.1, 0), Vector3(2.6, 0.05, 0.1), -a)
	for k in 12:
		var a := float(k) / 12.0 * TAU
		b.box("bbox", "bronze", p + Vector3(cos(a), 0, sin(a)) * 3.55 + Vector3(0, 0.12, 0), Vector3(0.3, 0.12, 0.3), -a)
	b.box("cyl", "stone", p + Vector3(0, 0.2, 0), Vector3(2.4, 0.4, 2.4), 0.0, Color(0.9, 0.85, 0.8))
	b.box("cyl", "bronze", p + Vector3(0, 0.45, 0), Vector3(1.9, 0.1, 1.9))
	b.box("cyl", "iron", p + Vector3(0, 1.2, 0), Vector3(1.1, 1.5, 1.1))
	for y in [0.6, 1.2, 1.8]:
		b.box("cyl", "bronze", p + Vector3(0, y, 0), Vector3(1.2, 0.1, 1.2))
	b.box("cyl", "bronze", p + Vector3(0, 2.15, 0), Vector3(0.7, 0.5, 0.7))
	b.box("sphere", "bronze", p + Vector3(0, 2.45, 0), Vector3(0.6, 0.5, 0.6))
	for k in 4:
		var a := float(k) / 4.0 * TAU + 0.4
		b.box("box", "bronze", p + Vector3(cos(a) * 0.9, 1.3, sin(a) * 0.9), Vector3(0.12, 2.0, 0.12), 0.0)
	light(p + Vector3(0, 3.5, 2.5), 1.6, 6.0, Color(1.0, 0.6, 0.3))


func winch(p: Vector3) -> void:
	for side in [-1.0, 1.0]:
		b.box("box", "bronze", p + Vector3(side * 1.6, 1.3, -1.6), Vector3(0.14, 2.6, 0.14))
		b.box("box", "bronze", p + Vector3(side * 1.6, 1.3, 1.6), Vector3(0.14, 2.6, 0.14))
		b.box("box", "bronze", p + Vector3(side * 1.6, 2.6, 0), Vector3(0.12, 0.12, 3.3))
	b.box("box", "bronze", p + Vector3(0, 2.6, 0), Vector3(3.3, 0.14, 0.14))
	b.box("cyl", "iron", p + Vector3(0, 2.4, 0), Vector3(0.4, 0.5, 0.4))
	for k in 4:
		b.box("box", "iron", p + Vector3(-0.6 + k * 0.4, 1.2, 0), Vector3(0.04, 2.3, 0.04))
	b.box("box", "wood_dark", p + Vector3(0, 0.3, 0), Vector3(0.8, 0.5, 0.8))
