class_name Build
extends RefCounted
## Turns a resolved Layout into instanced geometry: flagstone floors, coursed
## walls with crenellations, corner towers, corbelled pillars that run down
## into the abyss, and the bridge, stair, walkway and girder for each link.

const TILE := 0.6
const SLAB := 0.55          # floor slab under the tiles
const TILE_H := 0.09
const COURSE := 0.33
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
		Vector3(inner.size.x, SLAB - TILE_H, inner.size.y), 0.0, Color(0.5, 0.48, 0.46))
	if theme == "wood" or theme == "iron":
		_deck(r.rect.grow(-0.05), r.y, theme)
		return
	_tiles(inner, r.y)
	for e in r.extra_floor:
		var c := e.get_center()
		kit.put("box", "stone_dark", Vector3(c.x, r.y - SLAB * 0.5 - TILE_H * 0.5, c.y), Vector3(e.size.x, SLAB - TILE_H, e.size.y), 0.0, Color(0.5, 0.48, 0.46))
		_tiles(e, r.y)
	_slab_edges(r)
	_debris(r)


## Irregular flagstones on a 0.5 m grid: whole, halved, quartered, a few
## large ones and the odd broken gap.
func _tiles(area: Rect2, top: float, mat := "floor") -> void:
	var nx := maxi(1, roundi(area.size.x / TILE))
	var nz := maxi(1, roundi(area.size.y / TILE))
	var cw := area.size.x / nx
	var cd := area.size.y / nz
	var used := {}
	for iz in nz:
		for ix in nx:
			if used.has(Vector2i(ix, iz)):
				continue
			var r := kit.rng.randf()
			var x0 := area.position.x + ix * cw
			var z0 := area.position.y + iz * cd
			if r < 0.07 and ix + 1 < nx and iz + 1 < nz and not used.has(Vector2i(ix + 1, iz)) \
					and not used.has(Vector2i(ix, iz + 1)) and not used.has(Vector2i(ix + 1, iz + 1)):
				for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
					used[Vector2i(ix, iz) + d] = true
				_tile(Rect2(x0, z0, cw * 2, cd * 2), top, mat)
			elif r < 0.27:
				if kit.rng.randf() < 0.5:
					_tile(Rect2(x0, z0, cw * 0.5, cd), top, mat)
					_tile(Rect2(x0 + cw * 0.5, z0, cw * 0.5, cd), top, mat)
				else:
					_tile(Rect2(x0, z0, cw, cd * 0.5), top, mat)
					_tile(Rect2(x0, z0 + cd * 0.5, cw, cd * 0.5), top, mat)
			elif r < 0.37:
				for q in [Vector2(0, 0), Vector2(0.5, 0), Vector2(0, 0.5), Vector2(0.5, 0.5)]:
					_tile(Rect2(x0 + q.x * cw, z0 + q.y * cd, cw * 0.5, cd * 0.5), top, mat)
			elif r < 0.395:
				_broken(Rect2(x0, z0, cw, cd), top)
			else:
				_tile(Rect2(x0, z0, cw, cd), top, mat)


func _tile(rect: Rect2, top: float, mat: String) -> void:
	var gap := 0.035
	var h := TILE_H + kit.jitter(0.015)
	var c := rect.get_center()
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(kit.jitter(1.6))) * Basis(Vector3.FORWARD, deg_to_rad(kit.jitter(1.6)))
	var basis := Basis(Vector3.UP, deg_to_rad(kit.jitter(2.0))) * tilt
	kit.piece("slab", mat, Vector3(c.x, top - h * 0.5 + kit.jitter(0.012), c.y),
		Vector3(rect.size.x - gap - kit.rng.randf_range(0.0, 0.03), h, rect.size.y - gap - kit.rng.randf_range(0.0, 0.03)), basis, kit.tint(STONE, 0.16))


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
				kit.put("slab", "iron", Vector3(c.x, top - 0.03, c.y), Vector3(area.size.x / nx - 0.03, 0.06, area.size.y / nz - 0.03), 0.0, kit.tint(Color(1, 1, 1), 0.15))
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
		_course_wall(side, rect, base, r.y + height, "stone")
		_crenellate(side, rect, r.y + height)
		if height >= 1.0:
			_pilasters(side, rect, base, r.y + height)
	for o in doors:
		_doorway(r, side, band, o, height)
	for f in r.opts.get("features", []):
		if f.side == side:
			_feature(r, side, band, f, height)


## Coursed masonry filling a plan rectangle from y0 to y1, with a dark mortar
## core so joints read as gaps.
func _course_wall(side: String, rect: Rect2, y0: float, y1: float, mat: String, block_len := Vector2(0.45, 0.95), course := COURSE) -> void:
	var along_x := side == "n" or side == "s"
	var length := rect.size.x if along_x else rect.size.y
	var depth := rect.size.y if along_x else rect.size.x
	if length < 0.05 or y1 - y0 < 0.05:
		return
	var c := rect.get_center()
	kit.put("box", "stone_dark", Vector3(c.x, (y0 + y1) * 0.5, c.y),
		Vector3(rect.size.x - (0.0 if along_x else 0.1), y1 - y0 - 0.02, rect.size.y - (0.1 if along_x else 0.0)), 0.0, Color(0.16, 0.15, 0.15))
	var start := rect.position.x if along_x else rect.position.y
	var y := y0
	var row := 0
	while y < y1 - 0.04:
		var h := minf(course + kit.jitter(0.05), y1 - y)
		if y1 - (y + h) < 0.12:
			h = y1 - y
		var s := start - kit.rng.randf_range(0.1, block_len.x)
		while s < start + length - 0.02:
			var bl := kit.rng.randf_range(block_len.x, block_len.y)
			var a := maxf(s, start)
			var b := minf(s + bl, start + length)
			if b - a > 0.08 and kit.rng.randf() > 0.015:
				var mid := (a + b) * 0.5
				var out := kit.jitter(0.03)
				var bh := h - 0.04
				var shrink := 1.0
				if kit.rng.randf() < 0.07:
					shrink = kit.rng.randf_range(0.7, 0.88)
				var pos := Vector3(mid, y + h * 0.5 - (1.0 - shrink) * bh * 0.3, c.y + out) if along_x else Vector3(c.x + out, y + h * 0.5 - (1.0 - shrink) * bh * 0.3, mid)
				var size := Vector3((b - a - 0.04) * shrink, bh * shrink, depth + kit.jitter(0.04)) if along_x \
					else Vector3(depth + kit.jitter(0.04), bh * shrink, (b - a - 0.04) * shrink)
				var wob := 0.02 + (1.0 - shrink) * 0.3
				var basis := Basis.from_euler(Vector3(kit.jitter(wob), kit.jitter(wob * 1.5), kit.jitter(wob)))
				kit.piece("block", mat, pos, size, basis, kit.tint(STONE, 0.24, 0.05))
			s += bl
		y += h
		row += 1


## Piers standing proud of both wall faces every couple of metres.
func _pilasters(side: String, rect: Rect2, y0: float, y1: float) -> void:
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
		var pos := Vector3(at, (y0 + y1 + 0.2) * 0.5, c.y) if along_x else Vector3(c.x, (y0 + y1 + 0.2) * 0.5, at)
		var size := Vector3(0.42, y1 - y0 + 0.2, depth + 0.24) if along_x else Vector3(depth + 0.24, y1 - y0 + 0.2, 0.42)
		_column(pos, size)
		kit.put("block", "stone", pos + Vector3(0, size.y * 0.5 + 0.08, 0), size * Vector3(1.15, 0.0, 1.1) + Vector3(0, 0.16, 0), kit.jitter(4.0), kit.tint(STONE, 0.2))


## Merlons along a wall top, with the odd one fallen.
func _crenellate(side: String, rect: Rect2, top: float) -> void:
	var along_x := side == "n" or side == "s"
	var length := rect.size.x if along_x else rect.size.y
	var depth := rect.size.y if along_x else rect.size.x
	var start := rect.position.x if along_x else rect.position.y
	var c := rect.get_center()
	# Capping course, slightly proud of the wall.
	var n := maxi(1, int(length / 0.6))
	var w := length / n
	for i in n:
		var mid := start + (i + 0.5) * w + kit.jitter(0.03)
		var ch := 0.16 + kit.jitter(0.03)
		var pos := Vector3(mid, top + ch * 0.5, c.y + kit.jitter(0.03)) if along_x else Vector3(c.x + kit.jitter(0.03), top + ch * 0.5, mid)
		var size := Vector3(w - 0.04, ch, depth + 0.1) if along_x else Vector3(depth + 0.1, ch, w - 0.04)
		kit.piece("block", "stone", pos, size, Basis.from_euler(Vector3(kit.jitter(0.03), kit.jitter(0.06), kit.jitter(0.03))), kit.tint(STONE, 0.22, 0.05))
	var m := maxi(1, int(length / 0.85))
	var pitch := length / m
	for i in m:
		if kit.rng.randf() < 0.15:
			continue
		var mid := start + (i + 0.5) * pitch + kit.jitter(0.06)
		var mh := kit.rng.randf_range(0.26, 0.42)
		var mw := minf(kit.rng.randf_range(0.38, 0.5), pitch * 0.6)
		var pos := Vector3(mid, top + 0.16 + mh * 0.5, c.y) if along_x else Vector3(c.x, top + 0.16 + mh * 0.5, mid)
		var size := Vector3(mw, mh, depth * 0.95) if along_x else Vector3(depth * 0.95, mh, mw)
		kit.piece("block", "stone", pos, size, Basis.from_euler(Vector3(kit.jitter(0.05), kit.jitter(0.08), kit.jitter(0.05))), kit.tint(STONE, 0.22, 0.05))
		if kit.rng.randf() < 0.18:
			var sh := kit.rng.randf_range(0.18, 0.28)
			var p2 := pos + Vector3(kit.jitter(0.05), mh * 0.5 + sh * 0.5 + 0.01, kit.jitter(0.03))
			kit.piece("block", "stone", p2, size * Vector3(0.85, sh / mh, 0.85), Basis(Vector3.UP, kit.jitter(0.15)), kit.tint(STONE, 0.22, 0.05))


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
func _column(center: Vector3, size: Vector3) -> void:
	var y := center.y - size.y * 0.5
	var top := center.y + size.y * 0.5
	while y < top - 0.03:
		var h := minf(COURSE + kit.jitter(0.04), top - y)
		kit.piece("block", "stone", Vector3(center.x, y + h * 0.5, center.z), Vector3(size.x + kit.jitter(0.02), h - 0.02, size.z + kit.jitter(0.02)),
			Basis(Vector3.UP, kit.jitter(0.03)), kit.tint(STONE_WARM, 0.14))
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
	var at: float = lerpf(rng_lo, rng_hi, f.t)
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
	if y0 + h + 0.4 > height:
		h = height - y0 - 0.45
		if h < 0.6:
			return
	var panel_mat := "window_glow" if f.get("lit", false) else "stone_dark"
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
		kit.light(base + into * 0.6 + Vector3(0, y0 + h * 0.6, 0), Color(1.0, 0.55, 0.22), 0.9, 3.0)


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
	_block_box(crown, top, top + 0.3, Vector2(0.3, 0.5))
	for q in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var p: Vector2 = crown.position + (crown.size - Vector2(0.4, 0.4)) * q + Vector2(0.2, 0.2)
		kit.put("block", "stone", Vector3(p.x, top + 0.3 + 0.2, p.y), Vector3(0.38, 0.4, 0.38), kit.jitter(5.0), kit.tint(STONE, 0.15))
	kit.put("slab", "floor", Vector3(crown.get_center().x, top + 0.31, crown.get_center().y), Vector3(crown.size.x - 0.2, 0.04, crown.size.y - 0.2), 0.0, kit.tint(STONE, 0.1))
	if r.opts.get("tower_fire", false):
		Props.brazier(kit, Vector3(foot.get_center().x, top + 0.33, foot.get_center().y))


## Hollow-looking solid of blocks on all four faces between y0 and y1.
func _block_box(foot: Rect2, y0: float, y1: float, block_len := Vector2(0.35, 0.6), course := COURSE) -> void:
	var t := 0.3
	_course_wall("n", Rect2(foot.position.x, foot.position.y, foot.size.x, t), y0, y1, "stone", block_len, course)
	_course_wall("s", Rect2(foot.position.x, foot.end.y - t, foot.size.x, t), y0, y1, "stone", block_len, course)
	_course_wall("w", Rect2(foot.position.x, foot.position.y + t, t, foot.size.y - 2 * t), y0, y1, "stone", block_len, course)
	_course_wall("e", Rect2(foot.end.x - t, foot.position.y + t, t, foot.size.y - 2 * t), y0, y1, "stone", block_len, course)


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

## Corbel steps under the slab, then one or more pillars of ever larger
## courses down to the abyss floor, with timber between them.
func _pillar(r: Layout.Room) -> void:
	var top := r.y - SLAB
	var foot := r.rect
	for step in 3:
		var f := foot.grow(-0.22 * (step + 1))
		_block_box(f, top - 0.32, top, Vector2(0.45, 0.85), 0.32)
		top -= 0.32
	var area := foot.grow(-0.8)
	var nx := maxi(1, roundi(area.size.x / 4.8))
	var nz := maxi(1, roundi(area.size.y / 4.8))
	var cw := area.size.x / nx
	var cd := area.size.y / nz
	var pw := minf(cw - 0.6, 3.6) if nx > 1 else minf(cw, 4.2)
	var pd := minf(cd - 0.6, 3.6) if nz > 1 else minf(cd, 4.2)
	var cores: Array[Rect2] = []
	for iz in nz:
		for ix in nx:
			var c := area.position + Vector2((ix + 0.5) * cw, (iz + 0.5) * cd)
			var core := Rect2(c - Vector2(pw, pd) * 0.5, Vector2(pw, pd))
			cores.append(core)
			_pillar_core(core, top, iz == nz - 1)
	# Heavy beams under the slab joining the pillar heads, on the front row.
	var front := cores.slice(cores.size() - nx)
	for i in front.size() - 1:
		var a: Rect2 = front[i]
		var b: Rect2 = front[i + 1]
		var z := a.end.y - 0.15
		kit.span("plank", "wood_dark", Vector3(a.end.x - 0.1, top - 0.2, z), Vector3(b.position.x + 0.1, top - 0.2, z), Vector2(0.34, 0.3))
		_timber_frame(Rect2(a.end.x, a.position.y, b.position.x - a.end.x, a.size.y), top - 0.4, top - 7.0)


func _pillar_core(core: Rect2, top: float, front: bool) -> void:
	# Near courses: dressed blocks; deeper: bigger rougher ones; then plain.
	_block_box(core, top - 6.0, top, Vector2(0.5, 1.0), 0.36)
	_block_box(core, DEEP_BLOCKS, top - 6.0, Vector2(0.9, 1.6), 0.6)
	var c := core.get_center()
	kit.put("box", "stone_dark", Vector3(c.x, (Layout.ABYSS + DEEP_BLOCKS) * 0.5, c.y), Vector3(core.size.x, DEEP_BLOCKS - Layout.ABYSS, core.size.y))
	if not front:
		return
	# Pilasters and brass-banded corner posts down the front face.
	var n := maxi(1, int(core.size.x / 1.6))
	for i in range(1, n):
		var x := core.position.x + core.size.x * i / n
		_column(Vector3(x, top - 6.0, core.end.y + 0.12), Vector3(0.4, 12.0, 0.26))
	# A lantern on the pillar face lights the masonry from below the slab.
	var lc := Vector3(core.get_center().x + kit.jitter(0.5), top - 1.6, core.end.y + 0.35)
	kit.put("block", "iron", lc + Vector3(0, 0.3, -0.12), Vector3(0.1, 0.5, 0.25))
	kit.put("cyl8", "brass", lc, Vector3(0.26, 0.36, 0.26))
	kit.put("flame", "flame", lc + Vector3(0, 0.02, 0), Vector3(0.14, 0.24, 0.14))
	kit.put("sphere", "glow", lc, Vector3(0.1, 0.16, 0.1))
	kit.light(lc + Vector3(0, -0.1, 0.4), Color(1.0, 0.6, 0.32), 2.5, 6.0)
	for x in [core.position.x - 0.1, core.end.x + 0.1]:
		var z := core.end.y + 0.1
		kit.span("plank", "wood_dark", Vector3(x, top + 0.1, z), Vector3(x, top - 24.0, z), Vector2(0.24, 0.24))
		var y := top - 0.5
		while y > top - 24.0:
			kit.put("box", "brass", Vector3(x, y, z), Vector3(0.3, 0.1, 0.3))
			y -= kit.rng.randf_range(1.6, 3.2)


func _timber_frame(core: Rect2, y0: float, y1: float) -> void:
	var z := core.end.y - 0.2
	var xs := [core.position.x + 0.15, core.get_center().x, core.end.x - 0.15]
	for x in xs:
		kit.span("plank", "wood_dark", Vector3(x, y0, z), Vector3(x, y1, z), Vector2(0.24, 0.2))
	for i in 2:
		var a: float = xs[i]
		var b: float = xs[i + 1]
		kit.span("plank", "wood_dark", Vector3(a, y0, z), Vector3(b, y1, z), Vector2(0.16, 0.14))
		kit.span("plank", "wood_dark", Vector3(b, y0, z), Vector3(a, y1, z), Vector2(0.16, 0.14))
	for y in [y0, (y0 + y1) * 0.5, y1]:
		kit.span("plank", "wood_dark", Vector3(xs[0] - 0.2, y, z + 0.02), Vector3(xs[2] + 0.2, y, z + 0.02), Vector2(0.2, 0.18))
		for x in xs:
			kit.put("box", "brass", Vector3(x, y, z + 0.12), Vector3(0.3, 0.12, 0.04))


func _round_pillar(r: Layout.Room) -> void:
	var c := r.center()
	var top := r.y - SLAB
	var rad := r.radius()
	for step in 3:
		_ring(c, rad - 0.2 * (step + 1), top - 0.3, top, 0.4, 0.55)
		top -= 0.3
	var pr := rad - 1.0
	_ring(c, pr, top - 6.0, top, 0.45, 0.8, 0.32)
	_ring(c, pr, DEEP_BLOCKS, top - 6.0, 0.6, 1.4, 0.6)
	kit.put("cyl", "stone_dark", Vector3(c.x, (Layout.ABYSS + DEEP_BLOCKS) * 0.5, c.y), Vector3(pr * 2.0, DEEP_BLOCKS - Layout.ABYSS, pr * 2.0))


## Courses of blocks laid around a circle of radius rad.
func _ring(c: Vector2, rad: float, y0: float, y1: float, depth: float, block_len: float, course := COURSE) -> void:
	kit.put("cyl", "stone_dark", Vector3(c.x, (y0 + y1) * 0.5, c.y), Vector3((rad - 0.05) * 2.0, y1 - y0, (rad - 0.05) * 2.0))
	var y := y0
	var row := 0
	while y < y1 - 0.03:
		var h := minf(course + kit.jitter(0.03), y1 - y)
		var n := maxi(6, int(TAU * rad / block_len))
		var off := (0.5 if row % 2 else 0.0) + kit.jitter(0.1)
		for i in n:
			var a := TAU * (i + off) / n
			var p := c + Vector2(cos(a), sin(a)) * (rad - depth * 0.5)
			var w := TAU * rad / n
			kit.piece("block", "stone", Vector3(p.x, y + h * 0.5, p.y), Vector3(depth + kit.jitter(0.02), h - 0.02, w - 0.03),
				Basis(Vector3.UP, -a), kit.tint(STONE, 0.17))
		y += h
		row += 1


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
	while ring_r < rad:
		var w := minf(0.5, rad - ring_r)
		var mid := ring_r + w * 0.5
		var n := maxi(6, int(TAU * mid / 0.5))
		var off := kit.rng.randf()
		for i in n:
			var a := TAU * (i + off) / n
			var p := c + Vector2(cos(a), sin(a)) * mid
			var arc := TAU * mid / n
			kit.piece("slab", "floor", Vector3(p.x, r.y - TILE_H * 0.5 + kit.jitter(0.01), p.y),
				Vector3(w - 0.035, TILE_H + kit.jitter(0.012), arc - 0.04), Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, kit.jitter(0.02)), kit.tint(STONE, 0.16))
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
	var row := 0
	while y < r.y + height - 0.03:
		var h := minf(COURSE + kit.jitter(0.03), r.y + height - y)
		var n := int(TAU * rad / 0.5)
		var off := 0.5 if row % 2 else 0.0
		for i in n:
			var a := TAU * (i + off) / n
			if _in_gaps(a, gaps):
				continue
			var p := c + Vector2(cos(a), sin(a)) * (rad - r.wall_t * 0.5)
			kit.piece("block", "stone", Vector3(p.x, y + h * 0.5, p.y), Vector3(r.wall_t + kit.jitter(0.02), h - 0.02, TAU * rad / n - 0.03),
				Basis(Vector3.UP, -a), kit.tint(STONE, 0.17))
		y += h
		row += 1
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


## Timber posts standing against the pillars at both ends of a span, with
## cross bracing and ledger beams, running down into the dark.
func _truss(l: Layout.Link) -> void:
	var dirf := float(signf(l.s1 - l.s0))
	var half := l.width * 0.5 + 0.15
	var low := minf(l.ya, l.yb) - SLAB - 0.4
	var depth := kit.rng.randf_range(14.0, 22.0)
	for end in [l.s0 + dirf * 0.2, l.s1 - dirf * 0.2]:
		for c in [-half, half]:
			kit.span("plank", "wood_dark", _p(l, end, c, low + 0.3), _p(l, end, c, low - depth), Vector2(0.22, 0.22))
			var y := low - 0.4
			while y > low - depth:
				kit.put("box", "brass", _p(l, end, c, y), Vector3(0.28, 0.08, 0.28))
				y -= kit.rng.randf_range(1.5, 3.5)
	var bay := 3.2
	var y0 := low
	var bays := 0
	while y0 > low - depth + bay and bays < 1:
		bays += 1
		var a := l.s0 + dirf * 0.2
		var b := l.s1 - dirf * 0.2
		for c in [-half, half]:
			kit.span("plank", "wood_dark", _p(l, a, c, y0), _p(l, b, c, y0 - bay), Vector2(0.14, 0.14))
			kit.span("plank", "wood_dark", _p(l, b, c, y0), _p(l, a, c, y0 - bay), Vector2(0.14, 0.14))
			kit.span("plank", "wood_dark", _p(l, a, c, y0 - bay), _p(l, b, c, y0 - bay), Vector2(0.18, 0.2))
		y0 -= bay


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
		for k in 3:
			var y0 := top - k * 3.0
			kit.span("plank", "wood_dark", _p(l, sp, -half + 0.1, y0), _p(l, sp, half - 0.1, y0 - 3.0), Vector2(0.12, 0.12))
			kit.span("plank", "wood_dark", _p(l, sp, half - 0.1, y0), _p(l, sp, -half + 0.1, y0 - 3.0), Vector2(0.12, 0.12))
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
	if foot.size.x > 0.6 and foot.size.y > 0.6:
		_block_box(foot.grow(-0.1), low - SLAB - 6.0, low - SLAB, Vector2(0.45, 0.9), 0.32)
		var c := foot.get_center()
		kit.put("box", "stone_dark", Vector3(c.x, (Layout.ABYSS + low - SLAB - 6.0) * 0.5, c.y), Vector3(foot.size.x - 0.3, low - SLAB - 6.0 - Layout.ABYSS, foot.size.y - 0.3))
	if high - low > 0.0:
		pass
