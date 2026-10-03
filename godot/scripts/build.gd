class_name Build
extends RefCounted
## Turns a resolved Layout into instanced geometry: flagstone floors, coursed
## walls with crenellations, corner towers, corbels and slender piers that
## run down into the abyss (open shafts between them), and the bridge, stair,
## walkway and girder for each link.

const FLAG := 0.3           # flagstone module (flags are 1-4 modules a side)
const SLAB := 0.55          # floor slab under the tiles
const TILE_H := 0.12
const COURSE := 0.5         # mean course height of the ashlar
const STONE := Color(0.47, 0.42, 0.37)
const STONE_WARM := Color(0.5, 0.43, 0.36)
const DEEP_BLOCKS := -22.0  # below this, pillars are plain masonry hidden in fog

var kit: Kit
var layout: Layout


func _init(k: Kit, l: Layout) -> void:
	kit = k
	layout = l


func all() -> void:
	for r in layout.rooms:
		room(r)
	for l in layout.links:
		link(l)


# ------------------------------------------------------------------- rooms

func room(r: Layout.Room) -> void:
	if r.round:
		_round_floor(r)
		_round_wall(r)
	else:
		_floor(r)
		if r.opts.get("theme", "stone") == "stone":
			for side in Layout.SIDES:
				_side_walls(r, side)
			for corner in r.opts.get("towers", {}):
				_tower(r, corner, r.opts.towers[corner])
		else:
			_rails(r)
	match r.support:
		"pillar":
			if r.round:
				_round_pillar(r)
			else:
				_pillar(r)
		"posts":
			_posts(r)
		"links":
			pass


func _floor(r: Layout.Room) -> void:
	var inner := r.inner()
	var theme: String = r.opts.get("theme", "stone")
	# Bedding under the floor (shows as dark mortar between tiles).
	kit.put("box", "stone_dark", Vector3(inner.get_center().x, r.y - SLAB * 0.5 - TILE_H * 0.5, inner.get_center().y),
		Vector3(inner.size.x, SLAB - TILE_H, inner.size.y), 0.0, Color(0.32, 0.3, 0.29))
	if theme == "wood" or theme == "iron":
		_deck(r.rect.grow(-0.05), r.y, theme)
		return
	_tiles(inner, r.y)
	for e in r.extra_floor:
		var c := e.get_center()
		kit.put("box", "stone_dark", Vector3(c.x, r.y - SLAB * 0.5 - TILE_H * 0.5, c.y), Vector3(e.size.x, SLAB - TILE_H, e.size.y), 0.0, Color(0.32, 0.3, 0.29))
		_tiles(e, r.y)
	_slab_edges(r)
	_debris(r)


## Random-pattern flagging: rectangles of one to four modules a side packed
## greedily over a fine grid, so large and small flags mix and the joints never
## line up into a grid, with the odd broken flag.
func _tiles(area: Rect2, top: float, mat := "floor") -> void:
	var nx := maxi(1, roundi(area.size.x / FLAG))
	var nz := maxi(1, roundi(area.size.y / FLAG))
	var cw := area.size.x / nx
	var cd := area.size.y / nz
	var used := {}
	for iz in nz:
		for ix in nx:
			if used.has(Vector2i(ix, iz)):
				continue
			var w := _flag_span(nx - ix)
			var d := _flag_span(nz - iz)
			# Shrink to fit around flags already laid.
			for k in range(1, w):
				if used.has(Vector2i(ix + k, iz)):
					w = k
					break
			var free := false
			while not free:
				free = true
				for jz in d:
					for jx in w:
						if used.has(Vector2i(ix + jx, iz + jz)):
							free = false
				if not free:
					d -= 1
			for jz in d:
				for jx in w:
					used[Vector2i(ix + jx, iz + jz)] = true
			var rect := Rect2(area.position.x + ix * cw, area.position.y + iz * cd, cw * w, cd * d)
			if kit.rng.randf() < 0.025:
				_broken(rect, top)
			else:
				_tile(rect, top, mat)


## Flagstone side in modules: mostly two or three, some four, the odd one.
func _flag_span(room: int) -> int:
	var r := kit.rng.randf()
	var n := 1 if r < 0.12 else (2 if r < 0.5 else (3 if r < 0.85 else 4))
	return mini(n, room)


func _tile(rect: Rect2, top: float, mat: String) -> void:
	var gap := 0.05
	var h := TILE_H + kit.jitter(0.018)
	var c := rect.get_center()
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(kit.jitter(1.8))) * Basis(Vector3.FORWARD, deg_to_rad(kit.jitter(1.8)))
	var basis := Basis(Vector3.UP, deg_to_rad(kit.jitter(0.8))) * tilt
	var col := kit.tint(STONE * (0.72 if kit.rng.randf() < 0.12 else 1.0), 0.26, 0.04)
	kit.piece("slab", mat, Vector3(c.x, top - h * 0.5 + kit.jitter(0.018), c.y),
		Vector3(rect.size.x - gap - kit.rng.randf_range(0.0, 0.03), h, rect.size.y - gap - kit.rng.randf_range(0.0, 0.03)), basis, col)


func _broken(rect: Rect2, top: float) -> void:
	for i in 3 + kit.rng.randi() % 3:
		var s := kit.rng.randf_range(0.08, 0.2)
		var c := rect.position + Vector2(kit.rng.randf(), kit.rng.randf()) * rect.size
		kit.piece("block", "floor", Vector3(c.x, top - 0.06 + s * 0.3, c.y), Vector3(s, s * 0.7, s * kit.rng.randf_range(0.7, 1.3)),
			Basis.from_euler(Vector3(kit.jitter(0.5), kit.rng.randf() * TAU, kit.jitter(0.5))), kit.tint(STONE, 0.2))


## Plank deck for wooden or iron platforms (lift, dock).
func _deck(area: Rect2, top: float, theme: String) -> void:
	if theme == "iron":
		# Riveted iron plates.
		var nx := maxi(1, roundi(area.size.x / 0.7))
		var nz := maxi(1, roundi(area.size.y / 0.7))
		for iz in nz:
			for ix in nx:
				var c := area.position + Vector2((ix + 0.5) * area.size.x / nx, (iz + 0.5) * area.size.y / nz)
				kit.put("slab", "statue", Vector3(c.x, top - 0.03, c.y), Vector3(area.size.x / nx - 0.03, 0.06, area.size.y / nz - 0.03), 0.0, kit.tint(Color(1.25, 0.95, 0.7), 0.15))
				for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
					var rp: Vector2 = c + q * Vector2(area.size.x / nx, area.size.y / nz) * 0.4
					kit.put("sphere", "brass", Vector3(rp.x, top + 0.005, rp.y), Vector3(0.05, 0.03, 0.05))
	else:
		var n := maxi(1, int(area.size.x / 0.24))
		var w := area.size.x / n
		for i in n:
			var x := area.position.x + (i + 0.5) * w
			kit.piece("plank", "wood", Vector3(x, top - 0.04, area.get_center().y), Vector3(w - 0.02, 0.07, area.size.y - kit.rng.randf_range(0.0, 0.08)),
				Basis(Vector3.FORWARD, deg_to_rad(kit.jitter(1.0))), kit.tint(Color(1, 1, 1), 0.2))
	var mat := "iron" if theme == "iron" else "wood_dark"
	var c0 := area.get_center()
	for z in [area.position.y + 0.07, area.end.y - 0.07]:
		kit.put("plank", mat, Vector3(c0.x, top - 0.17, z), Vector3(area.size.x + 0.1, 0.26, 0.16))
	for x in [area.position.x + 0.07, area.end.x - 0.07]:
		kit.put("plank", mat, Vector3(x, top - 0.17, c0.y), Vector3(0.16, 0.26, area.size.y))
	for i in range(1, 4):
		kit.put("plank", mat, Vector3(c0.x, top - 0.2, area.position.y + area.size.y * i / 4.0), Vector3(area.size.x, 0.18, 0.12))
	if theme == "iron":
		# Brass-bound plate with a cross of straps, as on the reference's lift.
		var c := area.get_center()
		kit.put("box", "brass", Vector3(c.x, top + 0.005, c.y), Vector3(area.size.x * 0.96, 0.02, 0.07))
		kit.put("box", "brass", Vector3(c.x, top + 0.005, c.y), Vector3(0.07, 0.02, area.size.y * 0.96))
		for corner in [Vector2(0.05, 0.05), Vector2(0.95, 0.05), Vector2(0.05, 0.95), Vector2(0.95, 0.95)]:
			var p: Vector2 = area.position + area.size * corner
			kit.put("cyl", "brass", Vector3(p.x, top + 0.12, p.y), Vector3(0.36, 0.24, 0.36))
			kit.put("cyl", "iron", Vector3(p.x, top + 0.26, p.y), Vector3(0.12, 0.08, 0.12))


## Outer face of the floor slab where no wall stands on it.
func _slab_edges(r: Layout.Room) -> void:
	for side in Layout.SIDES:
		if r.walls.get(side, 0.0) > 0.0:
			continue
		var seg := _band(r, side)
		_course_wall(side, seg, r.y - SLAB, r.y, "stone")


# ------------------------------------------------------------------- walls

## Plan rectangle of a side's wall band (walls stand inside the room rect).
func _band(r: Layout.Room, side: String) -> Rect2:
	var R := r.rect
	var t := r.wall_t
	match side:
		"n":
			return Rect2(R.position.x, R.position.y, R.size.x, t)
		"s":
			return Rect2(R.position.x, R.end.y - t, R.size.x, t)
		"w":
			return Rect2(R.position.x, R.position.y + r.inset("n"), t, R.size.y - r.inset("n") - r.inset("s"))
		_:
			return Rect2(R.end.x - t, R.position.y + r.inset("n"), t, R.size.y - r.inset("n") - r.inset("s"))


func _tower_size(r: Layout.Room) -> float:
	return clampf(r.wall_t * 2.6, 1.0, 1.5)


func _side_walls(r: Layout.Room, side: String) -> void:
	var height: float = r.walls.get(side, 0.0)
	if height <= 0.0:
		return
	var band := _band(r, side)
	var along_x := side == "n" or side == "s"
	var lo := band.position.x if along_x else band.position.y
	var hi := band.end.x if along_x else band.end.y
	# Cut out corner towers and link openings.
	var cuts := []
	var ts := _tower_size(r)
	var towers: Dictionary = r.opts.get("towers", {})
	for corner: String in towers:
		var cz := corner[0]
		var cx := corner[1]
		if along_x and cz == side:
			cuts.append(Vector2(r.rect.position.x, r.rect.position.x + ts) if cx == "w" else Vector2(r.rect.end.x - ts, r.rect.end.x))
		elif not along_x and cx == side:
			cuts.append(Vector2(r.rect.position.y, r.rect.position.y + ts) if cz == "n" else Vector2(r.rect.end.y - ts, r.rect.end.y))
	var doors := []
	for o in r.openings_on(side):
		cuts.append(Vector2(o.lo, o.hi))
		doors.append(o)
	# Shared edges: the neighbour's wall stands there instead of ours.
	var under := []
	for sh in r.shared:
		if sh.side != side:
			continue
		if not sh.owner:
			cuts.append(Vector2(sh.lo, sh.hi))
		elif sh.other.y < r.y:
			under.append([Vector2(sh.lo, sh.hi), sh.other.y])
	var segments := _subtract(Vector2(lo, hi), cuts)
	var base := r.y - SLAB
	for seg in segments:
		var rect := Rect2(seg.x, band.position.y, seg.y - seg.x, band.size.y) if along_x \
			else Rect2(band.position.x, seg.x, band.size.x, seg.y - seg.x)
		# Carry the wall down to a lower neighbour's floor so nothing shows through.
		for u in under:
			var a := maxf(seg.x, u[0].x)
			var b := minf(seg.y, u[0].y)
			if b - a > 0.05:
				var ur := Rect2(a, band.position.y, b - a, band.size.y) if along_x else Rect2(band.position.x, a, band.size.x, b - a)
				_course_wall(side, ur, u[1] - SLAB, base, "stone")
		if side in r.opts.get("balustrade", []):
			_balustrade(side, rect, base, r.y, r.y + height)
			continue
		var notch := _notch(r, side, rect, height)
		_course_wall(side, rect, base, r.y + height, "stone", Vector2(0.55, 1.3), COURSE, notch)
		_crenellate(side, rect, r.y + height, notch)
		if notch != Vector3.ZERO:
			_rubble(r, side, band, notch)
		if height >= 1.0:
			_pilasters(side, rect, base, r.y + height, notch)
	for o in doors:
		_doorway(r, side, band, o, height)
	for f in r.opts.get("features", []):
		if f.side == side:
			_feature(r, side, band, f, height)


## A breach in some lower walls without features: the top broken down in
## steps over a metre or two (centre, half width, drop), as on the
## reference's ruined parapets. Vector3.ZERO for an intact wall.
func _notch(r: Layout.Room, side: String, rect: Rect2, height: float) -> Vector3:
	var along_x := side == "n" or side == "s"
	var length := rect.size.x if along_x else rect.size.y
	if length < 2.6 or height < 0.6 or height > 2.0 or kit.rng.randf() > 0.4:
		return Vector3.ZERO
	for f in r.opts.get("features", []):
		if f.side == side:
			return Vector3.ZERO
	var start := rect.position.x if along_x else rect.position.y
	var hw := kit.rng.randf_range(0.55, minf(1.2, length * 0.3))
	var at := kit.rng.randf_range(start + hw + 0.4, start + length - hw - 0.4)
	return Vector3(at, hw, height * kit.rng.randf_range(0.5, 0.8))


## Fallen stones at the foot of a breach, inside the room.
func _rubble(r: Layout.Room, side: String, band: Rect2, notch: Vector3) -> void:
	var along_x := side == "n" or side == "s"
	var into: float = 1.0 if side == "n" or side == "w" else -1.0
	var face: float
	match side:
		"n":
			face = band.end.y
		"s":
			face = band.position.y
		"w":
			face = band.end.x
		_:
			face = band.position.x
	for i in 4 + kit.rng.randi() % 4:
		var at := notch.x + kit.jitter(notch.y * 0.9)
		var off := face + into * kit.rng.randf_range(0.08, 0.7)
		var sz := kit.rng.randf_range(0.14, 0.34)
		var p := Vector3(at, 0, off) if along_x else Vector3(off, 0, at)
		kit.piece("block", "stone", p + Vector3(0, r.y + sz * 0.28, 0), Vector3(sz * kit.rng.randf_range(0.9, 1.6), sz * 0.65, sz),
			Basis.from_euler(Vector3(kit.jitter(0.35), kit.rng.randf() * TAU, kit.jitter(0.35))), kit.tint(STONE, 0.24, 0.05))


## Coursed ashlar filling a plan rectangle from y0 to y1, over a near-black
## core so the joints read as deep gaps. Course heights vary up the wall and
## block lengths along it; some blocks run through two courses, some stand
## proud or sit back, and a few are settled, shrunken or missing. A notch
## (centre, half width, drop along the wall) breaks the top down in steps.
func _course_wall(side: String, rect: Rect2, y0: float, y1: float, mat: String, block_len := Vector2(0.55, 1.3), course := COURSE, notch := Vector3.ZERO) -> void:
	var along_x := side == "n" or side == "s"
	var length := rect.size.x if along_x else rect.size.y
	var depth := rect.size.y if along_x else rect.size.x
	if length < 0.05 or y1 - y0 < 0.05:
		return
	var c := rect.get_center()
	var core := maxf(depth - 0.14, depth * 0.5)
	var lo := rect.position.x if along_x else rect.position.y
	var hi := lo + length
	if notch == Vector3.ZERO:
		_void_core(along_x, c, core, lo, hi, y0, y1 - 0.02)
	var rows := _courses(y1 - y0, course)
	var y := y0
	var reserved := []
	var carried := []
	for i in rows.size():
		var h: float = rows[i]
		var next_reserved := []
		var skipped := carried
		carried = []
		for seg in _subtract(Vector2(lo, hi), reserved):
			var cuts := _block_cuts(seg, block_len, seg.x <= lo + 0.001)
			for k in cuts.size() - 1:
				var a := cuts[k]
				var b := cuts[k + 1]
				var bh := h
				var double := i + 1 < rows.size() and b - a < block_len.y * 0.8 and kit.rng.randf() < 0.1
				if double:
					bh += rows[i + 1]
					next_reserved.append(Vector2(a, b))
				if notch != Vector3.ZERO and y + bh > y1 - _notch_drop(notch, (a + b) * 0.5) + 0.05:
					skipped.append(Vector2(a, b))
					if double:
						carried.append(Vector2(a, b))
					continue
				_ashlar(along_x, c, depth, a, b, y, bh, mat)
		if notch != Vector3.ZERO:
			for seg in _subtract(Vector2(lo, hi), skipped):
				_void_core(along_x, c, core, seg.x, seg.y, y, y + h)
		reserved = next_reserved
		y += h


## Depth of a wall-top notch at x along the wall: full in the middle,
## stepping out to nothing at its ends.
func _notch_drop(notch: Vector3, x: float) -> float:
	if notch == Vector3.ZERO:
		return 0.0
	return notch.z * clampf((1.0 - absf(x - notch.x) / notch.y) * 1.6, 0.0, 1.0)


## The near-black core behind a run of blocks, from a to b along the wall.
func _void_core(along_x: bool, c: Vector2, core: float, a: float, b: float, y0: float, y1: float) -> void:
	var mid := (a + b) * 0.5
	kit.put("box", "void", Vector3(mid if along_x else c.x, (y0 + y1) * 0.5, c.y if along_x else mid),
		Vector3(b - a if along_x else core, y1 - y0, core if along_x else b - a))


## Joint positions along a run of masonry: random block lengths, the first
## one staggered at a wall end, and no sliver left at the far end.
func _block_cuts(seg: Vector2, block_len: Vector2, stagger: bool) -> Array[float]:
	var cuts: Array[float] = [seg.x]
	var s := seg.x
	if stagger:
		s -= kit.rng.randf_range(0.0, block_len.x)
	while true:
		s += kit.rng.randf_range(block_len.x, block_len.y)
		if s >= seg.y - 0.18:
			break
		if s > cuts[-1] + 0.18:
			cuts.append(s)
	cuts.append(seg.y)
	return cuts


## One wall block between a and b along the wall, y to y + h, through the
## wall's depth: proud, set back, settled or (rarely) missing.
func _ashlar(along_x: bool, c: Vector2, depth: float, a: float, b: float, y: float, h: float, mat: String) -> void:
	if kit.rng.randf() < 0.012:
		return
	var gap := 0.045
	var thick := depth + kit.jitter(0.03)
	var out := kit.jitter(0.02)
	var r := kit.rng.randf()
	if r < 0.12:
		thick += kit.rng.randf_range(0.05, 0.12)
		out = kit.jitter(0.035)
	elif r < 0.22:
		thick -= kit.rng.randf_range(0.03, 0.07)
		out = kit.jitter(0.01)
	var shrink := 1.0
	var wob := 0.012
	if kit.rng.randf() < 0.06:
		shrink = kit.rng.randf_range(0.78, 0.92)
		wob = 0.045
	var bl := (b - a - gap) * shrink
	var bh := (h - gap) * shrink
	var mid := (a + b) * 0.5
	var cy := y + h * 0.5 - (h - gap - bh) * 0.4
	var pos := Vector3(mid, cy, c.y + out) if along_x else Vector3(c.x + out, cy, mid)
	var size := Vector3(bl, bh, thick) if along_x else Vector3(thick, bh, bl)
	var basis := Basis.from_euler(Vector3(kit.jitter(wob), kit.jitter(wob), kit.jitter(wob)))
	kit.piece("block", mat, pos, size, basis, kit.tint(STONE, 0.26, 0.05))


## Stone balustrade: plinth, turned balusters, heavy handrail.
func _balustrade(side: String, rect: Rect2, base: float, floor_y: float, top: float) -> void:
	var along_x := side == "n" or side == "s"
	var length := rect.size.x if along_x else rect.size.y
	var start := rect.position.x if along_x else rect.position.y
	var c := rect.get_center()
	_course_wall(side, rect, base, floor_y + 0.18, "stone")
	var rail_h := 0.16
	var n := maxi(2, int(length / 0.24))
	for i in n:
		var at := start + (i + 0.5) * length / n
		var p := Vector3(at, 0, c.y) if along_x else Vector3(c.x, 0, at)
		var h := top - rail_h - (floor_y + 0.18)
		kit.put("cyl8", "stone", p + Vector3(0, floor_y + 0.18 + h * 0.5, 0), Vector3(0.12, h, 0.12), 0.0, kit.tint(STONE, 0.1))
		kit.put("sphere", "stone", p + Vector3(0, floor_y + 0.18 + h * 0.45, 0), Vector3(0.17, 0.2, 0.17), 0.0, kit.tint(STONE, 0.1))
	var m := maxi(1, int(length / 0.8))
	for i in m:
		var at := start + (i + 0.5) * length / m
		var pos := Vector3(at, top - rail_h * 0.5, c.y) if along_x else Vector3(c.x, top - rail_h * 0.5, at)
		var size := Vector3(length / m - 0.03, rail_h, rect.size.y * 0.8) if along_x else Vector3(rect.size.x * 0.8, rail_h, length / m - 0.03)
		kit.piece("block", "stone", pos, size, Basis.IDENTITY, kit.tint(STONE, 0.15))


## Piers standing proud of both wall faces every couple of metres.
func _pilasters(side: String, rect: Rect2, y0: float, y1: float, notch := Vector3.ZERO) -> void:
	var along_x := side == "n" or side == "s"
	var length := rect.size.x if along_x else rect.size.y
	var depth := rect.size.y if along_x else rect.size.x
	if length < 1.6:
		return
	var n := maxi(1, roundi(length / 2.4))
	var start := rect.position.x if along_x else rect.position.y
	var c := rect.get_center()
	for i in range(1, n):
		var at := start + length * i / n + kit.jitter(0.1)
		if notch != Vector3.ZERO and absf(at - notch.x) < notch.y + 0.3:
			continue
		var pos := Vector3(at, (y0 + y1 + 0.2) * 0.5, c.y) if along_x else Vector3(c.x, (y0 + y1 + 0.2) * 0.5, at)
		var size := Vector3(0.42, y1 - y0 + 0.2, depth + 0.24) if along_x else Vector3(depth + 0.24, y1 - y0 + 0.2, 0.42)
		_column(pos, size)
		var cap := pos + Vector3(0, size.y * 0.5 + 0.08, 0)
		kit.put("block", "stone", cap, size * Vector3(1.15, 0.0, 1.1) + Vector3(0, 0.16, 0), kit.jitter(4.0), kit.tint(STONE, 0.2))
		if kit.rng.randf() < 0.3:
			Props.candles(kit, cap + Vector3(0, 0.08, 0), 2 + kit.rng.randi() % 2, 0.1)
			if kit.rng.randf() < 0.5:
				kit.light(cap + Vector3(0, 0.5, 0), Props.CANDLE_LIGHT, 1.4, 3.2)


## Capping course and merlons along a wall top, at an uneven rhythm: some
## merlons fallen, some broken down, some with a loose stone left on top.
func _crenellate(side: String, rect: Rect2, top: float, notch := Vector3.ZERO) -> void:
	var along_x := side == "n" or side == "s"
	var length := rect.size.x if along_x else rect.size.y
	var depth := rect.size.y if along_x else rect.size.x
	var start := rect.position.x if along_x else rect.position.y
	var c := rect.get_center()
	# Capping course: long stones of uneven thickness, slightly proud of the wall.
	var gap := Vector2(notch.x - notch.y, notch.x + notch.y)
	for seg in _subtract(Vector2(start, start + length), [gap] if notch != Vector3.ZERO else []):
		var cuts := _block_cuts(seg, Vector2(0.5, 1.1), true)
		for k in cuts.size() - 1:
			var mid := (cuts[k] + cuts[k + 1]) * 0.5
			var ch := kit.rng.randf_range(0.15, 0.21)
			var out := kit.jitter(0.03)
			var pos := Vector3(mid, top + ch * 0.5, c.y + out) if along_x else Vector3(c.x + out, top + ch * 0.5, mid)
			var w := cuts[k + 1] - cuts[k] - 0.05
			var d := depth + 0.1 + kit.jitter(0.03)
			var size := Vector3(w, ch, d) if along_x else Vector3(d, ch, w)
			kit.piece("block", "stone", pos, size, Basis.from_euler(Vector3(kit.jitter(0.025), kit.jitter(0.04), kit.jitter(0.025))), kit.tint(STONE, 0.24, 0.05))
	var s := start + kit.rng.randf_range(0.0, 0.35)
	while s < start + length - 0.3:
		var mw := minf(kit.rng.randf_range(0.42, 0.72), start + length - s)
		var r := kit.rng.randf()
		if notch != Vector3.ZERO and s < gap.y and s + mw > gap.x:
			r = 0.0
		if r >= 0.12:
			var mh := kit.rng.randf_range(0.3, 0.48)
			if r < 0.26:
				mh *= kit.rng.randf_range(0.45, 0.7)
			var mid := s + mw * 0.5
			var md := depth * kit.rng.randf_range(0.85, 1.0)
			var pos := Vector3(mid, top + 0.13 + mh * 0.5, c.y) if along_x else Vector3(c.x, top + 0.13 + mh * 0.5, mid)
			var size := Vector3(mw, mh, md) if along_x else Vector3(md, mh, mw)
			var wob := 0.05 if r < 0.26 else 0.025
			kit.piece("block", "stone", pos, size, Basis.from_euler(Vector3(kit.jitter(wob), kit.jitter(0.06), kit.jitter(wob))), kit.tint(STONE, 0.24, 0.05))
			if r >= 0.26 and kit.rng.randf() < 0.15:
				var sh := kit.rng.randf_range(0.16, 0.26)
				var p2 := pos + Vector3(kit.jitter(0.05), mh * 0.5 + sh * 0.5 + 0.01, kit.jitter(0.03))
				kit.piece("block", "stone", p2, size * Vector3(0.8, sh / mh, 0.8), Basis(Vector3.UP, kit.jitter(0.15)), kit.tint(STONE, 0.24, 0.05))
		s += mw + kit.rng.randf_range(0.26, 0.5)


## Jambs either side of an opening, and a lintel with wall above in tall walls.
func _doorway(r: Layout.Room, side: String, band: Rect2, o: Dictionary, height: float) -> void:
	var along_x := side == "n" or side == "s"
	var depth := band.size.y if along_x else band.size.x
	var c := band.get_center()
	var jamb_h := minf(height + 0.35, 2.4)
	for s in [o.lo - 0.16, o.hi + 0.16]:
		var pos := Vector3(s, r.y - SLAB + (jamb_h + SLAB) * 0.5, c.y) if along_x else Vector3(c.x, r.y - SLAB + (jamb_h + SLAB) * 0.5, s)
		var size := Vector3(0.32, jamb_h + SLAB, depth + 0.14) if along_x else Vector3(depth + 0.14, jamb_h + SLAB, 0.32)
		_column(pos, size)
	if height >= 2.0:
		var y0 := r.y + 2.05
		var rect := Rect2(o.lo, band.position.y, o.hi - o.lo, band.size.y) if along_x \
			else Rect2(band.position.x, o.lo, band.size.x, o.hi - o.lo)
		var mid: float = (o.lo + o.hi) * 0.5
		var lp := Vector3(mid, y0 + 0.14, c.y) if along_x else Vector3(c.x, y0 + 0.14, mid)
		var ls := Vector3(o.hi - o.lo + 0.5, 0.28, depth + 0.1) if along_x else Vector3(depth + 0.1, 0.28, o.hi - o.lo + 0.5)
		kit.piece("block", "stone", lp, ls, Basis.IDENTITY, kit.tint(STONE_WARM, 0.1))
		if height > 2.35:
			_course_wall(side, rect, y0 + 0.28, r.y + height, "stone")
			_crenellate(side, rect, r.y + height)
		# Pointed arch voussoirs under the lintel.
		_arch(Vector3(lp.x, r.y + 1.45, lp.z), o.hi - o.lo, 0.6, side, depth + 0.08, false)


## A column of stacked blocks (jambs, pilasters).
func _column(center: Vector3, size: Vector3, mat := "stone") -> void:
	var y := center.y - size.y * 0.5
	var top := center.y + size.y * 0.5
	while y < top - 0.03:
		var h := minf(COURSE * kit.rng.randf_range(0.7, 1.15), top - y)
		if top - (y + h) < 0.15:
			h = top - y
		kit.piece("block", mat, Vector3(center.x, y + h * 0.5, center.z), Vector3(size.x + kit.jitter(0.03), h - 0.04, size.z + kit.jitter(0.03)),
			Basis(Vector3.UP, kit.jitter(0.03)), kit.tint(STONE_WARM, 0.18))
		y += h


## Arch of wedge blocks springing at `spring` (centre between the jambs),
## span `width`, rise `rise`. On the inner wall face when `face` is set.
func _arch(spring: Vector3, width: float, rise: float, side: String, depth: float, recess: bool, mat := "stone") -> void:
	var along_x := side == "n" or side == "s"
	var n := 9
	for i in n:
		var t := (i + 0.5) / n
		var ang := lerpf(PI, 0.0, t)
		var x := cos(ang) * width * 0.5
		var y := sin(ang) * rise
		var pos := spring + (Vector3(x, y, 0) if along_x else Vector3(0, y, x))
		var tangent := Vector2(-sin(ang) * width * 0.5, cos(ang) * rise).normalized()
		var roll := atan2(tangent.y, tangent.x)
		var basis := Basis(Vector3.FORWARD, -roll) if along_x else Basis(Vector3.RIGHT, roll)
		var size := Vector3(width * 0.2, 0.2, depth) if along_x else Vector3(depth, 0.2, width * 0.2)
		kit.piece("block", mat, pos, size, basis, kit.tint(STONE_WARM, 0.12))
	if recess:
		pass


## Windows, blind arches, the chapel alcove and decorative door arches.
func _feature(r: Layout.Room, side: String, band: Rect2, f: Dictionary, height: float) -> void:
	var along_x := side == "n" or side == "s"
	var rng_lo := band.position.x if along_x else band.position.y
	var rng_hi := band.end.x if along_x else band.end.y
	# Spread features over the wall between any corner towers.
	var ts := _tower_size(r)
	for corner: String in r.opts.get("towers", {}):
		if (along_x and corner[0] == side) or (not along_x and corner[1] == side):
			var at_lo := (corner[1] == "w") if along_x else (corner[0] == "n")
			if at_lo:
				rng_lo += ts
			else:
				rng_hi -= ts
	var at: float = lerpf(rng_lo + 0.5, rng_hi - 0.5, f.t)
	# Inner face of the wall and the direction into the room.
	var into: Vector3 = {"n": Vector3(0, 0, 1), "s": Vector3(0, 0, -1), "w": Vector3(1, 0, 0), "e": Vector3(-1, 0, 0)}[side]
	var face_coord: float
	match side:
		"n":
			face_coord = band.end.y
		"s":
			face_coord = band.position.y
		"w":
			face_coord = band.end.x
		_:
			face_coord = band.position.x
	var base := Vector3(at, r.y, face_coord) if along_x else Vector3(face_coord, r.y, at)
	var kind: String = f.kind
	var w := 0.8
	var h := 1.3
	var y0 := 0.7
	match kind:
		"arch":
			w = 1.2
			h = 1.5
			y0 = 0.15
		"alcove":
			w = 1.9
			h = 2.6
			y0 = 0.35
		"door_arch":
			return
		"banner":
			var bh := minf(1.6, height - 0.3)
			var top := base + into * 0.06 + Vector3(0, height - 0.15, 0)
			kit.put("box", "iron", top, Vector3(0.9, 0.04, 0.05) if along_x else Vector3(0.05, 0.04, 0.9))
			kit.put("box", "cloth", top - Vector3(0, bh * 0.5, 0) + into * 0.01, Vector3(0.7, bh, 0.02) if along_x else Vector3(0.02, bh, 0.7))
			kit.put("cone", "brass", top - Vector3(0, bh + 0.08, 0) + into * 0.02, Vector3(0.12, 0.16, 0.12))
			return
		"sconce":
			var sp := base + into * 0.18 + Vector3(0, minf(1.6, height - 0.2), 0)
			kit.put("block", "iron", sp - into * 0.08, Vector3(0.12, 0.3, 0.12))
			kit.put("cyl8", "brass", sp + Vector3(0, 0.02, 0), Vector3(0.2, 0.05, 0.2))
			Props.candle(kit, sp + Vector3(0, 0.04, 0), 0.16, 0.04)
			kit.light(sp + into * 0.3 + Vector3(0, 0.3, 0), Props.CANDLE_LIGHT, 1.6, 3.5)
			return
	if y0 + h + 0.4 > height:
		h = height - y0 - 0.45
		if h < 0.6:
			return
	var panel_mat := "window_glow" if f.get("lit", false) else "void"
	if kind == "alcove":
		panel_mat = "stone_dark"
	# Recessed panel (slightly into the wall), then a proud frame.
	var panel_c := base + into * 0.02 + Vector3(0, y0 + h * 0.5, 0)
	var panel_s := Vector3(w, h, 0.04) if along_x else Vector3(0.04, h, w)
	kit.put("box", panel_mat, panel_c, panel_s, 0.0, Color(1, 1, 1) if panel_mat == "window_glow" else Color(0.6, 0.55, 0.5))
	var arch_spring := base + into * 0.06 + Vector3(0, y0 + h, 0)
	_arch(arch_spring, w + 0.2, w * 0.55, side, 0.14, false)
	if panel_mat == "window_glow" or kind == "alcove":
		var arch_fill := base + into * 0.025 + Vector3(0, y0 + h + w * 0.22, 0)
		kit.put("cyl8", panel_mat, arch_fill, Vector3(w * 0.75, 0.035, w * 0.75) if not along_x else Vector3(w * 0.75, 0.035, w * 0.75),
			0.0, Color(1, 1, 1) if panel_mat == "window_glow" else Color(0.6, 0.55, 0.5))
	for s in [-1.0, 1.0]:
		var off := Vector3(s * (w * 0.5 + 0.1), 0, 0) if along_x else Vector3(0, 0, s * (w * 0.5 + 0.1))
		var col_c := base + into * 0.08 + off + Vector3(0, y0 + h * 0.5 - 0.05, 0)
		_column(col_c, Vector3(0.18, h + 0.1, 0.16) if along_x else Vector3(0.16, h + 0.1, 0.18))
	# Sill.
	kit.put("block", "stone", base + into * 0.1 + Vector3(0, y0 - 0.05, 0), Vector3(w + 0.45, 0.12, 0.2) if along_x else Vector3(0.2, 0.12, w + 0.45))
	if panel_mat == "window_glow":
		# Mullion and transom bars.
		kit.put("box", "iron", panel_c + into * 0.02, Vector3(0.04, h, 0.03) if along_x else Vector3(0.03, h, 0.04))
		kit.put("box", "iron", panel_c + into * 0.02 + Vector3(0, h * 0.1, 0), Vector3(w, 0.04, 0.03) if along_x else Vector3(0.03, 0.04, w))
		kit.light(base + into * 0.6 + Vector3(0, y0 + h * 0.6, 0), Color(1.0, 0.6, 0.3), 0.8, 3.0)


func _subtract(range_: Vector2, cuts: Array) -> Array:
	var out := [range_]
	for c in cuts:
		var next := []
		for seg in out:
			if c.y <= seg.x or c.x >= seg.y:
				next.append(seg)
				continue
			if c.x > seg.x:
				next.append(Vector2(seg.x, c.x))
			if c.y < seg.y:
				next.append(Vector2(c.y, seg.y))
		out = next
	return out.filter(func(s): return s.y - s.x > 0.05)


# ------------------------------------------------------------------ towers

func _tower(r: Layout.Room, corner: String, height: float) -> void:
	var ts := _tower_size(r)
	var x0 := r.rect.position.x if corner[1] == "w" else r.rect.end.x - ts
	var z0 := r.rect.position.y if corner[0] == "n" else r.rect.end.y - ts
	var foot := Rect2(x0, z0, ts, ts)
	var base := r.y - SLAB
	var top := r.y + height
	_block_box(foot, base, top)
	# Corbelled crown and corner merlons.
	var crown := foot.grow(0.09)
	_block_box(crown, top, top + 0.3, Vector2(0.45, 0.8))
	for q in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var p: Vector2 = crown.position + (crown.size - Vector2(0.4, 0.4)) * q + Vector2(0.2, 0.2)
		kit.put("block", "stone", Vector3(p.x, top + 0.3 + 0.2, p.y), Vector3(0.38, 0.4, 0.38), kit.jitter(5.0), kit.tint(STONE, 0.15))
	kit.put("slab", "floor", Vector3(crown.get_center().x, top + 0.31, crown.get_center().y), Vector3(crown.size.x - 0.2, 0.04, crown.size.y - 0.2), 0.0, kit.tint(STONE, 0.1))
	if r.opts.get("tower_fire", false):
		Props.brazier(kit, Vector3(foot.get_center().x, top + 0.33, foot.get_center().y))
	elif height >= 3.3:
		# Gothic pinnacle on the tallest towers, as on the reference's chapel.
		var tc := foot.get_center()
		kit.put("block", "stone", Vector3(tc.x, top + 0.55, tc.y), Vector3(0.75, 0.5, 0.75), 0.0, kit.tint(STONE, 0.12))
		kit.put("spire", "stone", Vector3(tc.x, top + 1.35, tc.y), Vector3(0.85, 1.1, 0.85), 45.0, kit.tint(STONE, 0.12))
		kit.put("sphere", "brass", Vector3(tc.x, top + 1.95, tc.y), Vector3(0.14, 0.14, 0.14))


## Hollow-looking solid of blocks on all four faces between y0 and y1.
func _block_box(foot: Rect2, y0: float, y1: float, block_len := Vector2(0.5, 0.95), course := COURSE, mat := "stone") -> void:
	var t := 0.3
	_course_wall("n", Rect2(foot.position.x, foot.position.y, foot.size.x, t), y0, y1, mat, block_len, course)
	_course_wall("s", Rect2(foot.position.x, foot.end.y - t, foot.size.x, t), y0, y1, mat, block_len, course)
	_course_wall("w", Rect2(foot.position.x, foot.position.y + t, t, foot.size.y - 2 * t), y0, y1, mat, block_len, course)
	_course_wall("e", Rect2(foot.end.x - t, foot.position.y + t, t, foot.size.y - 2 * t), y0, y1, mat, block_len, course)


## Iron or timber railing around a platform (lift, dock), open at links.
func _rails(r: Layout.Room) -> void:
	var mat := "iron" if r.opts.get("theme") == "iron" else "wood_dark"
	var R := r.rect.grow(-0.08)
	var edges := {"n": [R.position, Vector2(R.end.x, R.position.y)], "s": [Vector2(R.position.x, R.end.y), R.end],
		"w": [R.position, Vector2(R.position.x, R.end.y)], "e": [Vector2(R.end.x, R.position.y), R.end]}
	for side in edges:
		var a: Vector2 = edges[side][0]
		var b: Vector2 = edges[side][1]
		var along_x: bool = side == "n" or side == "s"
		var cuts := []
		for o in r.openings_on(side):
			cuts.append(Vector2(o.lo, o.hi))
		var lo := a.x if along_x else a.y
		var hi := b.x if along_x else b.y
		for seg in _subtract(Vector2(lo, hi), cuts):
			var p0 := Vector3(seg.x, r.y, a.y) if along_x else Vector3(a.x, r.y, seg.x)
			var p1 := Vector3(seg.y, r.y, a.y) if along_x else Vector3(a.x, r.y, seg.y)
			var n := maxi(1, roundi((seg.y - seg.x) / 0.6))
			for i in n + 1:
				var p := p0.lerp(p1, float(i) / n)
				kit.put("box", mat, p + Vector3(0, 0.45, 0), Vector3(0.06, 0.9, 0.06))
				kit.put("box", "brass", p + Vector3(0, 0.92, 0), Vector3(0.1, 0.05, 0.1))
			for h in [0.88, 0.5]:
				kit.span("box", mat, p0 + Vector3(0, h, 0), p1 + Vector3(0, h, 0), Vector2(0.06, 0.06))
	if r.support == "links":
		# The lift hangs on chains that run down to counterweights below.
		for q in [R.position, Vector2(R.end.x, R.position.y), R.end, Vector2(R.position.x, R.end.y)]:
			chain(Vector3(q.x, r.y - 0.25, q.y), Vector3(q.x, r.y - 9.0 - kit.rng.randf() * 3.0, q.y))


## A hanging chain of alternating links from a to b.
func chain(a: Vector3, b: Vector3, size := 0.11) -> void:
	var d := b - a
	var length := d.length()
	if length < size:
		return
	var x := d / length
	var ref := Vector3.FORWARD if absf(x.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var y := x.cross(ref).normalized()
	var n := int(length / (size * 0.75))
	for i in n:
		var c := a + d * (i + 0.5) / n
		var yy := y if i % 2 == 0 else y.rotated(x, PI * 0.5)
		var zz := x.cross(yy)
		kit.piece("link", "iron", c, Vector3(size, size * 0.9, size * 0.62), Basis(x, yy, zz))
	kit.put("block", "iron", b - x * 0.15, Vector3(0.22, 0.3, 0.22))


# ----------------------------------------------------------------- pillars

## Corbel steps under the slab, then a few slender masonry piers (the
## corners, and every five metres or so along a front) running down into the
## abyss, so the shafts between the rooms stay open down to the dark. A room
## whose south edge overhangs a shaft (opts.open_s) stands there on timber
## posts instead. Narrow rooms carry their back rows on one central pier.
func _pillar(r: Layout.Room) -> void:
	var slab := r.y - SLAB
	var top := slab
	var foot := r.rect
	var open_s: bool = r.opts.get("open_s", false)
	for step in 3:
		var g := -0.22 * (step + 1)
		var f := foot.grow(g)
		if open_s:
			# Its south edge rests on a beam: the corbels step back from it,
			# leaving a thin rim over the shaft.
			f = foot.grow_individual(g, g, g, -1.0 - 0.5 * step)
		_block_box(f, top - 0.32, top, Vector2(0.7, 1.3), 0.32)
		top -= 0.32
	var base := foot.grow(-0.66)
	var front := _is_front(r)
	var p := clampf(minf(base.size.x, base.size.y) * 0.36, 1.3, 2.1)
	var pb := maxf(1.2, p * 0.85)
	var south := base.end.y
	if open_s:
		var zp := foot.end.y - 0.45
		var xs := _stations(foot.position.x + 0.45, foot.end.x - 0.45, 5.2)
		for x in xs:
			_post(Vector2(x, zp), slab)
		kit.span("plank", "wood_dark", Vector3(xs[0] - 0.25, slab - 0.17, zp), Vector3(xs[-1] + 0.25, slab - 0.17, zp), Vector2(0.3, 0.34))
		for i in range(1, xs.size()):
			_braces(xs[i - 1] + 0.15, xs[i] - 0.15, zp, slab, false)
	else:
		var xs := _stations(base.position.x + p * 0.5, base.end.x - p * 0.5, 5.2)
		if xs.size() == 2 and xs[1] - xs[0] < p:
			xs = [base.get_center().x]
		for i in xs.size():
			var pf := Rect2(xs[i] - p * 0.5, base.end.y - p, p, p)
			_pier(pf, top)
			if front and i % 2 == 0:
				_lantern(Vector3(xs[i] + kit.jitter(0.12), top - 1.7, pf.end.y - 0.16))
			if front and i > 0:
				_braces(xs[i - 1] + p * 0.5, xs[i] - p * 0.5, base.end.y - 0.2, top, true)
		south = base.end.y - p * 0.5
	# Back rows, hidden under the room: on the centre line or at the sides.
	var zn := base.position.y + pb * 0.5
	if south - zn < pb * 1.5:
		return
	var back_xs: Array[float] = [base.get_center().x]
	if base.size.x >= 6.5:
		back_xs = [base.position.x + pb * 0.5, base.end.x - pb * 0.5]
	var rows := _stations(zn, south, 7.5)
	rows.pop_back()
	for z in rows:
		for x in back_xs:
			_pier(Rect2(x - pb * 0.5, z - pb * 0.5, pb, pb), top, "stone_dark")


## True when no room stands south of r across its width: its south face is
## the one seen at the bottom of the view.
func _is_front(r: Layout.Room) -> bool:
	for o in layout.rooms:
		if o == r:
			continue
		var overlap := minf(o.rect.end.x, r.rect.end.x) - maxf(o.rect.position.x, r.rect.position.x)
		if o.rect.position.y >= r.rect.end.y - Layout.EPS and overlap > 1.0:
			return false
	return true


## Evenly spaced positions from a to b (both included), at most `gap` apart.
func _stations(a: float, b: float, gap: float) -> Array[float]:
	var out: Array[float] = []
	if b - a < 0.3:
		out.append((a + b) * 0.5)
		return out
	var n := maxi(1, ceili((b - a) / gap))
	for i in n + 1:
		out.append(lerpf(a, b, float(i) / n))
	return out


## A slender masonry pier from `top` down to the abyss floor: corner
## pilasters (the lit arrises) standing proud of recessed panels, a capital
## under the corbels and band courses every few metres; rougher courses
## lower down, then plain masonry lost in the haze. Piers hidden under a
## room (seen only down a shaft) are laid in the darker stone.
func _pier(foot: Rect2, top: float, mat := "stone") -> void:
	var cap := 0.34
	_block_box(foot.grow(0.1), top - cap, top, Vector2(0.45, 0.9), cap, mat)
	var y := top - cap
	var low := maxf(DEEP_BLOCKS, top - 14.0)
	var pil := clampf(foot.size.x * 0.26, 0.36, 0.5)
	_block_box(foot.grow(-0.15), low, y, Vector2(0.45, 1.0), 0.52, mat)
	for q in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var cx: float = foot.position.x + pil * 0.5 + (foot.size.x - pil) * q.x
		var cz: float = foot.position.y + pil * 0.5 + (foot.size.y - pil) * q.y
		_column(Vector3(cx, (low + y) * 0.5, cz), Vector3(pil, y - low, pil), mat)
	var b := y - kit.rng.randf_range(3.0, 4.5)
	while b > low + 1.5:
		_block_box(foot.grow(0.06), b - 0.3, b, Vector2(0.45, 0.9), 0.3, mat)
		b -= kit.rng.randf_range(4.5, 6.5)
	if low > DEEP_BLOCKS:
		_block_box(foot, DEEP_BLOCKS, low, Vector2(1.0, 1.9), 0.7, mat)
	var c := foot.get_center()
	kit.put("box", "stone_dark", Vector3(c.x, (Layout.ABYSS + DEEP_BLOCKS) * 0.5, c.y), Vector3(foot.size.x, DEEP_BLOCKS - Layout.ABYSS, foot.size.y))


## A brass-banded timber post from under the slab to the abyss floor.
func _post(p: Vector2, top: float, size := 0.3) -> void:
	kit.span("plank", "wood_dark", Vector3(p.x, top + 0.1, p.y), Vector3(p.x, Layout.ABYSS, p.y), Vector2(size, size))
	for y in [top - 0.35, top - 3.2, top - 7.5]:
		kit.put("box", "brass", Vector3(p.x, y, p.y), Vector3(size + 0.08, 0.1, size + 0.08))


## Timber in the open bay between two supports (x0..x1 at z): a heavy beam
## under the slab and knee braces from both sides; on a front, a brass-
## strapped tie lower down and, in some wide bays, a cross brace between
## them. The bay itself stays open to the dark.
func _braces(x0: float, x1: float, z: float, top: float, beam: bool) -> void:
	var w := x1 - x0
	if w < 0.4:
		return
	if beam:
		kit.span("plank", "wood_dark", Vector3(x0 - 0.15, top - 0.2, z), Vector3(x1 + 0.15, top - 0.2, z), Vector2(0.36, 0.32))
	var k := minf(1.2, w * 0.35)
	for e in [[x0, 1.0], [x1, -1.0]]:
		var x: float = e[0]
		var d: float = e[1]
		kit.span("plank", "wood_dark", Vector3(x, top - 0.3 - k * 1.4, z), Vector3(x + d * k, top - 0.36, z), Vector2(0.17, 0.15))
		kit.put("box", "brass", Vector3(x + d * k, top - 0.22, z + 0.18), Vector3(0.12, 0.36, 0.03))
	if not beam:
		return
	var yt := top - kit.rng.randf_range(4.2, 5.6)
	kit.span("plank", "wood_dark", Vector3(x0 - 0.1, yt, z), Vector3(x1 + 0.1, yt, z), Vector2(0.28, 0.26))
	for x in [x0 + 0.22, x1 - 0.22]:
		kit.put("box", "brass", Vector3(x, yt, z + 0.15), Vector3(0.12, 0.34, 0.03))
	# A lantern hung from the tie of a wide bay frames the opening below.
	if w > 2.0:
		var lx := (x0 + x1) * 0.5 + kit.jitter(w * 0.2)
		kit.span("box", "iron", Vector3(lx, yt - 0.1, z + 0.05), Vector3(lx, yt - 0.55, z + 0.05), Vector2(0.03, 0.03))
		# Hung on a short chain (random state kept so the rest of the build
		# stays exactly as it was).
		var st := kit.rng.state
		chain(Vector3(lx, yt - 0.12, z + 0.05), Vector3(lx, yt - 0.62, z + 0.05), 0.1)
		kit.rng.state = st
		_lantern(Vector3(lx, yt - 0.78, z - 0.3))
	if w > 2.0 and kit.rng.randf() < 0.5:
		var y0 := top - 0.6
		kit.span("plank", "wood_dark", Vector3(x0, y0, z), Vector3(x1, yt, z), Vector2(0.16, 0.14))
		kit.span("plank", "wood_dark", Vector3(x1, y0, z), Vector3(x0, yt, z), Vector2(0.16, 0.14))


## A lantern hung on a pier face: a pinpoint warm pool on the nearby blocks,
## not a wash over the whole shaft.
func _lantern(face: Vector3) -> void:
	var lc := face + Vector3(0, 0, 0.35)
	kit.put("block", "iron", lc + Vector3(0, 0.3, -0.12), Vector3(0.1, 0.5, 0.25))
	kit.put("cyl8", "brass", lc, Vector3(0.26, 0.36, 0.26))
	kit.put("flame", "flame", lc + Vector3(0, 0.02, 0), Vector3(0.14, 0.24, 0.14))
	kit.put("sphere", "glow", lc, Vector3(0.1, 0.16, 0.1))
	kit.light(lc + Vector3(0, -0.1, 0.4), Color(1.0, 0.78, 0.55), 0.8, 2.8, false, 1.0, 2.0)


## A slim central drum under the round dais, and brass-banded posts under
## its rim with struts back to the drum: the shafts beside it stay open.
func _round_pillar(r: Layout.Room) -> void:
	var c := r.center()
	var top := r.y - SLAB
	var rad := r.radius()
	for step in 3:
		_ring(c, rad - 0.2 * (step + 1), top - 0.3, top, 0.4, 0.55)
		top -= 0.3
	var pr := rad * 0.4
	_ring(c, pr, top - 6.0, top, 0.45, 0.8, 0.32)
	_ring(c, pr, DEEP_BLOCKS, top - 6.0, 0.6, 1.4, 0.6)
	kit.put("cyl", "stone_dark", Vector3(c.x, (Layout.ABYSS + DEEP_BLOCKS) * 0.5, c.y), Vector3(pr * 2.0, DEEP_BLOCKS - Layout.ABYSS, pr * 2.0))
	for k in 4:
		var d := Vector2.from_angle(PI * 0.25 + k * PI * 0.5)
		var p := c + d * (rad - 1.1)
		var q := c + d * (pr - 0.1)
		_post(p, top)
		kit.span("plank", "wood_dark", Vector3(q.x, top - 0.2, q.y), Vector3(p.x, top - 0.2, p.y), Vector2(0.28, 0.3))
		kit.span("plank", "wood_dark", Vector3(q.x, top - 2.6, q.y), Vector3(p.x, top - 0.4, p.y), Vector2(0.18, 0.16))


## Courses of blocks laid around a circle of radius rad.
func _ring(c: Vector2, rad: float, y0: float, y1: float, depth: float, block_len: float, course := COURSE) -> void:
	kit.put("cyl", "stone_dark", Vector3(c.x, (y0 + y1) * 0.5, c.y), Vector3((rad - 0.05) * 2.0, y1 - y0, (rad - 0.05) * 2.0))
	var y := y0
	for h in _courses(y1 - y0, course):
		_ring_course(c, rad, depth, y, h, Vector2(block_len * 0.75, block_len * 1.35))
		y += h


## One course of blocks round a circle: random arc lengths from a random
## start, stopping short of the gaps (angle ranges left open).
func _ring_course(c: Vector2, rad: float, depth: float, y: float, h: float, block_len: Vector2, gaps := []) -> void:
	var a0 := kit.rng.randf() * TAU
	var free := [Vector2(0.0, TAU * rad)]
	if not gaps.is_empty():
		a0 = gaps[0].y
		var holes := []
		for g in gaps:
			var g0 := wrapf(g.x - a0, 0.0, TAU) * rad
			holes.append(Vector2(g0, g0 + (g.y - g.x) * rad))
		free = _subtract(free[0], holes)
	for seg in free:
		var cuts := _block_cuts(seg, block_len, false)
		for k in cuts.size() - 1:
			var a := a0 + (cuts[k] + cuts[k + 1]) * 0.5 / rad
			var p := c + Vector2(cos(a), sin(a)) * (rad - depth * 0.5)
			var tilt := Basis.from_euler(Vector3(kit.jitter(0.012), 0.0, kit.jitter(0.012)))
			kit.piece("block", "stone", Vector3(p.x, y + h * 0.5, p.y), Vector3(depth + kit.jitter(0.04), h - 0.045, cuts[k + 1] - cuts[k] - 0.045),
				Basis(Vector3.UP, -a) * tilt, kit.tint(STONE, 0.24, 0.05))


## Course heights filling `height`: uneven, none much thinner than half a course.
func _courses(height: float, course: float) -> Array[float]:
	var rows: Array[float] = []
	var left := height
	while left > 0.04:
		var h := course * kit.rng.randf_range(0.72, 1.28)
		if left - h < course * 0.5:
			h = left if left < course * 1.6 else left * 0.5
		rows.append(h)
		left -= h
	return rows


## Wooden posts with cross bracing (the low dock).
func _posts(r: Layout.Room) -> void:
	var R := r.rect.grow(-0.15)
	var top := r.y - 0.2
	var corners := [R.position, Vector2(R.end.x, R.position.y), R.end, Vector2(R.position.x, R.end.y)]
	for p in corners:
		kit.span("plank", "wood_dark", Vector3(p.x, top, p.y), Vector3(p.x, Layout.ABYSS, p.y), Vector2(0.26, 0.26))
		for y in [top - 0.4, top - 4.0, top - 8.0]:
			kit.put("box", "iron", Vector3(p.x, y, p.y), Vector3(0.32, 0.1, 0.32))
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		for band in [[top, top - 4.0], [top - 4.0, top - 8.0]]:
			kit.span("plank", "wood_dark", Vector3(a.x, band[0], a.y), Vector3(b.x, band[1], b.y), Vector2(0.14, 0.12))
		kit.span("plank", "wood_dark", Vector3(a.x, top - 0.1, a.y), Vector3(b.x, top - 0.1, b.y), Vector2(0.2, 0.22))


# ------------------------------------------------------------------- round

func _round_floor(r: Layout.Room) -> void:
	var c := r.center()
	var rad := r.radius() - r.wall_t + 0.1
	kit.put("cyl", "stone_dark", Vector3(c.x, r.y - SLAB * 0.5 - TILE_H * 0.5, c.y), Vector3(rad * 2.0, SLAB - TILE_H, rad * 2.0))
	kit.put("cyl", "floor", Vector3(c.x, r.y - TILE_H * 0.5, c.y), Vector3(0.9, TILE_H, 0.9), 0.0, kit.tint(STONE, 0.1))
	var ring_r := 0.45
	while ring_r < rad - 0.05:
		var w := kit.rng.randf_range(0.5, 0.75)
		if rad - (ring_r + w) < 0.35:
			w = rad - ring_r
		var mid := ring_r + w * 0.5
		var a0 := kit.rng.randf() * TAU
		var cuts := _block_cuts(Vector2(0.0, TAU * mid), Vector2(0.55, 1.05), false)
		for k in cuts.size() - 1:
			var a := a0 + (cuts[k] + cuts[k + 1]) * 0.5 / mid
			var p := c + Vector2(cos(a), sin(a)) * mid
			var h := TILE_H + kit.jitter(0.015)
			kit.piece("slab", "floor", Vector3(p.x, r.y - h * 0.5 + kit.jitter(0.012), p.y),
				Vector3(w - 0.05, h, cuts[k + 1] - cuts[k] - 0.05), Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, kit.jitter(0.02)), kit.tint(STONE, 0.18))
		ring_r += w


func _round_wall(r: Layout.Room) -> void:
	var c := r.center()
	var rad := r.radius()
	var height: float = r.walls.get("n", 0.7)
	var base := r.y - SLAB
	# Openings as angle ranges where links meet the rim.
	var gaps := []
	for o in r.openings:
		var l: Layout.Link = o.link
		var dir: Vector2 = {"n": Vector2(0, -1), "s": Vector2(0, 1), "w": Vector2(-1, 0), "e": Vector2(1, 0)}[o.side]
		var half := asin(clampf((o.hi - o.lo) * 0.5 / (rad - r.wall_t * 0.5), 0.0, 1.0)) + 0.04
		gaps.append(Vector2(dir.angle() - half, dir.angle() + half))
	var y := base
	for h in _courses(r.y + height - base, COURSE):
		_ring_course(c, rad, r.wall_t, y, h, Vector2(0.6, 1.1), gaps)
		y += h
	# Brass-capped posts around the rim, as on the reference's dais.
	var posts := 16
	for i in posts:
		var a := TAU * (i + 0.5) / posts
		if _in_gaps(a, gaps):
			continue
		var p := c + Vector2(cos(a), sin(a)) * (rad - r.wall_t * 0.5)
		kit.put("block", "stone", Vector3(p.x, r.y + height + 0.2, p.y), Vector3(0.3, 0.4, 0.3), rad_to_deg(-a))
		kit.put("cyl", "brass", Vector3(p.x, r.y + height + 0.44, p.y), Vector3(0.2, 0.08, 0.2))


func _in_gaps(a: float, gaps: Array) -> bool:
	for g in gaps:
		var d := wrapf(a - (g.x + g.y) * 0.5, -PI, PI)
		if absf(d) < (g.y - g.x) * 0.5:
			return true
	return false


# ------------------------------------------------------------------- links

func link(l: Layout.Link) -> void:
	# Thresholds through the wall bands at each end (unless the room's own
	# floor already runs there because its wall was handed to a neighbour).
	for end in [[l.e0, l.s0, l.room_a], [l.s1, l.e1, l.room_b]]:
		var mid: float = (end[0] + end[1]) * 0.5
		var m := Vector2(mid, l.center) if l.axis == 0 else Vector2(l.center, mid)
		var room: Layout.Room = end[2]
		if room.round or not room.has_floor(m):
			_threshold(l, end[0], end[1])
	if l.kind != "door" and l.gap() > 0.9:
		_truss(l)
	match l.kind:
		"door":
			pass
		"bridge":
			_bridge(l)
		"walk":
			_walk(l)
		"girder":
			_girder(l)
		"stairs":
			_stairs(l)


## Timber posts at both ends of a span running down into the dark, with a
## ledger across each pair and knee braces up to the deck: no cross bracing,
## so a bridge over a shaft leaves the shaft open below it.
func _truss(l: Layout.Link) -> void:
	var dirf := float(signf(l.s1 - l.s0))
	var half := l.width * 0.5 + 0.15
	var low := minf(l.ya, l.yb) - SLAB - 0.4
	var depth := kit.rng.randf_range(14.0, 22.0)
	var reach := minf(0.9, l.gap() * 0.3)
	for e in [[l.s0 + dirf * 0.2, dirf], [l.s1 - dirf * 0.2, -dirf]]:
		var end: float = e[0]
		var d: float = e[1]
		for c in [-half, half]:
			kit.span("plank", "wood_dark", _p(l, end, c, low + 0.3), _p(l, end, c, low - depth), Vector2(0.22, 0.22))
			kit.put("box", "iron", _p(l, end, c, low - 0.4), Vector3(0.28, 0.1, 0.28))
			if reach > 0.3:
				kit.span("plank", "wood_dark", _p(l, end, c, low - reach * 1.3), _p(l, end + d * reach, c, low + 0.15), Vector2(0.12, 0.12))
		kit.span("plank", "wood_dark", _p(l, end, -half, low - 0.5), _p(l, end, half, low - 0.5), Vector2(0.16, 0.16))


## Grit, pebbles and spalled chips on a floor, thicker along the walls.
func _debris(r: Layout.Room) -> void:
	var inner := r.inner()
	var n := int(inner.size.x * inner.size.y * 1.6)
	for i in n:
		var p := inner.position + Vector2(kit.rng.randf(), kit.rng.randf()) * inner.size
		if kit.rng.randf() < 0.6:
			# Pull towards the nearest wall.
			var d := Vector2(minf(p.x - inner.position.x, inner.end.x - p.x), minf(p.y - inner.position.y, inner.end.y - p.y))
			if d.x < d.y:
				p.x = inner.position.x + 0.12 if p.x - inner.position.x < inner.end.x - p.x else inner.end.x - 0.12
			else:
				p.y = inner.position.y + 0.12 if p.y - inner.position.y < inner.end.y - p.y else inner.end.y - 0.12
			p += Vector2(kit.jitter(0.12), kit.jitter(0.12))
		var sz := kit.rng.randf_range(0.04, 0.13)
		kit.piece("block", "stone", Vector3(p.x, r.y + sz * 0.3, p.y), Vector3(sz * kit.rng.randf_range(0.8, 1.6), sz * 0.6, sz),
			Basis.from_euler(Vector3(kit.jitter(0.4), kit.rng.randf() * TAU, kit.jitter(0.4))), kit.tint(STONE, 0.25))


func _threshold(l: Layout.Link, a: float, b: float) -> void:
	if absf(b - a) < 0.05:
		return
	var lo := minf(a, b)
	var hi := maxf(a, b)
	var y := l.height_at((a + b) * 0.5)
	var rect := Rect2(lo, l.center - l.width * 0.5, hi - lo, l.width) if l.axis == 0 \
		else Rect2(l.center - l.width * 0.5, lo, l.width, hi - lo)
	kit.put("box", "stone_dark", Vector3(rect.get_center().x, y - SLAB * 0.5, rect.get_center().y), Vector3(rect.size.x, SLAB - 0.05, rect.size.y))
	_tiles(rect, y)


## Point on a link: s along the axis, c across it, at height y.
func _p(l: Layout.Link, s: float, c: float, y: float) -> Vector3:
	return Vector3(s, y, l.center + c) if l.axis == 0 else Vector3(l.center + c, y, s)


## Size vector with `along` on the link axis and `across` on the other.
func _sz(l: Layout.Link, along: float, h: float, across: float) -> Vector3:
	return Vector3(along, h, across) if l.axis == 0 else Vector3(across, h, along)


## Rotation that tilts a piece to the link's slope.
func _slope_basis(l: Layout.Link) -> Basis:
	var ang := atan2(l.yb - l.ya, (l.s1 - l.s0))
	if l.axis == 0:
		return Basis(Vector3.BACK, ang)
	return Basis(Vector3.RIGHT, -ang)


func _bridge(l: Layout.Link) -> void:
	var half := l.width * 0.5
	var basis := _slope_basis(l)
	var s0 := l.s0
	var s1 := l.s1
	var dirf := float(signf(s1 - s0))
	var length := absf(s1 - s0)
	# Deck planks laid across the span.
	var s := s0
	while (s1 - s) * dirf > 0.05:
		var w := kit.rng.randf_range(0.2, 0.27)
		var mid := s + dirf * w * 0.5
		if (s1 - mid) * dirf < 0.0:
			break
		var y := l.height_at(mid) - 0.04
		kit.piece("plank", "wood", _p(l, mid, kit.jitter(0.03), y + kit.jitter(0.008)), _sz(l, w - 0.02, 0.07, l.width + 0.12 + kit.jitter(0.05)),
			basis * Basis(Vector3.UP, kit.jitter(0.02)), kit.tint(Color(1, 1, 1), 0.22))
		s += dirf * w
	# Stringers, buried a little into each room's slab.
	var a := s0 - dirf * 0.35
	var b := s1 + dirf * 0.35
	for c in [-half + 0.1, half - 0.1]:
		kit.span("plank", "wood_dark", _p(l, a, c, l.height_at(a) - 0.25), _p(l, b, c, l.height_at(b) - 0.25), Vector2(0.18, 0.3))
		# Brass straps along the stringer.
		var k := 0.6
		while k < length:
			var sk := s0 + dirf * k
			kit.piece("box", "brass", _p(l, sk, c + signf(c) * 0.1, l.height_at(sk) - 0.22), _sz(l, 0.1, 0.34, 0.02), basis)
			k += 1.2
	# Joists under the deck.
	var j := 0.5
	while j < length:
		var sj := s0 + dirf * j
		kit.piece("plank", "wood_dark", _p(l, sj, 0, l.height_at(sj) - 0.16), _sz(l, 0.14, 0.14, l.width), basis)
		j += 1.0
	_railings(l, s0, s1, l.width * 0.5 - 0.06)
	# Chains hanging from the stringers of long spans, weighted at the end.
	if length > 4.5:
		for t in [0.3, 0.62]:
			var sc := lerpf(s0, s1, t)
			for c in [-half + 0.1, half - 0.1]:
				chain(_p(l, sc, c, l.height_at(sc) - 0.4), _p(l, sc, c, l.height_at(sc) - kit.rng.randf_range(5.0, 9.0)))
	# Posts down to the abyss floor on long spans.
	for i in l.posts:
		var sp := lerpf(s0, s1, float(i + 1) / (l.posts + 1))
		var top := l.height_at(sp) - 0.4
		for c in [-half + 0.1, half - 0.1]:
			kit.span("plank", "wood_dark", _p(l, sp, c, top), _p(l, sp, c, Layout.ABYSS), Vector2(0.26, 0.26))
			for yy in [top - 0.3, top - 3.0, top - 6.0]:
				kit.put("box", "brass", _p(l, sp, c, yy), Vector3(0.32, 0.1, 0.32))
		kit.span("plank", "wood_dark", _p(l, sp, -half + 0.1, top), _p(l, sp, half - 0.1, top - 2.5), Vector2(0.12, 0.12))
		kit.span("plank", "wood_dark", _p(l, sp, half - 0.1, top), _p(l, sp, -half + 0.1, top - 2.5), Vector2(0.12, 0.12))
		# Knee braces from the posts up to the stringers.
		for d in [-1.2, 1.2]:
			for c in [-half + 0.1, half - 0.1]:
				kit.span("plank", "wood_dark", _p(l, sp, c, top - 1.4), _p(l, sp + d, c, l.height_at(sp + d) - 0.4), Vector2(0.12, 0.12))


func _railings(l: Layout.Link, s0: float, s1: float, off: float, mat := "wood_dark", cap := "brass") -> void:
	var length := absf(s1 - s0)
	var n := maxi(1, roundi(length / 1.2))
	var basis := _slope_basis(l)
	for c in [-off, off]:
		for i in n + 1:
			var s := lerpf(s0, s1, float(i) / n)
			var y := l.height_at(s)
			kit.put("plank", mat, _p(l, s, c, y + 0.42), Vector3(0.11, 0.9, 0.11))
			kit.put("box", cap, _p(l, s, c, y + 0.9), Vector3(0.15, 0.06, 0.15))
		for h in [0.85, 0.45]:
			kit.span("plank", mat, _p(l, s0, c, l.height_at(s0) + h), _p(l, s1, c, l.height_at(s1) + h), Vector2(0.08, 0.07))


func _walk(l: Layout.Link) -> void:
	var half := l.width * 0.5
	var lo := minf(l.s0, l.s1)
	var hi := maxf(l.s0, l.s1)
	var y := l.ya
	var rect := Rect2(lo, l.center - half, hi - lo, l.width) if l.axis == 0 else Rect2(l.center - half, lo, l.width, hi - lo)
	_tiles(rect.grow(-0.02), y)
	var c := rect.get_center()
	kit.put("box", "stone_dark", Vector3(c.x, y - 0.35, c.y), Vector3(rect.size.x, 0.6, rect.size.y))
	# Block courses on both outer faces of the slab and corbels below.
	for side_c in [-half, half]:
		var band := Rect2(lo, l.center + side_c - 0.15, hi - lo, 0.3) if l.axis == 0 else Rect2(l.center + side_c - 0.15, lo, 0.3, hi - lo)
		_course_wall("n" if l.axis == 0 else "w", band, y - 0.7, y, "stone")
	# Parapet on one side, iron railing on the other.
	var par := Rect2(lo, l.center - half - 0.1, hi - lo, 0.28) if l.axis == 0 else Rect2(l.center - half - 0.1, lo, 0.28, hi - lo)
	_course_wall("n" if l.axis == 0 else "w", par, y, y + 0.7, "stone")
	_crenellate("n" if l.axis == 0 else "w", par, y + 0.7)
	var n := maxi(2, int((hi - lo) / 0.25))
	for i in n + 1:
		var s := lerpf(lo, hi, float(i) / n)
		kit.put("box", "iron", _p(l, s, half - 0.06, y + 0.4), Vector3(0.04, 0.8, 0.04))
	kit.span("box", "iron", _p(l, lo, half - 0.06, y + 0.82), _p(l, hi, half - 0.06, y + 0.82), Vector2(0.07, 0.07))
	# Arched underside: corbels stepping out from both rooms.
	for k in 3:
		var d := 0.5 + k * 0.35
		for end_s in [[lo, 1.0], [hi, -1.0]]:
			var s: float = end_s[0] + end_s[1] * (d * 0.5)
			kit.put("block", "stone", _p(l, s, 0, y - 0.85 - k * 0.3), _sz(l, d, 0.3, l.width - 0.1))


func _girder(l: Layout.Link) -> void:
	var half := l.width * 0.5
	var s0 := l.s0
	var s1 := l.s1
	var dirf := float(signf(s1 - s0))
	var y := l.ya
	var a := s0 - dirf * 0.4
	var b := s1 + dirf * 0.4
	# Two riveted iron I-beams carry a plank deck.
	for c in [-half + 0.08, half - 0.08]:
		kit.span("box", "iron", _p(l, a, c, y - 0.32), _p(l, b, c, y - 0.32), Vector2(0.06, 0.4))
		kit.span("box", "iron", _p(l, a, c, y - 0.13), _p(l, b, c, y - 0.13), Vector2(0.2, 0.04))
		kit.span("box", "iron", _p(l, a, c, y - 0.51), _p(l, b, c, y - 0.51), Vector2(0.2, 0.04))
		var k := 0.0
		while k < absf(b - a):
			var sk := a + dirf * k
			for e in [-1.0, 1.0]:
				kit.put("sphere", "brass", _p(l, sk, c + e * 0.04, y - 0.32), Vector3(0.04, 0.04, 0.04))
			k += 0.3
	var s := s0
	while (s1 - s) * dirf > 0.05:
		var mid := s + dirf * 0.11
		kit.piece("plank", "wood", _p(l, mid, 0, y - 0.04), _sz(l, 0.2, 0.07, l.width - 0.05), Basis(Vector3.UP, kit.jitter(0.02)), kit.tint(Color(1, 1, 1), 0.2))
		s += dirf * 0.23
	_railings(l, s0, s1, half - 0.04, "iron", "brass")
	# Winch wheels where the girder meets the lift.
	for room in [l.room_a, l.room_b]:
		if room.support == "links":
			var edge := l.s0 if room == l.room_a else l.s1
			for c in [-half - 0.1, half + 0.1]:
				kit.piece("cyl", "brass", _p(l, edge, c, y + 0.25), Vector3(0.6, 0.08, 0.6), Basis(Vector3.RIGHT if l.axis == 0 else Vector3.BACK, PI * 0.5))
				kit.piece("cyl", "iron", _p(l, edge, c, y + 0.25), Vector3(0.18, 0.14, 0.18), Basis(Vector3.RIGHT if l.axis == 0 else Vector3.BACK, PI * 0.5))


func _stairs(l: Layout.Link) -> void:
	var dirf := float(signf(l.s1 - l.s0))
	var run := l.gap() / l.steps
	var low := minf(l.ya, l.yb)
	var half := l.width * 0.5
	for k in l.steps:
		var sa := l.s0 + dirf * run * k
		var sb := sa + dirf * run
		var mid := (sa + sb) * 0.5
		var top := l.height_at(mid)
		var y0 := low - SLAB
		# Each tread: two or three blocks across, resting on the masonry below.
		var parts := 2 if l.width < 1.8 else 3
		for i in parts:
			var c := -half + l.width * (i + 0.5) / parts
			kit.piece("block", "stone", _p(l, mid, c, top - 0.09), _sz(l, run + 0.02, 0.18, l.width / parts - 0.03),
				Basis(Vector3.UP, kit.jitter(0.02)), kit.tint(STONE_WARM, 0.15))
		kit.put("box", "stone_dark", _p(l, mid, 0, (y0 + top - 0.18) * 0.5), _sz(l, run, top - 0.18 - y0, l.width))
	# Side walls following the flight, then the support under it.
	var lo := minf(l.s0, l.s1)
	var hi := maxf(l.s0, l.s1)
	var high := maxf(l.ya, l.yb)
	for c in [-half - 0.15, half + 0.15]:
		for k in l.steps:
			var sa := l.s0 + dirf * run * k
			var mid := sa + dirf * run * 0.5
			var top := l.height_at(mid)
			var band := Rect2(minf(sa, sa + dirf * run), l.center + c - 0.15, run, 0.3) if l.axis == 0 \
				else Rect2(l.center + c - 0.15, minf(sa, sa + dirf * run), 0.3, run)
			_course_wall("n" if l.axis == 0 else "w", band, low - SLAB, top + 0.45, "stone")
	var foot := Rect2(lo, l.center - half - 0.3, hi - lo, l.width + 0.6) if l.axis == 0 \
		else Rect2(l.center - half - 0.3, lo, l.width + 0.6, hi - lo)
	# A short masonry underside: the flight is carried between its two rooms
	# (and the truss posts at its ends), leaving the shaft below it open.
	if foot.size.x > 0.6 and foot.size.y > 0.6:
		_block_box(foot.grow(-0.1), low - SLAB - 1.0, low - SLAB, Vector2(0.7, 1.3), 0.5)
	if high - low > 0.0:
		pass
