class_name Props
extends RefCounted
## Prop catalogue: footprints (used by the walk grid) and builders.

const FOOTPRINTS := {
	"statue_knight": Vector2(1.0, 1.0),
	"statue_big": Vector2(1.6, 1.6),
	"statue_seated": Vector2(1.2, 1.1),
	"statuette": Vector2(0.6, 0.6),
	"candles": Vector2(0.5, 0.5),
	"candle_stand": Vector2(0.4, 0.4),
	"brazier": Vector2(0.8, 0.8),
	"table": Vector2(1.6, 0.9),
	"desk": Vector2(2.0, 1.0),
	"chest": Vector2(1.0, 0.6),
	"barrel": Vector2(0.7, 0.7),
	"crates": Vector2(1.2, 1.2),
	"gold": Vector2(1.6, 1.4),
	"rug": Vector2(2.0, 1.4),
	"runner": Vector2(1.4, 4.0),
	"fireplace": Vector2(2.2, 0.9),
	"altar": Vector2(2.2, 1.0),
	"shelf": Vector2(1.6, 0.5),
	"orrery": Vector2(1.6, 1.6),
	"anvil": Vector2(0.8, 0.5),
	"armor_stand": Vector2(0.6, 0.6),
	"rubble": Vector2(1.0, 1.0),
	"bench": Vector2(1.4, 0.5),
	"urn": Vector2(0.5, 0.5),
	"sacks": Vector2(0.9, 0.8),
	"coins": Vector2(4.0, 4.0),
}
const WALK_OVER := ["rug", "runner", "coins"]


static func footprint(kind: String) -> Vector2:
	return FOOTPRINTS.get(kind, Vector2(0.6, 0.6))


static func blocks(kind: String) -> bool:
	return not WALK_OVER.has(kind)


## Half extents of a footprint after a yaw rotation (axis-aligned bound).
static func rotated_half(size: Vector2, rot_deg: float) -> Vector2:
	var r := deg_to_rad(rot_deg)
	var c := absf(cos(r))
	var s := absf(sin(r))
	return Vector2(size.x * c + size.y * s, size.x * s + size.y * c) * 0.5


# ---------------------------------------------------------------- builders

# Candle and flame light, about 2200 K: the saturated colour lives in the
# light pools, not in the paint.
const CANDLE_LIGHT := Color(1.25, 0.72, 0.25)   # same luminance as the old cream, 2200 K


static func build_all(kit: Kit, layout: Layout) -> void:
	for r in layout.rooms:
		for p in r.props:
			build(kit, p)


static func build(kit: Kit, p: Layout.Prop) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(-p.rot)), Vector3(p.pos.x, p.y(), p.pos.y))
	match p.kind:
		"statue_knight":
			knight(kit, xf, p.opts)
		"statue_big":
			big_statue(kit, xf, p.opts)
		"statue_seated":
			seated(kit, xf)
		"statuette":
			statuette(kit, xf)
		"candles":
			candles(kit, xf.origin, 3 + kit.rng.randi() % 3, 0.2)
			kit.light(xf.origin + Vector3(0, 0.6, 0), CANDLE_LIGHT, 2.6, 4.5)
		"candle_stand":
			candle_stand(kit, xf, p.opts.get("light", 1.0))
		"brazier":
			brazier(kit, xf.origin)
		"table":
			table(kit, xf, Vector3(1.6, 0.8, 0.9), p.opts.get("items", "mugs"))
		"desk":
			table(kit, xf, Vector3(2.0, 0.85, 1.0), "desk")
		"chest":
			chest(kit, xf)
		"barrel":
			barrel(kit, xf.origin, kit.rng.randf_range(0.0, TAU))
		"crates":
			crates(kit, xf)
		"gold":
			gold(kit, xf)
		"rug", "runner":
			rug(kit, xf, p.opts.get("size", footprint(p.kind)))
		"fireplace":
			fireplace(kit, xf)
		"altar":
			altar(kit, xf)
		"shelf":
			shelf(kit, xf)
		"orrery":
			orrery(kit, xf)
		"anvil":
			anvil(kit, xf)
		"armor_stand":
			armor_stand(kit, xf)
		"rubble":
			rubble(kit, xf.origin, 1.0)
		"bench":
			bench(kit, xf)
		"urn":
			urn(kit, xf.origin)
		"sacks":
			sacks(kit, xf)
		"coins":
			coins(kit, xf, p.opts.get("size", Vector2(3, 3)))
		_:
			push_warning("no builder for prop %s" % p.kind)


## Place a unit mesh in a prop's local frame.
static func _l(kit: Kit, xf: Transform3D, mesh: String, mat: String, c: Vector3, s: Vector3, b := Basis.IDENTITY, col := Color.WHITE) -> void:
	kit.piece(mesh, mat, xf * c, s, xf.basis * b, col)


static func candle(kit: Kit, base: Vector3, h: float, r := 0.035) -> void:
	kit.put("cyl8", "wax", base + Vector3(0, h * 0.5, 0), Vector3(r * 2.0, h, r * 2.0), 0.0, kit.tint(Color(1, 1, 1), 0.08))
	kit.put("cyl8", "wax", base + Vector3(r * 0.6, h * 0.75, 0), Vector3(r * 0.6, h * 0.4, r * 0.6), 0.0)
	kit.put("flame", "flame", base + Vector3(0, h + r * 1.8, 0), Vector3(r * 2.0, r * 5.0, r * 2.0))
	# A faint amber halo shell: clusters of candles must not add up to a
	# pale fog around a crisp flame.
	kit.put("flame", "flame", base + Vector3(0, h + r * 1.6, 0), Vector3(r * 5.0, r * 7.0, r * 5.0), 0.0, Color(0.35, 0.24, 0.12))
	kit.put("sphere", "glow", base + Vector3(0, h + r * 1.4, 0), Vector3(r * 0.9, r * 2.2, r * 0.9))


static func candles(kit: Kit, base: Vector3, n: int, spread: float) -> void:
	for i in n:
		var a := TAU * i / n + kit.jitter(0.4)
		var d := spread * (0.3 + 0.7 * kit.rng.randf()) if i > 0 else 0.0
		var b := base + Vector3(cos(a) * d, 0, sin(a) * d)
		candle(kit, b, kit.rng.randf_range(0.12, 0.38), kit.rng.randf_range(0.03, 0.045))
	kit.put("cyl8", "wax", base + Vector3(0, 0.01, 0), Vector3(spread * 1.6, 0.02, spread * 1.6), 0.0, Color(0.9, 0.85, 0.75))


## light scales its omni (a cluster of stands in one room stays a pool).
static func candle_stand(kit: Kit, xf: Transform3D, light := 1.0) -> void:
	var o := xf.origin
	for i in 3:
		var a := TAU * i / 3.0 + 0.3
		kit.span("box", "iron", o + Vector3(cos(a) * 0.18, 0.0, sin(a) * 0.18), o + Vector3(0, 0.28, 0), Vector2(0.035, 0.035))
	kit.put("cyl8", "iron", o + Vector3(0, 0.75, 0), Vector3(0.045, 1.0, 0.045))
	kit.put("sphere", "brass", o + Vector3(0, 0.5, 0), Vector3(0.09, 0.09, 0.09))
	kit.put("cyl", "brass", o + Vector3(0, 1.26, 0), Vector3(0.22, 0.04, 0.22))
	candle(kit, o + Vector3(0, 1.28, 0), kit.rng.randf_range(0.14, 0.24), 0.045)
	kit.light(o + Vector3(0, 1.75, 0), CANDLE_LIGHT, 1.8 * light, 3.5)


static func brazier(kit: Kit, base: Vector3) -> void:
	for i in 3:
		var a := TAU * i / 3.0
		kit.span("box", "iron", base + Vector3(cos(a) * 0.3, 0, sin(a) * 0.3), base + Vector3(cos(a) * 0.12, 0.55, sin(a) * 0.12), Vector2(0.05, 0.05))
	kit.put("cyl", "brass", base + Vector3(0, 0.62, 0), Vector3(0.55, 0.16, 0.55))
	kit.put("cyl", "iron", base + Vector3(0, 0.52, 0), Vector3(0.3, 0.08, 0.3))
	for i in 6:
		kit.put("sphere", "ember", base + Vector3(kit.jitter(0.15), 0.7, kit.jitter(0.15)), Vector3(0.12, 0.08, 0.12))
	for i in 4:
		var off := Vector3(kit.jitter(0.1), 0, kit.jitter(0.1))
		kit.put("flame", "flame", base + off + Vector3(0, 0.95, 0), Vector3(0.18, 0.5, 0.18) * kit.rng.randf_range(0.7, 1.2))
	kit.light(base + Vector3(0, 1.3, 0), Color(1.0, 0.5, 0.2), 4.0, 6.0)


## Armoured knight on a round base. opts: weapon (sword/spear/axe/shield), kneel.
static func knight(kit: Kit, xf: Transform3D, opts: Dictionary) -> void:
	var m := "statue"
	_l(kit, xf, "cyl", "stone_dark", Vector3(0, 0.07, 0), Vector3(0.9, 0.14, 0.9))
	_l(kit, xf, "ring", "brass", Vector3(0, 0.14, 0), Vector3(0.9, 0.3, 0.9))
	var kneel: bool = opts.get("kneel", false)
	var hip := 0.62 if kneel else 0.98
	if kneel:
		_l(kit, xf, "block", m, Vector3(-0.12, 0.3, 0.12), Vector3(0.17, 0.32, 0.5))
		_l(kit, xf, "block", m, Vector3(0.12, 0.45, -0.05), Vector3(0.17, 0.62, 0.2))
	else:
		for s in [-1.0, 1.0]:
			_l(kit, xf, "block", m, Vector3(s * 0.12, 0.56, 0), Vector3(0.17, 0.8, 0.2))
			_l(kit, xf, "block", m, Vector3(s * 0.13, 0.2, 0.05), Vector3(0.19, 0.1, 0.3))
			_l(kit, xf, "sphere", m, Vector3(s * 0.12, 0.58, 0.06), Vector3(0.14, 0.14, 0.12))
	_l(kit, xf, "block", m, Vector3(0, hip, 0), Vector3(0.44, 0.22, 0.28))
	_l(kit, xf, "block", m, Vector3(0, hip + 0.32, 0), Vector3(0.46, 0.46, 0.3))
	_l(kit, xf, "block", "brass", Vector3(0, hip + 0.33, 0.16), Vector3(0.12, 0.3, 0.02))
	for s in [-1.0, 1.0]:
		_l(kit, xf, "sphere", m, Vector3(s * 0.29, hip + 0.5, 0), Vector3(0.24, 0.2, 0.26))
		_l(kit, xf, "block", m, Vector3(s * 0.32, hip + 0.2, 0.06), Vector3(0.13, 0.5, 0.14), Basis(Vector3.RIGHT, -0.25))
	_l(kit, xf, "cyl", m, Vector3(0, hip + 0.62, 0), Vector3(0.14, 0.1, 0.14))
	_l(kit, xf, "cyl", m, Vector3(0, hip + 0.78, 0), Vector3(0.24, 0.26, 0.25))
	_l(kit, xf, "sphere", m, Vector3(0, hip + 0.92, 0), Vector3(0.24, 0.14, 0.25))
	_l(kit, xf, "box", "stone_dark", Vector3(0, hip + 0.79, 0.12), Vector3(0.16, 0.03, 0.02))
	_l(kit, xf, "cone", "brass", Vector3(0, hip + 1.04, -0.02), Vector3(0.07, 0.14, 0.07))
	_l(kit, xf, "block", "cloth", Vector3(0, hip + 0.05, -0.2), Vector3(0.5, 0.95, 0.04), Basis(Vector3.RIGHT, 0.12))
	match opts.get("weapon", "sword"):
		"sword":
			_l(kit, xf, "box", "iron", Vector3(0, hip - 0.25, 0.24), Vector3(0.06, 0.95, 0.02))
			_l(kit, xf, "box", "brass", Vector3(0, hip + 0.24, 0.24), Vector3(0.26, 0.04, 0.05))
			_l(kit, xf, "cyl8", "brass", Vector3(0, hip + 0.33, 0.24), Vector3(0.05, 0.16, 0.05))
		"spear":
			_l(kit, xf, "cyl8", "wood_dark", Vector3(0.36, hip + 0.3, 0.12), Vector3(0.05, 2.3, 0.05))
			_l(kit, xf, "cone", "brass", Vector3(0.36, hip + 1.55, 0.12), Vector3(0.1, 0.26, 0.04))
		"axe":
			_l(kit, xf, "cyl8", "wood_dark", Vector3(0.34, hip, 0.12), Vector3(0.05, 1.3, 0.05))
			_l(kit, xf, "block", "iron", Vector3(0.44, hip + 0.55, 0.12), Vector3(0.22, 0.26, 0.03))
		"shield":
			_l(kit, xf, "cyl", m, Vector3(-0.34, hip + 0.15, 0.18), Vector3(0.62, 0.05, 0.62), Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.FORWARD, 0.2))
			_l(kit, xf, "ring", "brass", Vector3(-0.34, hip + 0.15, 0.2), Vector3(0.64, 0.4, 0.64), Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.FORWARD, 0.2))
			_l(kit, xf, "box", "iron", Vector3(0.33, hip - 0.1, 0.18), Vector3(0.05, 0.9, 0.02))


## Large statue on a stepped plinth (throne room, chapel alcove).
static func big_statue(kit: Kit, xf: Transform3D, opts: Dictionary) -> void:
	var m := "statue" if not opts.get("robed", false) else "stone"
	_l(kit, xf, "block", "stone", Vector3(0, 0.15, 0), Vector3(1.5, 0.3, 1.5), Basis.IDENTITY, kit.tint(Color(0.5, 0.44, 0.38)))
	_l(kit, xf, "block", "stone", Vector3(0, 0.45, 0), Vector3(1.15, 0.3, 1.15), Basis.IDENTITY, kit.tint(Color(0.5, 0.44, 0.38)))
	_l(kit, xf, "box", "brass", Vector3(0, 0.6, 0), Vector3(1.18, 0.04, 1.18))
	_l(kit, xf, "cone", m, Vector3(0, 1.45, 0), Vector3(1.0, 1.7, 0.9))
	_l(kit, xf, "block", m, Vector3(0, 2.15, 0), Vector3(0.62, 0.55, 0.4))
	for s in [-1.0, 1.0]:
		_l(kit, xf, "sphere", m, Vector3(s * 0.36, 2.35, 0), Vector3(0.3, 0.26, 0.32))
		_l(kit, xf, "block", m, Vector3(s * 0.2, 1.95, 0.24), Vector3(0.16, 0.5, 0.16), Basis(Vector3.FORWARD, s * 0.5))
	_l(kit, xf, "sphere", m, Vector3(0, 2.62, 0.02), Vector3(0.3, 0.36, 0.32))
	if opts.get("robed", false):
		_l(kit, xf, "cone", m, Vector3(0, 2.72, -0.02), Vector3(0.46, 0.5, 0.46))
		_l(kit, xf, "box", "brass", Vector3(0, 1.95, 0.3), Vector3(0.1, 0.4, 0.04))
		# Votive candles at the plinth light the figure from below: a tight
		# pool on the statue and its niche, not the floor.
		for sx in [-0.5, 0.5]:
			candles(kit, xf * Vector3(sx, 0.62, 0.45), 3, 0.1)
		kit.light(xf * Vector3(0, 1.3, 0.75), CANDLE_LIGHT, 1.5, 2.2)
	else:
		_l(kit, xf, "cyl", "brass", Vector3(0, 2.84, 0.02), Vector3(0.3, 0.12, 0.3))
		_l(kit, xf, "box", "iron", Vector3(0, 1.5, 0.42), Vector3(0.08, 1.4, 0.03))
		_l(kit, xf, "box", "brass", Vector3(0, 2.15, 0.42), Vector3(0.36, 0.06, 0.06))


static func seated(kit: Kit, xf: Transform3D) -> void:
	_l(kit, xf, "block", "stone", Vector3(0, 0.3, -0.05), Vector3(1.0, 0.6, 0.9))
	_l(kit, xf, "block", "stone", Vector3(0, 1.05, -0.42), Vector3(1.0, 1.5, 0.2))
	_l(kit, xf, "cone", "stone", Vector3(0, 1.7, -0.42), Vector3(0.6, 0.4, 0.2))
	var m := "statue"
	_l(kit, xf, "block", m, Vector3(0, 0.75, 0.05), Vector3(0.5, 0.3, 0.6))
	for s in [-1.0, 1.0]:
		_l(kit, xf, "block", m, Vector3(s * 0.13, 0.35, 0.33), Vector3(0.16, 0.6, 0.18))
	_l(kit, xf, "block", m, Vector3(0, 1.12, -0.15), Vector3(0.5, 0.55, 0.3))
	_l(kit, xf, "sphere", m, Vector3(0, 1.52, -0.12), Vector3(0.26, 0.3, 0.26))
	_l(kit, xf, "cyl", "brass", Vector3(0, 1.68, -0.12), Vector3(0.24, 0.08, 0.24))


static func statuette(kit: Kit, xf: Transform3D) -> void:
	_l(kit, xf, "block", "stone", Vector3(0, 0.35, 0), Vector3(0.5, 0.7, 0.5))
	_l(kit, xf, "box", "brass", Vector3(0, 0.71, 0), Vector3(0.54, 0.04, 0.54))
	_l(kit, xf, "cone", "brass", Vector3(0, 1.05, 0), Vector3(0.32, 0.6, 0.32))
	_l(kit, xf, "sphere", "brass", Vector3(0, 1.42, 0), Vector3(0.16, 0.18, 0.16))
	_l(kit, xf, "block", "brass", Vector3(0.15, 1.2, 0.05), Vector3(0.06, 0.4, 0.06), Basis(Vector3.FORWARD, -0.6))


static func table(kit: Kit, xf: Transform3D, size: Vector3, items: String) -> void:
	var n := int(size.x / 0.25)
	for i in n:
		var x := -size.x * 0.5 + (i + 0.5) * size.x / n
		_l(kit, xf, "plank", "wood", Vector3(x, size.y - 0.04, 0), Vector3(size.x / n - 0.015, 0.07, size.z), Basis.IDENTITY, kit.tint(Color(1, 1, 1), 0.15))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_l(kit, xf, "plank", "wood_dark", Vector3(sx * (size.x * 0.5 - 0.1), (size.y - 0.08) * 0.5, sz * (size.z * 0.5 - 0.1)), Vector3(0.1, size.y - 0.08, 0.1))
	_l(kit, xf, "plank", "wood_dark", Vector3(0, 0.2, 0), Vector3(size.x - 0.2, 0.07, 0.07))
	var top := size.y
	match items:
		"mugs":
			for i in 4:
				var c := Vector3(kit.jitter(size.x * 0.4), top + 0.07, kit.jitter(size.z * 0.35))
				_l(kit, xf, "cyl8", "brass" if i % 2 else "wood_dark", c, Vector3(0.09, 0.14, 0.09))
			_l(kit, xf, "box", "wood_dark", Vector3(0.3, top + 0.03, 0.1), Vector3(0.4, 0.04, 0.3))
		"tools":
			_l(kit, xf, "box", "iron", Vector3(-0.3, top + 0.04, 0), Vector3(0.5, 0.06, 0.08))
			_l(kit, xf, "box", "iron", Vector3(0.2, top + 0.05, 0.15), Vector3(0.12, 0.1, 0.3))
			_l(kit, xf, "cyl8", "wood_dark", Vector3(0.4, top + 0.12, -0.2), Vector3(0.2, 0.24, 0.2))
		"papers", "desk":
			for i in 5:
				var c := Vector3(kit.jitter(size.x * 0.4), top + 0.01, kit.jitter(size.z * 0.3))
				_l(kit, xf, "box", "paper", c, Vector3(0.24, 0.01, 0.32), Basis(Vector3.UP, kit.jitter(0.5)))
			for i in 3:
				_l(kit, xf, "block", "cloth" if i % 2 else "wood_dark", Vector3(-size.x * 0.35 + i * 0.12, top + 0.06, -size.z * 0.3), Vector3(0.1, 0.12 + i * 0.02, 0.24))
			var cpos := xf * Vector3(size.x * 0.38, top, -size.z * 0.25)
			candles(kit, cpos, 3, 0.08)
			kit.light(cpos + Vector3(0, 0.5, 0), CANDLE_LIGHT, 1.2, 3.0)


static func sacks(kit: Kit, xf: Transform3D) -> void:
	for i in 3:
		var c := Vector3(kit.jitter(0.25), 0.2, kit.jitter(0.2))
		_l(kit, xf, "sphere", "cloth", c, Vector3(0.42, 0.45, 0.36), Basis(Vector3.UP, kit.jitter(1.0)), Color(0.7, 0.9, 1.1))
		_l(kit, xf, "cyl8", "wood_dark", c + Vector3(0, 0.24, 0), Vector3(0.12, 0.08, 0.12))


## Coins strewn across a floor area (walkable).
static func coins(kit: Kit, xf: Transform3D, size: Vector2) -> void:
	for i in int(size.x * size.y * 22.0):
		var p := Vector3(kit.rng.randf_range(-0.5, 0.5) * size.x, 0.012, kit.rng.randf_range(-0.5, 0.5) * size.y)
		_l(kit, xf, "cyl8", "gold", p, Vector3(0.07, 0.012, 0.07), Basis.from_euler(Vector3(kit.jitter(0.3), kit.rng.randf() * TAU, kit.jitter(0.3))), kit.tint(Color(1, 1, 1), 0.2))


static func chest(kit: Kit, xf: Transform3D) -> void:
	_l(kit, xf, "plank", "wood", Vector3(0, 0.25, 0), Vector3(0.95, 0.5, 0.58), Basis.IDENTITY, kit.tint(Color(1, 1, 1), 0.1))
	_l(kit, xf, "cyl", "wood", Vector3(0, 0.5, 0), Vector3(0.58, 0.95, 0.4), Basis(Vector3.BACK, PI * 0.5))
	for x in [-0.32, 0.0, 0.32]:
		_l(kit, xf, "box", "brass", Vector3(x, 0.3, 0), Vector3(0.06, 0.62, 0.62))
	_l(kit, xf, "box", "gold", Vector3(0, 0.42, 0.3), Vector3(0.12, 0.14, 0.04))


static func barrel(kit: Kit, base: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	kit.piece("cyl", "wood", base + Vector3(0, 0.45, 0), Vector3(0.62, 0.6, 0.62), b, kit.tint(Color(1, 1, 1), 0.12))
	kit.piece("cyl", "wood", base + Vector3(0, 0.12, 0), Vector3(0.54, 0.24, 0.54), b)
	kit.piece("cyl", "wood", base + Vector3(0, 0.78, 0), Vector3(0.54, 0.2, 0.54), b)
	for y in [0.2, 0.7]:
		kit.piece("cyl", "iron", base + Vector3(0, y, 0), Vector3(0.6, 0.05, 0.6), b)
	kit.piece("cyl", "wood_dark", base + Vector3(0, 0.89, 0), Vector3(0.5, 0.02, 0.5), b)


static func crates(kit: Kit, xf: Transform3D) -> void:
	var boxes := [[Vector3(-0.25, 0.3, 0), 0.6], [Vector3(0.3, 0.25, 0.1), 0.5], [Vector3(-0.15, 0.85, 0.05), 0.5]]
	for bx in boxes:
		var c: Vector3 = bx[0]
		var s: float = bx[1]
		var yaw := kit.jitter(0.3)
		_l(kit, xf, "plank", "wood", c, Vector3(s, s, s), Basis(Vector3.UP, yaw), kit.tint(Color(1, 1, 1), 0.15))
		for e in [-1.0, 1.0]:
			_l(kit, xf, "box", "wood_dark", c + Basis(Vector3.UP, yaw) * Vector3(e * s * 0.46, 0, s * 0.51), Vector3(0.07, s, 0.03), Basis(Vector3.UP, yaw))
			_l(kit, xf, "box", "wood_dark", c + Basis(Vector3.UP, yaw) * Vector3(0, e * s * 0.46, s * 0.51), Vector3(s, 0.07, 0.03), Basis(Vector3.UP, yaw))


## A heap of coins over a dark, lumpy gold mound, with goblets and ingots:
## the metal shows as glints where candles catch it, not as a yellow disc.
static func gold(kit: Kit, xf: Transform3D) -> void:
	var body := Color(0.45, 0.4, 0.36)
	_l(kit, xf, "cone", "gold", Vector3(0, 0.22, 0), Vector3(1.5, 0.44, 1.25), Basis.IDENTITY, body)
	_l(kit, xf, "sphere", "gold", Vector3(0.25, 0.08, 0.1), Vector3(0.9, 0.3, 0.7), Basis.IDENTITY, body)
	# Lumps that break the cone's outline (outside the level's random sequence).
	var st := kit.rng.state
	for i in 6:
		var a := kit.rng.randf() * TAU
		var d := kit.rng.randf_range(0.35, 0.75)
		var sz := kit.rng.randf_range(0.3, 0.55)
		_l(kit, xf, "sphere", "gold", Vector3(cos(a) * d * 0.78, 0.04, sin(a) * d * 0.65), Vector3(sz, sz * 0.4, sz * 0.75),
			Basis(Vector3.UP, kit.rng.randf() * TAU), body)
	kit.rng.state = st
	for i in 320:
		var a := kit.rng.randf() * TAU
		var d := sqrt(kit.rng.randf()) * 1.15
		var x := cos(a) * d * 0.78
		var z := sin(a) * d * 0.65
		var h := maxf(0.44 * (1.0 - d), 0.0) + 0.012
		var tilt := Basis.from_euler(Vector3(kit.jitter(0.7), kit.rng.randf() * TAU, kit.jitter(0.7)))
		_l(kit, xf, "cyl8", "gold", Vector3(x, h, z), Vector3(0.075, 0.014, 0.075), tilt, kit.tint(Color(1, 1, 1), 0.2))
	for i in 3:
		var c := Vector3(kit.jitter(0.6), 0.0, kit.jitter(0.5))
		_l(kit, xf, "cyl8", "gold", c + Vector3(0, 0.1, 0), Vector3(0.12, 0.14, 0.12))
		_l(kit, xf, "cyl8", "gold", c + Vector3(0, 0.02, 0), Vector3(0.05, 0.08, 0.05))
	for i in 4:
		_l(kit, xf, "block", "gold", Vector3(kit.jitter(0.8), 0.04, kit.jitter(0.6)), Vector3(0.22, 0.07, 0.1), Basis(Vector3.UP, kit.jitter(1.5)))
	_l(kit, xf, "sphere", "brass", Vector3(-0.5, 0.12, 0.35), Vector3(0.26, 0.24, 0.26))


static func rug(kit: Kit, xf: Transform3D, size: Vector2) -> void:
	_l(kit, xf, "box", "cloth", Vector3(0, 0.018, 0), Vector3(size.x, 0.016, size.y))


static func fireplace(kit: Kit, xf: Transform3D) -> void:
	for s in [-1.0, 1.0]:
		for i in 6:
			_l(kit, xf, "block", "stone", Vector3(s * 0.85, 0.15 + i * 0.28, 0.0), Vector3(0.42, 0.26, 0.7), Basis.IDENTITY, kit.tint(Color(0.5, 0.43, 0.36), 0.15))
	_l(kit, xf, "block", "stone", Vector3(0, 1.8, 0.05), Vector3(2.3, 0.3, 0.85), Basis.IDENTITY, kit.tint(Color(0.5, 0.43, 0.36), 0.1))
	_l(kit, xf, "block", "stone_dark", Vector3(0, 0.85, -0.3), Vector3(1.3, 1.7, 0.2))
	_l(kit, xf, "block", "stone_dark", Vector3(0, 0.05, 0.0), Vector3(1.4, 0.1, 0.7))
	for i in 4:
		_l(kit, xf, "cyl8", "wood_dark", Vector3(kit.jitter(0.3), 0.18, kit.jitter(0.15)), Vector3(0.14, 0.8, 0.14), Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.RIGHT, kit.jitter(0.5)))
	for i in 10:
		_l(kit, xf, "sphere", "ember", Vector3(kit.jitter(0.45), 0.12, kit.jitter(0.2)), Vector3(0.16, 0.08, 0.14))
	for i in 7:
		_l(kit, xf, "flame", "flame", Vector3(kit.jitter(0.35), 0.5, kit.jitter(0.12)), Vector3(0.3, 0.8, 0.25) * kit.rng.randf_range(0.6, 1.1))
	kit.light(xf * Vector3(0, 0.8, 0.8), Color(1.0, 0.42, 0.14), 7.0, 7.5)
	# Cauldron hanging in the fire.
	_l(kit, xf, "sphere", "iron", Vector3(0.0, 0.6, 0.05), Vector3(0.5, 0.42, 0.5))
	_l(kit, xf, "box", "iron", Vector3(0.0, 1.2, 0.05), Vector3(0.03, 0.8, 0.03))


static func altar(kit: Kit, xf: Transform3D) -> void:
	_l(kit, xf, "block", "stone", Vector3(0, 0.45, 0), Vector3(2.0, 0.9, 0.85), Basis.IDENTITY, kit.tint(Color(0.55, 0.48, 0.4)))
	_l(kit, xf, "block", "stone", Vector3(0, 0.95, 0), Vector3(2.15, 0.1, 0.95), Basis.IDENTITY, kit.tint(Color(0.55, 0.48, 0.4)))
	_l(kit, xf, "box", "cloth", Vector3(0, 0.75, 0.43), Vector3(0.9, 0.55, 0.02))
	for i in 10:
		var x := -0.9 + i * 0.2
		var c := xf * Vector3(x, 1.0, kit.jitter(0.25))
		candle(kit, c, kit.rng.randf_range(0.15, 0.4), 0.04)
	_l(kit, xf, "block", "gold", Vector3(0, 1.08, 0), Vector3(0.3, 0.16, 0.2))
	# Above and in front of the candle row, so the wax beside them doesn't
	# blow out (the falloff is steep near the source).
	kit.light(xf * Vector3(-0.6, 2.2, 0.6), CANDLE_LIGHT, 0.6, 2.5)
	kit.light(xf * Vector3(0.6, 2.2, 0.6), CANDLE_LIGHT, 0.6, 2.5)


static func shelf(kit: Kit, xf: Transform3D) -> void:
	for s in [-1.0, 1.0]:
		_l(kit, xf, "plank", "wood_dark", Vector3(s * 0.78, 1.0, 0), Vector3(0.08, 2.0, 0.42))
	for i in 5:
		var y := 0.1 + i * 0.45
		_l(kit, xf, "plank", "wood", Vector3(0, y, 0), Vector3(1.5, 0.05, 0.4))
		if i < 4:
			var x := -0.68
			while x < 0.65:
				var w := kit.rng.randf_range(0.05, 0.11)
				var h := kit.rng.randf_range(0.25, 0.38)
				var mat: String = ["cloth", "wood_dark", "paper", "brass"][kit.rng.randi() % 4]
				_l(kit, xf, "box", mat, Vector3(x + w * 0.5, y + 0.03 + h * 0.5, 0.02), Vector3(w - 0.01, h, 0.28), Basis(Vector3.BACK, kit.jitter(0.12)))
				x += w + (0.1 if kit.rng.randf() < 0.1 else 0.0)


## The orrery: a dark bronze disc over most of the dais with a band of bronze
## plates between gilt rims, gilt spokes and straps, a toothed inner ring, and
## a dark bronze column with gilt bands and armillary rings on a stepped
## bronze plinth. The body stays dark; worn bevels and the gilt catch the light.
static func orrery(kit: Kit, xf: Transform3D) -> void:
	# Built outside the shared random sequence, which is then left where the
	# earlier 33-piece orrery left it (99 draws), so nothing else reshuffles.
	var st := kit.rng.state
	var rad := 2.85
	var top := 0.1
	_l(kit, xf, "disc", "bronze_dark", Vector3(0, top * 0.5 - 0.01, 0), Vector3(rad * 2.0, top + 0.02, rad * 2.0))
	# Outer band: bronze plates between gilt rims, with gilt straps at the joints.
	var band := Vector2(2.2, 2.72)
	var mid := (band.x + band.y) * 0.5
	var n := 16
	for i in n:
		var a := TAU * (i + 0.5) / n
		_l(kit, xf, "block", "bronze", _polar(a, mid, top + 0.025), Vector3(band.y - band.x - 0.04, 0.05, TAU * mid / n - 0.07), Basis(Vector3.UP, -a))
		var aj := TAU * i / n
		_l(kit, xf, "block", "gilt", _polar(aj, mid, top + 0.035), Vector3(band.y - band.x + 0.08, 0.06, 0.07), Basis(Vector3.UP, -aj))
	for rr in [rad - 0.03, band.x - 0.01]:
		_l(kit, xf, "ring48", "gilt", Vector3(0, top + 0.02, 0), Vector3(rr * 2.0, 2.4, rr * 2.0))
	# Inner field: gilt spokes and a thin ring on the dark disc.
	for i in 8:
		var a := TAU * (i + 0.5) / 8.0
		_l(kit, xf, "block", "gilt", _polar(a, 1.62, top + 0.02), Vector3(1.1, 0.04, 0.07), Basis(Vector3.UP, -a))
	_l(kit, xf, "ring48", "gilt", Vector3(0, top + 0.01, 0), Vector3(3.3, 1.6, 3.3))
	# Toothed inner ring.
	_l(kit, xf, "disc", "bronze_dark", Vector3(0, top + 0.08, 0), Vector3(2.1, 0.16, 2.1))
	for i in 28:
		var a := TAU * i / 28.0
		_l(kit, xf, "block", "bronze", _polar(a, 1.07, top + 0.07), Vector3(0.12, 0.12, 0.1), Basis(Vector3.UP, -a))
	_l(kit, xf, "ring48", "gilt", Vector3(0, top + 0.16, 0), Vector3(2.08, 1.6, 2.08))
	# Stepped plinth with gilt edges.
	_l(kit, xf, "disc", "bronze_dark", Vector3(0, 0.36, 0), Vector3(1.5, 0.2, 1.5))
	_l(kit, xf, "ring48", "gilt", Vector3(0, 0.46, 0), Vector3(1.52, 1.4, 1.52))
	_l(kit, xf, "disc", "bronze", Vector3(0, 0.54, 0), Vector3(1.1, 0.16, 1.1))
	_l(kit, xf, "ring48", "gilt", Vector3(0, 0.62, 0), Vector3(1.12, 1.4, 1.12))
	# Column, cap and armillary rings.
	_l(kit, xf, "cyl", "bronze_dark", Vector3(0, 1.41, 0), Vector3(0.62, 1.58, 0.62))
	for y in [0.9, 1.4, 1.9]:
		_l(kit, xf, "ring", "gilt", Vector3(0, y, 0), Vector3(0.72, 1.2, 0.72))
	_l(kit, xf, "cyl", "bronze", Vector3(0, 2.26, 0), Vector3(0.85, 0.12, 0.85))
	_l(kit, xf, "ring", "gilt", Vector3(0, 2.32, 0), Vector3(0.9, 0.6, 0.9))
	_l(kit, xf, "cyl", "bronze_dark", Vector3(0, 2.57, 0), Vector3(0.45, 0.5, 0.45))
	_l(kit, xf, "cone", "bronze_dark", Vector3(0, 2.97, 0), Vector3(0.5, 0.3, 0.5))
	_l(kit, xf, "sphere", "gilt", Vector3(0, 3.18, 0), Vector3(0.18, 0.18, 0.18))
	for k in 3:
		_l(kit, xf, "ring", "gilt", Vector3(0, 2.57, 0), Vector3(1.1, 0.4, 1.1), Basis(Vector3.UP, k * 1.05) * Basis(Vector3.RIGHT, 1.2))
	kit.rng.state = st
	for i in 99:
		kit.rng.randf()


static func _polar(a: float, r: float, y: float) -> Vector3:
	return Vector3(cos(a) * r, y, sin(a) * r)


static func anvil(kit: Kit, xf: Transform3D) -> void:
	_l(kit, xf, "block", "wood_dark", Vector3(0, 0.25, 0), Vector3(0.45, 0.5, 0.45))
	_l(kit, xf, "block", "iron", Vector3(0, 0.6, 0), Vector3(0.7, 0.2, 0.28))
	_l(kit, xf, "cone", "iron", Vector3(0.45, 0.62, 0), Vector3(0.18, 0.3, 0.18), Basis(Vector3.BACK, PI * 0.5))


static func armor_stand(kit: Kit, xf: Transform3D) -> void:
	_l(kit, xf, "box", "wood_dark", Vector3(0, 0.05, 0), Vector3(0.5, 0.1, 0.5))
	_l(kit, xf, "cyl8", "wood_dark", Vector3(0, 0.8, 0), Vector3(0.06, 1.5, 0.06))
	_l(kit, xf, "block", "statue", Vector3(0, 1.3, 0), Vector3(0.42, 0.5, 0.26))
	_l(kit, xf, "sphere", "statue", Vector3(0, 1.68, 0), Vector3(0.22, 0.26, 0.24))
	for s in [-1.0, 1.0]:
		_l(kit, xf, "sphere", "statue", Vector3(s * 0.26, 1.5, 0), Vector3(0.2, 0.18, 0.22))


static func rubble(kit: Kit, base: Vector3, size: float) -> void:
	for i in 14:
		var s := kit.rng.randf_range(0.12, 0.32) * size
		var p := base + Vector3(kit.jitter(0.45) * size, s * 0.35, kit.jitter(0.45) * size)
		kit.piece("block", "stone", p, Vector3(s * kit.rng.randf_range(1.0, 1.8), s * 0.8, s),
			Basis.from_euler(Vector3(kit.jitter(0.5), kit.rng.randf() * TAU, kit.jitter(0.5))), kit.tint(Color(0.47, 0.42, 0.37), 0.2))


static func bench(kit: Kit, xf: Transform3D) -> void:
	_l(kit, xf, "plank", "wood", Vector3(0, 0.45, 0), Vector3(1.4, 0.07, 0.4))
	for s in [-1.0, 1.0]:
		_l(kit, xf, "plank", "wood_dark", Vector3(s * 0.55, 0.21, 0), Vector3(0.08, 0.42, 0.34))


static func urn(kit: Kit, base: Vector3) -> void:
	kit.put("sphere", "brass", base + Vector3(0, 0.28, 0), Vector3(0.42, 0.46, 0.42))
	kit.put("cyl", "brass", base + Vector3(0, 0.56, 0), Vector3(0.2, 0.16, 0.2))
	kit.put("cyl", "brass", base + Vector3(0, 0.05, 0), Vector3(0.26, 0.1, 0.26))
