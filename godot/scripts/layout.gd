class_name Layout
extends RefCounted
## The level as data: named rooms, links declared between two named rooms,
## and props placed inside rooms. resolve() derives every link's span,
## heights and wall openings from its two endpoints, and rejects links that
## don't meet a real floor at both ends (no gap, no overlap, too steep,
## wrong step run). The walk grid and the reachability check are built from
## the same data, so the check exercises what the player walks on.

const CELL := 0.25          # walk grid resolution (m)
const STEP_RISE := 0.2      # one stair riser
const MAX_STEP := 0.3       # walkable height change between neighbouring cells
const MAX_SLOPE := 0.125    # bridges and walkways
const MIN_RUN := 0.25       # stair tread depth limits
const MAX_RUN := 0.65
const FREE_SPAN := 6.0      # longer spans get posts down to the abyss floor
const ABYSS := -70.0        # everything rests on this, eventually
const EPS := 0.01
const SIDES := ["n", "e", "s", "w"]


class Room:
	var name := ""
	var rect := Rect2()          # plan rectangle: position = (x0, z0), size = (dx, dz)
	var y := 0.0                 # floor height
	var round := false           # circular floor inscribed in rect
	var wall_t := 0.5            # wall thickness (walls stand inside rect)
	var walls := {"n": 2.6, "e": 1.4, "s": 0.9, "w": 1.4}
	var support := "pillar"      # pillar | posts | links
	var openings := []           # [{side, lo, hi, link}]
	var props := []              # [Prop]
	var opts := {}               # builder hints: towers, features, theme...
	var shared := []             # [{side, lo, hi, other, owner}] edges touching another room
	var extra_floor: Array[Rect2] = []   # wall bands handed to a neighbour's wall
	var index := 0

	## Wall thickness on a side; sides without a wall leave the floor to the edge.
	func inset(side: String) -> float:
		return wall_t if walls.get(side, 0.0) > 0.0 else 0.0

	func inner() -> Rect2:
		if round:
			return rect.grow(-wall_t)
		return Rect2(rect.position.x + inset("w"), rect.position.y + inset("n"),
			rect.size.x - inset("w") - inset("e"), rect.size.y - inset("n") - inset("s"))

	func center() -> Vector2:
		return rect.get_center()

	func radius() -> float:
		return minf(rect.size.x, rect.size.y) * 0.5

	func has_floor(p: Vector2) -> bool:
		if round:
			return p.distance_to(center()) < radius() - wall_t
		if inner().has_point(p):
			return true
		for e in extra_floor:
			if e.has_point(p):
				return true
		return false

	## Range of the side's edge, in the side's own coordinate (x for n/s, z for e/w).
	func side_range(side: String) -> Vector2:
		if side == "n" or side == "s":
			return Vector2(rect.position.x, rect.end.x)
		return Vector2(rect.position.y, rect.end.y)

	func openings_on(side: String) -> Array:
		return openings.filter(func(o): return o.side == side)


class Link:
	var name := ""
	var kind := "bridge"         # door | bridge | walk | girder | stairs
	var a := ""
	var b := ""
	var width := 1.6
	var at := NAN                # cross-axis centre; NAN = middle of the overlap
	# Resolved by Layout.resolve():
	var room_a: Room
	var room_b: Room
	var axis := 0                # 0: runs along x, 1: runs along z
	var dir := 1                 # +1 when a -> b increases the coordinate
	var side_a := ""
	var side_b := ""
	var center := 0.0            # cross-axis centre line
	var s0 := 0.0                # outer edge of room a (start of the gap)
	var s1 := 0.0                # outer edge of room b (end of the gap)
	var e0 := 0.0                # floor edge inside room a
	var e1 := 0.0                # floor edge inside room b
	var ya := 0.0
	var yb := 0.0
	var steps := 0
	var posts := 0               # intermediate supports for long spans
	var index := 0

	func gap() -> float:
		return absf(s1 - s0)

	## Walkable height at axis coordinate s (anywhere between e0 and e1).
	func height_at(s: float) -> float:
		var t := clampf((s - s0) / (s1 - s0), 0.0, 1.0) if gap() > EPS else 0.0
		if kind == "stairs":
			if t <= 0.0:
				return ya
			if t >= 1.0:
				return yb
			return ya + (yb - ya) * (floorf(t * steps) + 1.0) / steps
		return lerpf(ya, yb, t)

	## Plan rectangle of the walk span (e0..e1 along the axis, width across).
	func plan_rect() -> Rect2:
		var lo := minf(e0, e1)
		var hi := maxf(e0, e1)
		if axis == 0:
			return Rect2(lo, center - width * 0.5, hi - lo, width)
		return Rect2(center - width * 0.5, lo, width, hi - lo)

	## World point on the centre line at axis coordinate s, cross offset c.
	func point(s: float, c := 0.0) -> Vector3:
		if axis == 0:
			return Vector3(s, height_at(s), center + c)
		return Vector3(center + c, height_at(s), s)


class Prop:
	var kind := ""
	var room: Room
	var pos := Vector2.ZERO      # world plan position
	var rot := 0.0               # yaw in degrees
	var size := Vector2.ONE      # footprint (before rotation)
	var blocks := true
	var opts := {}

	func y() -> float:
		return room.y


var rooms: Array[Room] = []
var links: Array[Link] = []
var by_name := {}
var spawn_room := ""
var spawn_at := Vector2(0.5, 0.5)
var errors: PackedStringArray = []
var notes: PackedStringArray = []


func room(name: String, x0: float, z0: float, x1: float, z1: float, y: float, opts := {}) -> Room:
	var r := Room.new()
	r.name = name
	r.rect = Rect2(x0, z0, x1 - x0, z1 - z0)
	r.y = y
	for k in opts:
		if k == "walls":
			for side in opts.walls:
				r.walls[String(side)] = opts.walls[side]
		elif k in r:
			r.set(k, opts[k])
		elif opts[k] is Dictionary:
			# Literal {nw = 2.0} keys are StringNames; keep plain Strings.
			var d := {}
			for key in opts[k]:
				d[String(key)] = opts[k][key]
			r.opts[String(k)] = d
		else:
			r.opts[String(k)] = opts[k]
	r.index = rooms.size()
	if by_name.has(name):
		errors.append("duplicate room %s" % name)
	by_name[name] = r
	rooms.append(r)
	return r


func link(kind: String, a: String, b: String, opts := {}) -> Link:
	var l := Link.new()
	l.kind = kind
	l.a = a
	l.b = b
	l.name = "%s:%s-%s" % [kind, a, b]
	for k in opts:
		l.set(k, opts[k])
	l.index = links.size()
	links.append(l)
	return l


## Place a prop at fractional coordinates (u, v) of the room's floor.
func prop(kind: String, room_name: String, u: float, v: float, opts := {}) -> Prop:
	var r: Room = by_name.get(room_name)
	if r == null:
		errors.append("prop %s in unknown room %s" % [kind, room_name])
		return null
	var p := Prop.new()
	p.kind = kind
	p.room = r
	var inner := r.inner()
	p.pos = inner.position + inner.size * Vector2(u, v)
	p.rot = opts.get("rot", 0.0)
	p.size = opts.get("size", Props.footprint(kind))
	p.blocks = opts.get("blocks", Props.blocks(kind))
	p.opts = opts
	r.props.append(p)
	return p


## Decoration on a wall (window, arch, alcove...) at fraction t along the side.
func feature(kind: String, room_name: String, side: String, t: float, opts := {}) -> void:
	var r: Room = by_name.get(room_name)
	if r == null:
		errors.append("feature %s on unknown room %s" % [kind, room_name])
		return
	var f := opts.duplicate()
	f.kind = kind
	f.side = side
	f.t = t
	if not r.opts.has("features"):
		r.opts.features = []
	r.opts.features.append(f)


func get_room(name: String) -> Room:
	return by_name.get(name)


# ---------------------------------------------------------------- resolve

func resolve() -> bool:
	_share_walls()
	for l in links:
		_resolve_link(l)
	for r in rooms:
		_check_room(r)
	for r in rooms:
		for p in r.props:
			_check_prop(p)
	return errors.is_empty()


func _resolve_link(l: Link) -> void:
	l.room_a = by_name.get(l.a)
	l.room_b = by_name.get(l.b)
	if l.room_a == null or l.room_b == null:
		errors.append("%s: endpoint missing" % l.name)
		return
	if l.room_a == l.room_b:
		errors.append("%s: both ends are the same room" % l.name)
		return
	var A := l.room_a.rect
	var B := l.room_b.rect
	if A.end.x <= B.position.x + EPS:
		_set_axis(l, 0, 1, "e", "w", A.end.x, B.position.x)
	elif B.end.x <= A.position.x + EPS:
		_set_axis(l, 0, -1, "w", "e", A.position.x, B.end.x)
	elif A.end.y <= B.position.y + EPS:
		_set_axis(l, 1, 1, "s", "n", A.end.y, B.position.y)
	elif B.end.y <= A.position.y + EPS:
		_set_axis(l, 1, -1, "n", "s", A.position.y, B.end.y)
	else:
		errors.append("%s: rooms overlap, nothing to bridge" % l.name)
		return
	# Cross-axis: the link must fit inside both rooms' floors.
	var ra := _inner_cross(l.room_a, l.axis)
	var rb := _inner_cross(l.room_b, l.axis)
	var lo := maxf(ra.x, rb.x)
	var hi := minf(ra.y, rb.y)
	l.center = l.at if not is_nan(l.at) else (lo + hi) * 0.5
	for r in [l.room_a, l.room_b]:
		if r.round:
			var c: float = r.center().y if l.axis == 0 else r.center().x
			if absf(l.center - c) > 0.05:
				errors.append("%s: must meet round room %s on its centre line (%.2f vs %.2f)" % [l.name, r.name, l.center, c])
	if l.center - l.width * 0.5 < lo - EPS or l.center + l.width * 0.5 > hi + EPS:
		errors.append("%s: %.1f m wide at %.2f does not fit the shared floor %.2f..%.2f" % [l.name, l.width, l.center, lo, hi])
	# Walk span: from inside room a's floor to inside room b's floor.
	l.e0 = l.s0 - l.dir * _edge_depth(l.room_a, l.side_a, l.width)
	l.e1 = l.s1 + l.dir * _edge_depth(l.room_b, l.side_b, l.width)
	l.ya = l.room_a.y
	l.yb = l.room_b.y
	var dy := l.yb - l.ya
	var gap := l.gap()
	match l.kind:
		"door":
			if gap > EPS:
				errors.append("%s: door needs adjacent rooms, gap is %.2f m" % [l.name, gap])
			if absf(dy) > EPS:
				errors.append("%s: door between floors %.2f and %.2f" % [l.name, l.ya, l.yb])
		"bridge", "walk", "girder":
			if gap < 0.5:
				errors.append("%s: gap %.2f m too short for a %s" % [l.name, gap, l.kind])
			elif absf(dy) / gap > MAX_SLOPE + EPS:
				errors.append("%s: slope %.2f too steep" % [l.name, absf(dy) / gap])
			if gap > FREE_SPAN:
				l.posts = int(ceilf(gap / FREE_SPAN)) - 1
				notes.append("%s: %.1f m span, %d post(s) to the abyss floor" % [l.name, gap, l.posts])
		"stairs":
			l.steps = roundi(absf(dy) / STEP_RISE)
			if l.steps < 1 or absf(absf(dy) - l.steps * STEP_RISE) > EPS:
				errors.append("%s: rise %.2f is not a whole number of %.2f m steps" % [l.name, dy, STEP_RISE])
			elif gap / l.steps < MIN_RUN - EPS or gap / l.steps > MAX_RUN + EPS:
				errors.append("%s: %d steps over %.2f m gives a %.2f m tread" % [l.name, l.steps, gap, gap / l.steps])
		_:
			errors.append("%s: unknown link kind" % l.name)
	l.room_a.openings.append({"side": l.side_a, "lo": l.center - l.width * 0.5, "hi": l.center + l.width * 0.5, "link": l})
	l.room_b.openings.append({"side": l.side_b, "lo": l.center - l.width * 0.5, "hi": l.center + l.width * 0.5, "link": l})


## Where two rooms touch, only one wall stands on the shared edge: the one
## whose top is higher. The other room's floor runs over its own wall band
## up to that wall (in the walk grid and in the build alike).
func _share_walls() -> void:
	for i in rooms.size():
		for j in range(i + 1, rooms.size()):
			var A := rooms[i]
			var B := rooms[j]
			if A.round or B.round:
				continue
			var pairs := []
			if absf(A.rect.end.x - B.rect.position.x) < EPS:
				pairs.append([A, "e", B, "w", 1])
			if absf(B.rect.end.x - A.rect.position.x) < EPS:
				pairs.append([B, "e", A, "w", 1])
			if absf(A.rect.end.y - B.rect.position.y) < EPS:
				pairs.append([A, "s", B, "n", 0])
			if absf(B.rect.end.y - A.rect.position.y) < EPS:
				pairs.append([B, "s", A, "n", 0])
			for pr in pairs:
				var P: Room = pr[0]
				var Q: Room = pr[2]
				var along_x: bool = pr[4] == 0
				var lo := maxf(P.rect.position.x, Q.rect.position.x) if along_x else maxf(P.rect.position.y, Q.rect.position.y)
				var hi := minf(P.rect.end.x, Q.rect.end.x) if along_x else minf(P.rect.end.y, Q.rect.end.y)
				if hi - lo < 0.1:
					continue
				var top_p: float = P.y + P.walls.get(pr[1], 0.0)
				var top_q: float = Q.y + Q.walls.get(pr[3], 0.0)
				var owner := P if top_p >= top_q else Q
				P.shared.append({"side": pr[1], "lo": lo, "hi": hi, "other": Q, "owner": owner == P})
				Q.shared.append({"side": pr[3], "lo": lo, "hi": hi, "other": P, "owner": owner == Q})
				var loser := Q if owner == P else P
				var lside: String = pr[3] if owner == P else pr[1]
				if loser.walls.get(lside, 0.0) <= 0.0:
					continue
				# The loser's floor takes over its wall band along the shared part.
				var inner := loser.inner()
				var a := maxf(lo, inner.position.x if along_x else inner.position.y)
				var b := minf(hi, inner.end.x if along_x else inner.end.y)
				if b - a < 0.05:
					continue
				var t := loser.wall_t
				var band: Rect2
				match lside:
					"n":
						band = Rect2(a, loser.rect.position.y, b - a, t)
					"s":
						band = Rect2(a, loser.rect.end.y - t, b - a, t)
					"w":
						band = Rect2(loser.rect.position.x, a, t, b - a)
					_:
						band = Rect2(loser.rect.end.x - t, a, t, b - a)
				loser.extra_floor.append(band)


func _set_axis(l: Link, axis: int, dir: int, sa: String, sb: String, s0: float, s1: float) -> void:
	l.axis = axis
	l.dir = dir
	l.side_a = sa
	l.side_b = sb
	l.s0 = s0
	l.s1 = s1


## Usable cross-axis range of a room's floor for a link running along `axis`.
func _inner_cross(r: Room, axis: int) -> Vector2:
	var inner := r.inner()
	if axis == 0:
		return Vector2(inner.position.y, inner.end.y)
	return Vector2(inner.position.x, inner.end.x)


## How far a link must reach in from the outer edge to meet real floor.
func _edge_depth(r: Room, side: String, width: float) -> float:
	if not r.round:
		return r.inset(side)
	# A round floor curves away from the outer edge towards the link's sides.
	var rad := r.radius() - r.wall_t
	var half := width * 0.5
	return r.radius() - sqrt(maxf(rad * rad - half * half, 0.0)) + CELL


func _check_room(r: Room) -> void:
	match r.support:
		"pillar", "posts":
			pass
		"links":
			# Carried by two aligned links whose far ends stand on their own.
			var ok := false
			for l in links:
				for m in links:
					if l == m or l.room_a == null or m.room_a == null:
						continue
					var lr := l.room_b if l.room_a == r else (l.room_a if l.room_b == r else null)
					var mr := m.room_b if m.room_a == r else (m.room_a if m.room_b == r else null)
					if lr != null and mr != null and l.axis == m.axis and lr != mr \
							and lr.support != "links" and mr.support != "links" and absf(l.center - m.center) < EPS:
						ok = true
			if not ok:
				errors.append("room %s hangs on links but has no straight pair of supported links" % r.name)
		_:
			errors.append("room %s: unknown support %s" % [r.name, r.support])


func _check_prop(p: Prop) -> void:
	if not p.room.has_floor(p.pos):
		errors.append("prop %s in %s at (%.2f, %.2f) is off the floor" % [p.kind, p.room.name, p.pos.x, p.pos.y])
	if not p.blocks:
		return
	var half := Props.rotated_half(p.size, p.rot)
	var box := Rect2(p.pos - half, half * 2.0)
	for l in links:
		if l.room_a == p.room or l.room_b == p.room:
			# Keep a clear apron where each link enters the room.
			var lane := l.plan_rect()
			if l.axis == 0:
				lane = lane.grow_individual(0.75, 0.2, 0.75, 0.2)
			else:
				lane = lane.grow_individual(0.2, 0.75, 0.2, 0.75)
			if box.intersects(lane):
				errors.append("prop %s in %s blocks %s" % [p.kind, p.room.name, l.name])


# -------------------------------------------------------------- walk grid

class Grid:
	var origin := Vector2.ZERO
	var w := 0
	var h := 0
	var height := PackedFloat32Array()
	var area := PackedInt32Array()      # room index, or 1000 + link index, or -1
	var blocked := PackedByteArray()

	func idx(c: Vector2i) -> int:
		return c.y * w + c.x

	func cell_of(p: Vector2) -> Vector2i:
		return Vector2i(floori((p.x - origin.x) / CELL), floori((p.y - origin.y) / CELL))

	func center_of(c: Vector2i) -> Vector2:
		return origin + (Vector2(c) + Vector2(0.5, 0.5)) * CELL

	func valid(c: Vector2i) -> bool:
		return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h

	func walkable(c: Vector2i) -> bool:
		if not valid(c):
			return false
		var i := idx(c)
		return area[i] >= 0 and blocked[i] == 0

	## Floor height at a plan point, NAN where there is nothing to stand on.
	func floor_at(p: Vector2) -> float:
		var c := cell_of(p)
		return height[idx(c)] if walkable(c) else NAN


func build_grid() -> Grid:
	var g := Grid.new()
	var bounds := rooms[0].rect
	for r in rooms:
		bounds = bounds.merge(r.rect)
	bounds = bounds.grow(1.0)
	g.origin = bounds.position
	g.w = ceili(bounds.size.x / CELL)
	g.h = ceili(bounds.size.y / CELL)
	g.height.resize(g.w * g.h)
	g.area.resize(g.w * g.h)
	g.blocked.resize(g.w * g.h)
	g.area.fill(-1)
	g.height.fill(NAN)
	for r in rooms:
		_fill(g, r.rect, func(p): return r.has_floor(p), func(_p): return r.y, r.index)
	for l in links:
		if l.room_a == null or l.room_b == null:
			continue
		_fill(g, l.plan_rect(), func(_p): return true,
			func(p): return l.height_at(p.x if l.axis == 0 else p.y), 1000 + l.index)
	for r in rooms:
		for p in r.props:
			if p.blocks:
				var half := Props.rotated_half(p.size, p.rot)
				var rect := Rect2(p.pos - half, half * 2.0)
				var c0 := g.cell_of(rect.position)
				var c1 := g.cell_of(rect.end)
				for cy in range(c0.y, c1.y + 1):
					for cx in range(c0.x, c1.x + 1):
						var c := Vector2i(cx, cy)
						if g.valid(c) and rect.has_point(g.center_of(c)):
							g.blocked[g.idx(c)] = 1
	return g


func _fill(g: Grid, rect: Rect2, inside: Callable, height: Callable, area_id: int) -> void:
	var c0 := g.cell_of(rect.position)
	var c1 := g.cell_of(rect.end)
	for cy in range(maxi(c0.y, 0), mini(c1.y + 1, g.h)):
		for cx in range(maxi(c0.x, 0), mini(c1.x + 1, g.w)):
			var c := Vector2i(cx, cy)
			var p := g.center_of(c)
			if rect.has_point(p) and inside.call(p):
				var i := g.idx(c)
				g.height[i] = height.call(p)
				g.area[i] = area_id


func area_name(id: int) -> String:
	if id >= 1000:
		return links[id - 1000].name
	return rooms[id].name


func spawn_point() -> Vector3:
	var r: Room = by_name.get(spawn_room)
	var inner := r.inner()
	var p := inner.position + inner.size * spawn_at
	return Vector3(p.x, r.y, p.y)


# ----------------------------------------------------------------- checks

## Every walkable cell reachable from the spawn, every link landing on
## real floor at both ends. Returns a printable report; `ok` in the result.
func check(g: Grid) -> Dictionary:
	var lines: PackedStringArray = []
	var ok := errors.is_empty()
	for e in errors:
		lines.append("ERROR layout: " + e)
	var sp := spawn_point()
	var start := g.cell_of(Vector2(sp.x, sp.z))
	if not g.walkable(start):
		lines.append("ERROR spawn (%.2f, %.2f) is not walkable" % [sp.x, sp.z])
		return {"ok": false, "text": "\n".join(lines)}
	var seen := PackedByteArray()
	seen.resize(g.w * g.h)
	var queue: Array[Vector2i] = [start]
	seen[g.idx(start)] = 1
	var head := 0
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		var hc := g.height[g.idx(c)]
		for d in dirs:
			var n: Vector2i = c + d
			if g.walkable(n) and seen[g.idx(n)] == 0 and absf(g.height[g.idx(n)] - hc) <= MAX_STEP:
				seen[g.idx(n)] = 1
				queue.append(n)
	var total := {}
	var reached := {}
	var stray := {}
	for i in g.w * g.h:
		if g.area[i] >= 0 and g.blocked[i] == 0:
			total[g.area[i]] = total.get(g.area[i], 0) + 1
			if seen[i]:
				reached[g.area[i]] = reached.get(g.area[i], 0) + 1
			elif not stray.has(g.area[i]):
				stray[g.area[i]] = g.center_of(Vector2i(i % g.w, i / g.w))
	for r in rooms:
		var t: int = total.get(r.index, 0)
		var n: int = reached.get(r.index, 0)
		var status := "ok" if t > 0 and n == t else "UNREACHABLE"
		if status != "ok":
			ok = false
		lines.append("%-4s room %-10s %4d/%4d cells  floor %+.1f%s" % [status if status == "ok" else "FAIL", r.name, n, t, r.y,
			("  first unreachable cell at (%.2f, %.2f)" % [stray[r.index].x, stray[r.index].y]) if stray.has(r.index) else ""])
	for l in links:
		if l.room_a == null or l.room_b == null:
			continue
		var t: int = total.get(1000 + l.index, 0)
		var n: int = reached.get(1000 + l.index, 0)
		var ends := _ends_ok(g, l)
		var good := t > 0 and n == t and ends == ""
		if not good:
			ok = false
		lines.append("%-4s link %-28s %4d/%4d cells  gap %4.1f m  %s%s" % [
			"ok" if good else "FAIL", l.name, n, t, l.gap(),
			("%d steps" % l.steps) if l.kind == "stairs" else ("rise %+.1f" % (l.yb - l.ya)),
			"" if ends == "" else "  " + ends])
	for note in notes:
		lines.append("note " + note)
	lines.append("reachability: %s" % ("every walkable cell is reachable from the spawn in %s" % spawn_room if ok else "FAILED"))
	return {"ok": ok, "text": "\n".join(lines)}


## A link must land on its rooms' floors at matching heights at both ends.
func _ends_ok(g: Grid, l: Link) -> String:
	var probes := [[l.e0 - l.dir * CELL, l.room_a], [l.e1 + l.dir * CELL, l.room_b]]
	for pr in probes:
		var s: float = pr[0]
		var r: Room = pr[1]
		var p := Vector2(s, l.center) if l.axis == 0 else Vector2(l.center, s)
		var c := g.cell_of(p)
		if not g.valid(c) or g.area[g.idx(c)] != r.index:
			return "no floor of %s at (%.2f, %.2f)" % [r.name, p.x, p.y]
		if absf(g.height[g.idx(c)] - l.height_at(s)) > EPS:
			return "height mismatch at %s" % r.name
	return ""
