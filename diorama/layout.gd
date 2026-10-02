class_name Layout
extends Kit
## The authored diorama, traced from the reference composition (camera looks
## north, -Z). Plan units are roughly one flagstone row. The seed varies detail.

const WALL_T := 0.45

func _init(seed_value: int) -> void:
	super(seed_value)

## Per-room placement on top of each room's local plan (fitted to the reference).
const PLACE := {
	"gatehouse": Vector3(-1.5, 0.6, -4.0),
	"study": Vector3(-1.5, 0.5, -4.0),
	"chapel": Vector3(2.0, 0.0, -2.0),
	"treasury": Vector3(3.0, 0.0, -1.5),
	"mechanism": Vector3(2.0, 0.0, 0.0),
	"barracks": Vector3(2.5, 0.0, 1.5),
}

func generate() -> void:
	for part in ["gatehouse", "study", "forge", "hall", "ruin", "chapel", "treasury", "mechanism", "barracks", "lift", "connections", "backdrop"]:
		offset = PLACE.get(part, Vector3.ZERO)
		call(part)
	offset = Vector3.ZERO

# ---------------------------------------------------------------- helpers

## A walled room on piers. walls: side -> [height, [[from, to], ...] openings].
func room(x0: float, z0: float, x1: float, z1: float, h: float, walls: Dictionary, piers := true) -> void:
	slab(x0, z0, x1, z1, h, 1.1)
	flagstones(x0 + 0.05, z0 + 0.05, x1 - 0.05, z1 - 0.05, h)
	add_walk(Walk.rect(x0 + WALL_T, z0 + WALL_T, x1 - WALL_T, z1 - WALL_T, h, 0.3))
	debris(x0 + 0.5, z0 + 0.5, x1 - 0.5, z1 - 0.5, h, int((x1 - x0) * (z1 - z0) * 0.25))
	var i := WALL_T * 0.5
	for side in walls:
		var spec: Array = walls[side]
		var height: float = spec[0]
		var gaps: Array = spec[1] if spec.size() > 1 else []
		match side:
			"n": wall_run(Vector2(x0, z0 + i), Vector2(x1, z0 + i), h, height, gaps, true)
			"s": wall_run(Vector2(x0, z1 - i), Vector2(x1, z1 - i), h, height, gaps, true)
			"w": wall_run(Vector2(x0 + i, z0), Vector2(x0 + i, z1), h, height, gaps, false)
			"e": wall_run(Vector2(x1 - i, z0), Vector2(x1 - i, z1), h, height, gaps, false)
	if piers:
		foundation(x0, z0, x1, z1, h)
		var w := 1.7
		var xs := [x0 + w * 0.5 + 0.2, x1 - w * 0.5 - 0.2]
		var zs := [z0 + w * 0.5 + 0.2, z1 - w * 0.5 - 0.2]
		if x1 - x0 > 11.0:
			xs.insert(1, (x0 + x1) * 0.5)
		if z1 - z0 > 11.0:
			zs.insert(1, (z0 + z1) * 0.5)
		for x in xs:
			for z in zs:
				if x == xs[0] or x == xs[-1] or z == zs[0] or z == zs[-1]:
					pier(x, z, h - 1.25, w)

## Deep masonry block under a room, banded with string courses, before the piers take over.
func foundation(x0: float, z0: float, x1: float, z1: float, h: float) -> void:
	var depth := r(2.5, 4.5)
	var top := h - 1.4
	var bot := top - depth
	box("brick", Vector3((x0 + x1) * 0.5, (top + bot) * 0.5, (z0 + z1) * 0.5), Vector3(x1 - x0 - 0.5, depth, z1 - z0 - 0.5), jit(Kit.STONE_DARK.darkened(0.3), 0.05))
	var y := top - 1.6
	while y > bot + 0.5:
		box("stone", Vector3((x0 + x1) * 0.5, y, (z0 + z1) * 0.5), Vector3(x1 - x0 - 0.3, 0.32, z1 - z0 - 0.3), jit(Kit.STONE_DARK, 0.08))
		y -= r(1.8, 2.8)
	# arched recesses on the front face
	var x := x0 + 1.4
	while x < x1 - 1.4:
		if chance(0.3):
			arch(Vector3(x, top - 2.4, z1 - 0.2), 0.0, 1.0, 1.8, Color(0, 0, 0), Kit.STONE_DARK)
		x += r(2.2, 3.4)
	box("stone", Vector3((x0 + x1) * 0.5, bot - 0.2, (z0 + z1) * 0.5), Vector3(x1 - x0 - 1.2, 0.4, z1 - z0 - 1.2), Kit.STONE_DARK.darkened(0.3))

## Wall along x (or z) from p0 to p1 with door gaps given in that axis' coordinate.
func wall_run(p0: Vector2, p1: Vector2, base: float, height: float, gaps: Array, along_x: bool) -> void:
	var c0 := p0.x if along_x else p0.y
	var c1 := p1.x if along_x else p1.y
	var cuts := [[c0, c0]]
	for g in gaps:
		cuts.append(g)
	cuts.append([c1, c1])
	cuts.sort_custom(func(u, v): return u[0] < v[0])
	for k in cuts.size() - 1:
		var a: float = cuts[k][1]
		var b: float = cuts[k + 1][0]
		if b - a < 0.1:
			continue
		var pa := Vector2(a, p0.y) if along_x else Vector2(p0.x, a)
		var pb := Vector2(b, p0.y) if along_x else Vector2(p0.x, b)
		wall(pa, pb, base, height * r(0.85, 1.1), WALL_T)
		# gate posts at the door sides
		if k > 0:
			tower(pa.x, pa.y, base, base + height + 0.35, 0.62)
		if k < cuts.size() - 2:
			tower(pb.x, pb.y, base, base + height + 0.35, 0.62)
	# candles along the wall top
	var t := c0 + r(0.5, 2.0)
	while t < c1 - 0.5:
		var inside := false
		for g in gaps:
			if t > g[0] - 0.3 and t < g[1] + 0.3:
				inside = true
		if not inside and chance(0.5):
			var p := Vector2(t, p0.y) if along_x else Vector2(p0.x, t)
			candle(Vector3(p.x, base + height, p.y), r(0.15, 0.3), true, 0.8)
		t += r(1.8, 3.2)

func corner_towers(x0: float, z0: float, x1: float, z1: float, base: float, top: float, w := 1.0) -> void:
	for p in [Vector2(x0 + w * 0.5, z0 + w * 0.5), Vector2(x1 - w * 0.5, z0 + w * 0.5), Vector2(x0 + w * 0.5, z1 - w * 0.5), Vector2(x1 - w * 0.5, z1 - w * 0.5)]:
		tower(p.x, p.y, base, top, w)
		candles(Vector3(p.x, top + 0.45, p.y), 2, 0.15, 0.9)

# ---------------------------------------------------------------- rooms

func gatehouse() -> void:
	var h := 2.4
	var hu := 3.6
	room(3.5, 1.5, 13.0, 12.0, h, {"w": [1.7], "s": [1.0, [[5.2, 7.2]]], "e": [1.6, [[7.0, 9.0]]]})
	# raised dais along the north with stairs on the west
	slab(3.5, 1.5, 13.0, 5.8, hu, 1.0)
	box("brick", Vector3(8.25, (hu + h) * 0.5, 5.75), Vector3(9.5, hu - h, 0.3), jit(STONE, 0.05))
	flagstones(3.6, 1.6, 12.9, 5.7, hu)
	add_walk(Walk.rect(4.0, 2.0, 12.6, 5.6, hu, 0.0))
	wall_run(Vector2(3.5, 1.7), Vector2(13.0, 1.7), hu, 1.8, [], true)
	wall_run(Vector2(12.8, 1.5), Vector2(12.8, 5.8), hu, 1.2, [], false)
	stairs(5.0, 9.6, 7.6, 5.6, h, hu, false)
	for x in [4.6, 8.6]:
		wall(Vector2(x, 6.2), Vector2(x, 9.6), h, 1.0, 0.4)
	corner_towers(3.5, 1.5, 13.0, 12.0, h, h + 2.8, 1.2)
	statue(Vector3(10.0, hu, 3.2), PI * 0.1, 1.5)
	statue(Vector3(6.0, hu, 3.0), -PI * 0.1, 1.5)
	candles(Vector3(8.2, hu, 2.4), 5, 0.3)
	figure(Vector3(10.5, h, 9.5), 0.6, 1.0, Color(0.5, 0.45, 0.4))
	barrel(Vector3(12.2, h, 6.6))
	crate(Vector3(4.4, h, 11.0))
	rubble(Vector3(11.6, h, 11.2), 0.6, 6)

func study() -> void:
	var h := 1.5
	room(13.0, 3.0, 23.5, 13.5, h, {"n": [3.0], "e": [1.7, [[4.6, 7.0]]], "s": [1.0, [[18.4, 21.0]]]})
	for i in 4:
		arch(Vector3(15.0 + i * 2.4, h, 3.5), 0.0, 1.3, 2.0, Color(0.5, 0.2, 0.05) if i == 1 else Color(0, 0, 0))
	bookshelf(Vector3(14.2, h, 6.5), PI * 0.5, 1.6)
	bookshelf(Vector3(14.2, h, 9.3), PI * 0.5, 1.6)
	table(Vector3(18.0, h, 7.0), 2.4, 1.1)
	chair(Vector3(18.0, h, 8.0), PI)
	chair(Vector3(17.0, h, 6.0), 0.0)
	candles(Vector3(17.3, h + 0.6, 7.1), 3, 0.15)
	box("plain", Vector3(18.6, h + 0.62, 6.9), Vector3(0.5, 0.04, 0.35), Color(0.75, 0.66, 0.5), 0.2)
	carpet(16.2, 9.4, 21.2, 12.8, h)
	table(Vector3(21.6, h, 10.0), 1.0, 1.6)
	candles(Vector3(21.6, h + 0.6, 9.6), 2, 0.1)
	chest(Vector3(22.5, h, 12.6), PI)
	figure(Vector3(19.8, h, 11.3), PI * 0.9, 1.0, Color(0.42, 0.4, 0.42))
	candelabra(Vector3(15.0, h, 12.4))

func forge() -> void:
	var h := 0.8
	room(1.5, 8.5, 11.0, 25.0, h, {"n": [3.0, [[3.8, 5.9]]], "w": [1.6], "e": [1.4, [[16.2, 18.8]]], "s": [1.0, [[4.0, 6.2]]]})
	# hearth against the west wall
	var hx := 2.6
	box("brick", Vector3(hx, h + 1.2, 16.0), Vector3(1.6, 2.4, 2.6), jit(STONE_DARK, 0.05))
	box("plain", Vector3(hx + 0.55, h + 0.6, 16.0), Vector3(0.6, 1.0, 1.6), Color(0.05, 0.02, 0.01))
	box("stone", Vector3(hx + 0.6, h + 1.25, 16.0), Vector3(0.7, 0.25, 2.8), jit(STONE, 0.1))
	for i in 9:
		shape("sphere", "flame", Vector3(hx + 0.6 + r(-0.15, 0.15), h + 0.25 + r(0, 0.15), 16.0 + r(-0.6, 0.6)), Vector3(0.22, r(0.4, 0.7), 0.22), Color(1.0, r(0.35, 0.55), 0.12))
	for i in 6:
		shape("sphere", "glow", Vector3(hx + 0.6 + r(-0.2, 0.2), h + 0.1, 16.0 + r(-0.6, 0.6)), Vector3(0.3, 0.12, 0.3), Color(1.0, 0.3, 0.05))
	light(Vector3(hx + 1.4, h + 1.0, 16.0), 12.0, 8.0, Color(1.0, 0.45, 0.15))
	light(Vector3(hx + 0.9, h + 0.5, 16.0), 6.0, 3.0, Color(1.0, 0.35, 0.1))
	add_block(hx + 0.6, 16.0, 1.3)
	# anvil, work table, tools
	box("iron", Vector3(5.2, h + 0.35, 16.2), Vector3(0.35, 0.7, 0.3), IRON)
	box("iron", Vector3(5.2, h + 0.75, 16.2), Vector3(0.8, 0.18, 0.32), IRON.lightened(0.1))
	add_block(5.2, 16.2, 0.45)
	table(Vector3(6.5, h, 19.5), 2.0, 1.0, 0.1)
	candles(Vector3(6.0, h + 0.6, 19.4), 2, 0.1)
	for i in 4:
		box("iron", Vector3(6.6 + i * 0.2, h + 0.62, 19.6), Vector3(0.05, 0.03, 0.5), IRON, r(-0.3, 0.3))
	barrel(Vector3(9.8, h, 13.6))
	barrel(Vector3(10.2, h, 14.3))
	crate(Vector3(2.4, h, 23.8))
	crate(Vector3(2.8, h, 23.0), 0.35)
	chair(Vector3(7.8, h, 20.6), 2.5)
	figure(Vector3(4.6, h, 21.5), 0.4, 1.0, Color(0.4, 0.33, 0.28))
	corner_towers(1.5, 8.5, 11.0, 25.0, h, h + 2.6, 1.1)

func hall() -> void:
	var h := 0.3
	room(16.0, 9.5, 23.5, 37.0, h, {"w": [1.4, [[16.2, 18.8], [28.8, 31.2]]], "e": [1.4, [[19.6, 23.4], [32.6, 35.2]]], "s": [1.0]})
	carpet(18.4, 15.0, 21.1, 33.5, h)
	for z in [16.0, 21.0, 26.0, 31.0]:
		for x in [17.0, 22.5]:
			tower(x, z, h, h + 1.7, 0.7)
			candle(Vector3(x, h + 2.05, z), 0.2, true, 1.2)
	figure(Vector3(19.7, h, 19.0), PI * 0.2, 1.15, Color(0.55, 0.5, 0.42))
	figure(Vector3(22.0, h, 24.5), -PI * 0.5, 1.0, Color(0.45, 0.42, 0.4))
	figure(Vector3(17.6, h, 34.0), PI * 0.8, 1.15, Color(0.5, 0.46, 0.4))
	candelabra(Vector3(17.2, h, 23.5))
	candelabra(Vector3(22.4, h, 28.6))
	statue(Vector3(19.7, h, 35.6), PI, 1.3)

func ruin() -> void:
	var h := -0.2
	room(0.5, 25.0, 16.0, 35.0, h, {"w": [1.6], "n": [1.8, [[4.0, 6.2], [11.0, 16.0]]], "s": [1.3], "e": [1.4, [[28.8, 31.2]]]})
	for x in [2.5, 5.0, 7.5]:
		arch(Vector3(x, h, 25.4), 0.0, 1.8, 2.4)
	statue(Vector3(4.0, h, 29.5), 0.3, 2.4)
	candles(Vector3(2.4, h, 30.6), 6, 0.35)
	candles(Vector3(5.8, h, 30.8), 5, 0.3)
	rubble(Vector3(10.5, h, 27.5), 1.2, 18)
	rubble(Vector3(13.8, h, 33.6), 0.9, 12)
	wall(Vector2(9.5, 31.0), Vector2(13.5, 31.0), h, 1.3, 0.45)
	tower(1.3, 34.2, h, h + 2.4, 1.3)
	tower(15.2, 34.2, h, h + 1.8, 1.1)
	figure(Vector3(8.8, h, 33.0), 0.2, 1.0, Color(0.44, 0.4, 0.36))
	crate(Vector3(14.6, h, 26.2))
	barrel(Vector3(13.8, h, 26.0))

func chapel() -> void:
	var h := 2.0
	room(29.5, 2.0, 43.5, 17.0, h, {"n": [4.1], "w": [1.8, [[3.6, 5.8]]], "e": [1.8, [[9.0, 11.0]]], "s": [1.2, [[36.8, 40.2]]]})
	# altar niche with a pale statue
	box("brick", Vector3(36.5, h + 2.3, 2.6), Vector3(4.0, 4.6, 0.9), jit(STONE, 0.04))
	arch(Vector3(36.5, h + 0.6, 3.1), 0.0, 2.2, 3.2, Color(0.45, 0.22, 0.08))
	statue(Vector3(36.5, h + 0.6, 3.7), 0.0, 2.0)
	box("stone", Vector3(36.5, h + 0.3, 3.6), Vector3(4.2, 0.6, 2.0), jit(STONE, 0.05))
	for i in 5:
		arch(Vector3(31.0 + i * 1.3, h, 2.5), 0.0, 1.0, 2.6, Color(0.0, 0.0, 0.0))
		arch(Vector3(39.4 + i * 0.9, h, 2.5), 0.0, 0.8, 2.6, Color(0.0, 0.0, 0.0))
	box("stone", Vector3(36.5, h + 0.45, 6.4), Vector3(3.0, 0.9, 1.2), jit(STONE, 0.05))
	add_block(36.5, 6.4, 1.6)
	box("carpet", Vector3(36.5, h + 0.91, 6.4), Vector3(3.1, 0.02, 0.6), Kit.RED_CLOTH)
	candles(Vector3(35.4, h + 0.9, 6.2), 6, 0.35)
	candles(Vector3(37.6, h + 0.9, 6.2), 6, 0.35)
	candles(Vector3(34.2, h + 0.6, 3.9), 5, 0.3)
	candles(Vector3(38.8, h + 0.6, 3.9), 5, 0.3)
	for x in [33.2, 39.8]:
		candelabra(Vector3(x, h, 6.4))
	carpet(35.4, 7.6, 37.6, 16.8, h)
	for z in [9.5, 13.0]:
		figure(Vector3(33.5, h, z), PI * 0.5, 1.0, Color(0.5, 0.46, 0.42))
		figure(Vector3(40.0, h, z), -PI * 0.5, 1.0, Color(0.46, 0.42, 0.4))
	for z in [8.0, 11.0, 14.0]:
		for x in [31.2, 41.8]:
			box("wood", Vector3(x, h + 0.25, z), Vector3(1.8, 0.1, 0.5), jit(Kit.WOOD, 0.1))
			box("wood", Vector3(x, h + 0.12, z), Vector3(1.6, 0.24, 0.1), Kit.WOOD_DARK)
	corner_towers(29.5, 2.0, 43.5, 17.0, h, h + 4.4, 1.3)

func treasury() -> void:
	var h := 1.6
	room(42.5, 4.0, 53.5, 18.5, h, {"n": [3.4], "e": [1.6], "s": [1.2], "w": [1.6, [[9.0, 11.0]]]})
	for i in 4:
		arch(Vector3(45.5 + i * 2.2, h, 4.5), 0.0, 1.4, 2.4, Color(0.9, 0.42, 0.1))
	for i in 3:
		light(Vector3(46.6 + i * 2.2, h + 1.6, 5.6), 1.8, 4.0, Color(1.0, 0.5, 0.2))
	gold_pile(Vector3(47.2, h, 8.5), 1.6, 160)
	gold_pile(Vector3(50.5, h, 9.5), 1.2, 110)
	gold_pile(Vector3(49.0, h, 13.0), 0.9, 60)
	light(Vector3(48.5, h + 1.4, 9.5), 3.0, 5.0, Color(1.0, 0.7, 0.35))
	chest(Vector3(52.4, h, 7.0), -PI * 0.5, true)
	chest(Vector3(45.0, h, 12.0), PI * 0.5, true)
	chest(Vector3(52.4, h, 14.5), -PI * 0.5)
	for p in [Vector3(46.2, h, 15.8), Vector3(51.0, h, 16.4)]:
		figure(p, PI + r(-0.4, 0.4), 1.0, Color(0.5, 0.44, 0.36))
	for i in 5:
		box("wood", Vector3(53.0, h + 0.4 + i * 0.35, 11.5), Vector3(0.3, 0.05, 2.4), jit(Kit.WOOD, 0.1))
	candelabra(Vector3(44.6, h, 16.8))
	candles(Vector3(52.6, h, 17.4), 4, 0.25)
	corner_towers(42.5, 4.0, 53.5, 18.5, h, h + 3.6, 1.2)

func mechanism() -> void:
	var c := Vector2(38.5, 24.0)
	var h := 0.6
	var rad := 5.8
	cyl("brick", Vector3(c.x, h - 0.7, c.y), rad, 1.2, jit(Kit.STONE_DARK, 0.04), "cyl24")
	cyl("stone", Vector3(c.x, h - 1.45, c.y), rad - 0.3, 0.3, Kit.STONE_DARK.darkened(0.2), "cyl24")
	cyl("flag", Vector3(c.x, h - 0.06, c.y), rad - 0.1, 0.12, jit(Kit.FLAG, 0.05), "cyl24")
	add_walk(Walk.circle(c, rad - 0.7, h))
	# concentric brass rings and spokes inlaid in the floor
	for rr in [1.6, 2.6, 3.6, 4.5]:
		put("torus", "brass", Transform3D(Basis.from_scale(Vector3(rr * 2.0 + 0.2, 0.25, rr * 2.0 + 0.2)), Vector3(c.x, h, c.y)), jit(Kit.BRASS, 0.05))
	for i in 16:
		var a := i * TAU / 16.0
		var p := c + Vector2(cos(a), sin(a)) * 3.05
		box("brass", Vector3(p.x, h + 0.01, p.y), Vector3(2.9, 0.05, 0.1), Kit.BRASS, -a)
	cyl("iron", Vector3(c.x, h + 0.02, c.y), 1.5, 0.06, Kit.IRON)
	# central engine
	cyl("iron", Vector3(c.x, h + 0.5, c.y), 0.9, 1.0, Kit.IRON, "cyl24")
	cyl("brass", Vector3(c.x, h + 1.05, c.y), 0.95, 0.12, Kit.BRASS, "cyl24")
	cyl("iron", Vector3(c.x, h + 1.75, c.y), 0.6, 1.3, Kit.IRON.lightened(0.1), "cyl24")
	cyl("brass", Vector3(c.x, h + 2.45, c.y), 0.66, 0.1, Kit.BRASS, "cyl24")
	shape("sphere", "brass", Vector3(c.x, h + 2.55, c.y), Vector3(1.0, 0.7, 1.0), Kit.BRASS.darkened(0.2))
	cyl("iron", Vector3(c.x, h + 3.0, c.y), 0.12, 0.6, Kit.IRON)
	for i in 4:
		var a := i * TAU / 4.0 + 0.4
		var p := c + Vector2(cos(a), sin(a)) * 1.2
		shape("cyl", "brass", Vector3(p.x, h + 0.9, p.y), Vector3(0.9, 0.12, 0.9), Kit.BRASS, -a, 0.0, PI * 0.5)
		for k in 10:
			var t := k * TAU / 10.0
			box("brass", Vector3(p.x, h + 0.9, p.y) + Basis.from_euler(Vector3(0, -a, 0)) * Vector3(0, sin(t) * 0.5, cos(t) * 0.5), Vector3(0.12, 0.1, 0.1), Kit.BRASS, -a)
	add_block(c.x, c.y, 1.4)
	candles(Vector3(c.x + 1.2, h + 1.12, c.y + 0.3), 3, 0.15, 0.8)
	# low ring parapet with gaps for the four exits
	var n := 54
	for i in n:
		var a := i * TAU / n
		var gapped := false
		for g in [PI, 0.0, -PI * 0.5, PI * 0.5]:
			if absf(angle_difference(a, g)) < 0.24:
				gapped = true
		if gapped:
			continue
		var p := c + Vector2(cos(a), sin(a)) * (rad - 0.25)
		var bh := r(0.35, 0.55)
		box("stone", Vector3(p.x, h + bh * 0.5, p.y), Vector3(0.62, bh, 0.42), jit(Kit.STONE, 0.15), -a + PI * 0.5)
		if i % 9 == 4:
			candle(Vector3(p.x, h + bh, p.y), 0.25, true, 1.0)
	for i in 6:
		var a := i * TAU / 6.0 + 0.3
		var p := c + Vector2(cos(a), sin(a)) * (rad - 1.5)
		pier(p.x, p.y, h - 1.45, 1.3)
	for p in [Vector2(-3.3, 2.0), Vector2(3.0, -2.6), Vector2(3.2, 2.8)]:
		figure(Vector3(c.x + p.x, h, c.y + p.y), atan2(p.x, p.y) + PI, 1.0, Color(0.48, 0.44, 0.4))
	for i in 4:
		var a := i * TAU / 4.0 + PI * 0.25
		var p := c + Vector2(cos(a), sin(a)) * (rad - 0.9)
		candelabra(Vector3(p.x, h, p.y), 0.9)

func barracks() -> void:
	var h := -0.4
	room(35.0, 30.5, 53.5, 43.0, h, {"w": [1.6, [[32.0, 35.0], [37.8, 40.4]]], "n": [1.7, [[36.8, 40.2], [48.8, 53.0]]], "e": [1.6], "s": [1.2]})
	# east landing reaching up to the mechanism bridge
	room(48.5, 20.0, 53.5, 30.6, h, {"e": [1.4], "w": [1.2, [[21.0, 24.0]]]})
	for z in [32.5, 35.0]:
		table(Vector3(44.0, h, z + 0.5), 2.2, 0.9)
		chair(Vector3(43.2, h, z + 1.3), PI)
		chair(Vector3(44.8, h, z - 0.3), 0.0)
		candles(Vector3(44.0, h + 0.6, z + 0.5), 2, 0.15)
	for i in 4:
		var x := 37.0 + i * 1.6
		box("wood", Vector3(x, h + 0.3, 41.6), Vector3(1.0, 0.3, 1.9), jit(Kit.WOOD, 0.1))
		box("cloth", Vector3(x, h + 0.48, 41.8), Vector3(0.9, 0.08, 1.5), jit(Color(0.35, 0.22, 0.15), 0.2))
		add_block(x, 41.6, 0.8)
	for p in [Vector2(50.5, 34.0), Vector2(51.6, 37.0), Vector2(47.0, 39.0), Vector2(40.0, 34.0), Vector2(51.0, 25.0)]:
		figure(Vector3(p.x, h, p.y), r(0, TAU), 1.0, jit(Color(0.45, 0.42, 0.38), 0.1))
	statue(Vector3(52.0, h, 31.8), -PI * 0.7, 1.5)
	for i in 6:
		crate(Vector3(36.3 + r(0, 1.5), h, 37.0 + r(0, 2.5)), r(0.3, 0.5))
	barrel(Vector3(48.6, h, 41.8))
	barrel(Vector3(49.2, h, 42.2))
	chest(Vector3(52.2, h, 41.5), -PI * 0.5)
	box("wood", Vector3(47.5, h + 0.55, 31.4), Vector3(2.4, 1.1, 0.3), Kit.WOOD_DARK)
	for i in 5:
		box("iron", Vector3(46.5 + i * 0.5, h + 0.9, 31.6), Vector3(0.04, 1.2, 0.04), Color(0.6, 0.58, 0.55), 0.0, 0.0, 0.1)
	candelabra(Vector3(38.0, h, 31.8))
	candelabra(Vector3(50.0, h, 40.0))
	candles(Vector3(36.0, h, 42.2), 3, 0.2)
	corner_towers(35.0, 30.5, 53.5, 43.0, h, h + 2.4, 1.1)

func lift() -> void:
	var y := 0.05
	var x0 := 25.4
	var x1 := 30.4
	var z0 := 28.4
	var z1 := 33.7
	box("wood", Vector3((x0 + x1) * 0.5, y - 0.12, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.2, z1 - z0), jit(Kit.WOOD, 0.05))
	var k := x0 + 0.2
	while k < x1:
		box("wood", Vector3(k, y - 0.01, (z0 + z1) * 0.5), Vector3(0.36, 0.04, z1 - z0 - 0.1), jit(Kit.WOOD, 0.2))
		k += 0.4
	box("brass", Vector3((x0 + x1) * 0.5, y + 0.02, (z0 + z1) * 0.5), Vector3(2.4, 0.03, 2.4), Kit.BRASS.darkened(0.15), PI * 0.25)
	for zz in [z0, z1]:
		box("brass", Vector3((x0 + x1) * 0.5, y - 0.1, zz), Vector3(x1 - x0 + 0.2, 0.3, 0.2), Kit.BRASS)
	for xx in [x0, x1]:
		box("brass", Vector3(xx, y - 0.1, (z0 + z1) * 0.5), Vector3(0.2, 0.3, z1 - z0), Kit.BRASS)
	for p in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
		box("brass", Vector3(p.x, y + 0.15, p.y), Vector3(0.4, 0.4, 0.4), Kit.BRASS.lightened(0.1))
	for p in [Vector2(x0, z0), Vector2(x1, z1)]:
		chain(Vector3(p.x, y - 0.3, p.y), Vector3(p.x, -12.0, p.y))
	add_walk(Walk.rect(x0, z0, x1, z1, y, 0.1))
	light(Vector3((x0 + x1) * 0.5, y + 1.0, (z0 + z1) * 0.5), 1.0, 4.0)

func connections() -> void:
	# bridges (world coordinates; rooms are already placed)
	bridge(Vector3(21.8, 2.0, 2.3), Vector3(31.7, 2.0, 2.3), 1.8, true, true, -40.0)
	bridge(Vector3(23.3, 0.3, 21.5), Vector3(34.9, 0.6, 21.5), 3.6, true, true, -40.0)
	bridge(Vector3(10.8, 0.8, 17.5), Vector3(16.2, 0.3, 17.5), 2.4, true, false, -40.0)
	bridge(Vector3(23.3, 0.3, 34.4), Vector3(37.7, -0.4, 34.4), 1.8, false, true, -40.0)
	bridge(Vector3(46.1, 0.6, 24.0), Vector3(51.2, -0.4, 24.0), 2.8, true, true, -40.0)
	bridge(Vector3(37.7, -0.4, 40.6), Vector3(31.5, -0.6, 40.6), 2.4, true, true, -40.0)
	# timber landing at the end of the low bridge
	box("wood", Vector3(30.5, -0.75, 40.6), Vector3(2.4, 0.2, 3.0), Kit.WOOD)
	add_walk(Walk.rect(29.3, 39.1, 31.7, 42.1, -0.6, 0.2))
	trestle(Vector3(30.5, -0.6, 40.6), Vector3(0, 0, 1), 2.4, -40.0)
	for p in [Vector2(29.4, 39.2), Vector2(31.6, 39.2), Vector2(29.4, 42.0)]:
		box("wood", Vector3(p.x, -0.2, p.y), Vector3(0.18, 1.1, 0.18), Kit.WOOD_DARK)
	candles(Vector3(29.7, -0.65, 41.7), 3, 0.15)
	# stairs and door ramps between rooms (stairs() also adds the walk ramp)
	stairs(39.0, 14.6, 42.0, 18.6, 2.0, 0.6, false)
	stairs(39.3, 29.4, 42.3, 32.4, 0.6, -0.4, false)
	stairs(10.8, 3.0, 12.5, 5.0, 3.0, 2.0, true)
	stairs(3.8, 7.4, 5.7, 9.6, 3.0, 0.8, false)
	stairs(16.9, 9.0, 19.5, 10.8, 2.0, 0.3, false)
	stairs(4.0, 24.4, 6.2, 25.9, 0.8, -0.2, false)
	add_walk(Walk.ramp(15.3, 28.8, 16.7, 31.2, -0.2, 0.3, true))
	add_walk(Walk.ramp(44.8, 7.5, 46.3, 9.0, 2.0, 1.6, true))
	add_walk(Walk.ramp(51.3, 31.3, 55.5, 32.8, -0.4, -0.4, false))
	# timber and brass scaffolding standing in the gaps between rooms
	for p in [Vector2(13.5, 21.0), Vector2(26.5, 6.0), Vector2(28.0, 25.5), Vector2(33.0, 30.0), Vector2(48.5, 27.5), Vector2(24.5, 38.5), Vector2(34.0, 42.5), Vector2(27.5, 17.0), Vector2(48.5, 19.5)]:
		trestle(Vector3(p.x, -1.2, p.y), Vector3(1, 0, 0), 1.6, -40.0)
	# hanging chains below the lift
	for x in [24.0, 31.0]:
		chain(Vector3(x, -0.5, 33.3), Vector3(x, -14.0, 33.3))

func backdrop() -> void:
	# A gothic city falling away into the abyss: huge piers, arches and walls.
	var col := Color(0.24, 0.21, 0.2)
	for i in 14:
		var x := -12.0 + i * 6.0 + r(-1.5, 1.5)
		var z := -12.0 - r(0.0, 10.0)
		var w := r(2.0, 3.5)
		var top := r(-4.0, 16.0)
		box("brick", Vector3(x, (top - 70.0) * 0.5, z), Vector3(w, top + 70.0, w), jit(col, 0.1))
		tower(x, z, top - 0.5, top, w + 0.4, col)
		if i < 13:
			for k in 3:
				var y := top - 6.0 - k * 9.0
				arch(Vector3(x + 3.0, y, z + 0.5), 0.0, 3.4, 5.5, Color(0, 0, 0), col)
	for i in 7:
		light(Vector3(-8.0 + i * 11.0, r(-2.0, 4.0), -9.0), 3.0, 12.0, Color(1.0, 0.6, 0.35))
	for i in 10:
		var x := -10.0 + i * 8.0 + r(-2.0, 2.0)
		var z := r(20.0, 60.0)
		if x > -2.0 and x < 58.0:
			continue
		var top := r(-10.0, 6.0)
		box("brick", Vector3(x, (top - 70.0) * 0.5, z), Vector3(3.0, top + 70.0, 3.0), jit(col, 0.1))
		tower(x, z, top - 0.5, top, 3.4, col)
	# deep floor-level structures far below
	for i in 26:
		var x := r(-10.0, 66.0)
		var z := r(-6.0, 60.0)
		var top := r(-46.0, -24.0)
		var w := r(2.0, 5.0)
		box("brick", Vector3(x, top - 20.0, z), Vector3(w, 40.0, w * r(0.8, 2.0)), jit(col.darkened(0.2), 0.1))
	for i in 16:
		light(Vector3(r(-5.0, 60.0), r(-22.0, -8.0), r(0.0, 50.0)), 12.0, 20.0, Color(0.6, 0.62, 0.75))
	for i in 6:
		var p := Vector3(r(-12.0, 66.0), r(-30.0, -8.0), r(-20.0, 60.0))
		if p.x > 0.0 and p.x < 55.0 and p.z > 0.0:
			continue
		candles(p, 2, 0.3, 1.5)
