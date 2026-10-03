class_name Layout
extends RefCounted
## Declarative layout of the keep, derived from reference/reference.png.
##
## World axes: +x east (screen right), +z south (toward the camera), +y up.
## Rooms are named platforms. Connections join two *named* rooms; their
## geometry (span, height ramp, wall openings) is solved from the rooms, so a
## bridge to nowhere cannot be written. `solve()` fails loudly if a
## connection's rooms do not face each other across a gap (or share an edge,
## for doors).

const WALL_T := 0.55        # parapet thickness, inside the room rect
const ENTER := 0.9          # how far a connection's walk strip reaches into a room

# Rooms. rect = Rect2(x0, z0, width, depth); circle rooms use center + radius.
# walls: parapet height per side (n, s, e, w); 0 = open edge.
# tall: sides that carry a high wall with arched windows.
const ROOMS := [
	{"name": "keep", "rect": Rect2(-20.5, -22, 7, 9), "y": 2.5,
		"walls": {"n": 3.4, "s": 1.1, "e": 1.1, "w": 2.6}, "tall": ["n"], "floor": "flag"},
	{"name": "study", "rect": Rect2(-12, -21, 9, 9), "y": 1.2,
		"walls": {"n": 2.6, "s": 1.0, "e": 1.1, "w": 1.1}, "tall": ["n"], "floor": "cobble"},
	{"name": "forge", "rect": Rect2(-21.5, -10.5, 8, 10.5), "y": 0.0,
		"walls": {"n": 1.8, "s": 1.0, "e": 1.0, "w": 2.8}, "tall": ["w"], "floor": "cobble"},
	{"name": "chapel", "rect": Rect2(-20, 2, 11, 6), "y": -0.6,
		"walls": {"n": 1.6, "s": 1.1, "e": 1.0, "w": 2.2}, "tall": [], "floor": "flag"},
	{"name": "nave", "rect": Rect2(-7.5, -9.5, 6, 17), "y": 0.0,
		"walls": {"n": 1.0, "s": 0.0, "e": 1.3, "w": 1.8}, "tall": [], "floor": "cobble"},
	{"name": "pier", "rect": Rect2(-7, 7.5, 5, 4.5), "y": 0.0,
		"walls": {"n": 0.0, "s": 1.0, "e": 1.0, "w": 1.0}, "tall": [], "floor": "cobble"},
	{"name": "shrine", "rect": Rect2(3, -22, 11, 14), "y": 0.8,
		"walls": {"n": 4.2, "s": 1.0, "e": 1.8, "w": 1.8}, "tall": ["n"], "floor": "flag"},
	{"name": "dais", "center": Vector2(9.5, -2), "radius": 4.6, "y": 0.3,
		"walls": {"rim": 0.8}, "tall": [], "floor": "ring"},
	{"name": "treasury", "rect": Rect2(15.5, -19.5, 7, 13.5), "y": 0.8,
		"walls": {"n": 2.8, "s": 1.0, "e": 2.2, "w": 1.6}, "tall": ["n"], "floor": "cobble"},
	{"name": "landing", "rect": Rect2(16.5, -3.5, 4, 6), "y": 0.3,
		"walls": {"n": 0.9, "s": 0.9, "e": 1.6, "w": 0.9}, "tall": [], "floor": "cobble"},
	{"name": "lift", "rect": Rect2(0, -0.2, 3.4, 3.2), "y": -0.4,
		"walls": {"n": 0.0, "s": 0.0, "e": 0.0, "w": 0.0}, "tall": [], "floor": "plate"},
	{"name": "hall", "rect": Rect2(5.5, 4.2, 14, 8.5), "y": -0.8,
		"walls": {"n": 1.6, "s": 1.2, "e": 2.0, "w": 1.4}, "tall": [], "floor": "cobble"},
	{"name": "dock", "rect": Rect2(1, 8.8, 3.5, 3.5), "y": -1.6,
		"walls": {"n": 0.9, "s": 1.0, "e": 0.0, "w": 1.0}, "tall": [], "floor": "cobble"},
]

# Connections between two named rooms. offset shifts the strip along the
# shared edge from the centre of the overlap (or sets `at`, a world coordinate).
const CONNECTIONS := [
	{"kind": "stairs", "a": "keep", "b": "study", "width": 2.4},
	{"kind": "stairs", "a": "keep", "b": "forge", "width": 2.6, "at": -17.0},
	{"kind": "stairs", "a": "study", "b": "nave", "width": 2.4, "at": -5.2},
	{"kind": "bridge", "a": "forge", "b": "nave", "width": 2.4, "at": -5.0},
	{"kind": "stairs", "a": "forge", "b": "chapel", "width": 2.4, "at": -16.5},
	{"kind": "stairs", "a": "chapel", "b": "nave", "width": 2.0, "at": 5.0},
	{"kind": "door", "a": "nave", "b": "pier", "width": 5.0},
	{"kind": "bridge", "a": "study", "b": "shrine", "width": 2.2, "at": -18.0, "style": "iron"},
	{"kind": "bridge", "a": "shrine", "b": "treasury", "width": 2.2, "at": -15.0},
	{"kind": "bridge", "a": "nave", "b": "dais", "width": 2.6, "at": -3.0},
	{"kind": "stairs", "a": "shrine", "b": "dais", "width": 2.6, "at": 9.5},
	{"kind": "bridge", "a": "dais", "b": "landing", "width": 2.4, "at": -1.0},
	{"kind": "bridge", "a": "landing", "b": "treasury", "width": 2.2, "at": 18.5},
	{"kind": "stairs", "a": "dais", "b": "hall", "width": 2.4, "at": 11.0},
	{"kind": "bridge", "a": "nave", "b": "lift", "width": 1.6, "at": 1.4},
	{"kind": "bridge", "a": "nave", "b": "hall", "width": 2.0, "at": 5.85},
	{"kind": "stairs", "a": "hall", "b": "dock", "width": 2.0, "at": 10.5},
]

const SPAWN_ROOM := "nave"

# Props per room: [type, u, v, rot_deg, extra]; u, v are fractions of the
# room's rect (or of the circle's bounding square). Walk-blocking props
# carry a footprint radius in Props.FOOTPRINT.
const PROPS := {
	"keep": [["candelabra", 0.2, 0.25, 0], ["candelabra", 0.8, 0.25, 0], ["knight", 0.55, 0.3, 200],
		["candles", 0.3, 0.2, 0], ["banner", 0.5, 0.0, 0]],
	"study": [["desk", 0.55, 0.3, 0], ["carpet", 0.55, 0.62, 0, Vector2(2.0, 3.2)], ["candles", 0.35, 0.25, 0],
		["candles", 0.75, 0.22, 0], ["knight", 0.25, 0.4, 160], ["bookcase", 0.25, 0.06, 0], ["bookcase", 0.8, 0.06, 0]],
	"forge": [["hearth", 0.35, 0.25, 0], ["anvil", 0.55, 0.5, 30], ["table", 0.35, 0.72, 0], ["barrel", 0.82, 0.2, 0],
		["barrel", 0.88, 0.32, 0], ["candles", 0.75, 0.75, 0], ["crate", 0.22, 0.8, 10]],
	"chapel": [["statue_big", 0.2, 0.45, 160], ["candles", 0.1, 0.25, 0], ["candles", 0.33, 0.3, 0],
		["candles", 0.32, 0.7, 0], ["knight", 0.62, 0.55, 190], ["candelabra", 0.8, 0.35, 0], ["crate", 0.65, 0.25, 0]],
	"nave": [["carpet", 0.45, 0.42, 0, Vector2(2.2, 9.0)], ["knight", 0.5, 0.2, 180], ["candelabra", 0.12, 0.08, 0],
		["candelabra", 0.88, 0.08, 0], ["candelabra", 0.12, 0.6, 0], ["candelabra", 0.88, 0.6, 0], ["statue_small", 0.85, 0.3, 0]],
	"pier": [["knight", 0.5, 0.45, 200], ["candles", 0.85, 0.2, 0], ["candelabra", 0.12, 0.85, 0]],
	"shrine": [["shrine_statue", 0.5, 0.08, 0], ["altar", 0.5, 0.24, 0], ["carpet", 0.5, 0.62, 0, Vector2(2.0, 5.5)],
		["knight", 0.22, 0.55, 150], ["knight", 0.78, 0.55, 210], ["candelabra", 0.12, 0.88, 0], ["candelabra", 0.88, 0.88, 0],
		["barrel", 0.1, 0.2, 0], ["crate", 0.88, 0.25, 0]],
	"dais": [["orrery", 0.5, 0.5, 0], ["knight", 0.18, 0.62, 120], ["candelabra", 0.22, 0.32, 0], ["candelabra", 0.78, 0.32, 0],
		["candelabra", 0.5, 0.92, 0]],
	"treasury": [["gold", 0.4, 0.35, 0], ["gold", 0.65, 0.55, 0], ["chest", 0.25, 0.65, 90], ["chest", 0.75, 0.2, 0],
		["knight", 0.55, 0.78, 180], ["candles", 0.85, 0.75, 0], ["candles", 0.15, 0.2, 0], ["bookcase", 0.5, 0.06, 0]],
	"landing": [["candelabra", 0.8, 0.8, 0]],
	"dock": [["knight", 0.45, 0.5, 170], ["candles", 0.2, 0.25, 0], ["barrel", 0.75, 0.75, 0]],
	"lift": [["winch", 0.5, 0.5, 0]],
	"hall": [["knight", 0.12, 0.3, 160], ["knight", 0.88, 0.2, 220], ["table", 0.6, 0.55, 0], ["chest", 0.85, 0.75, 0],
		["barrel", 0.92, 0.45, 0], ["candles", 0.6, 0.35, 0], ["candles", 0.35, 0.75, 0], ["candelabra", 0.08, 0.85, 0],
		["candelabra", 0.5, 0.12, 0], ["crate", 0.75, 0.82, 20], ["carpet", 0.6, 0.55, 90, Vector2(2.4, 4.0)]],
}


## Returns {rooms: {name: room}, links: [link]}, or {} after reporting an error.
static func solve() -> Dictionary:
	var rooms := {}
	for src in ROOMS:
		var r: Dictionary = src.duplicate(true)
		if r.has("center"):
			var c: Vector2 = r.center
			r.rect = Rect2(c.x - r.radius, c.y - r.radius, r.radius * 2.0, r.radius * 2.0)
			r.shape = "circle"
		else:
			r.shape = "rect"
		r.openings = {"n": [], "s": [], "e": [], "w": [], "rim": []}
		if rooms.has(r.name):
			return _fail("duplicate room " + r.name)
		rooms[r.name] = r
	var names := rooms.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Rect2 = rooms[names[i]].rect
			var b: Rect2 = rooms[names[j]].rect
			if a.intersection(b).get_area() > 0.001:
				return _fail("rooms overlap: %s / %s" % [names[i], names[j]])
	var links := []
	for c in CONNECTIONS:
		if not rooms.has(c.a) or not rooms.has(c.b):
			return _fail("connection to unknown room: %s -> %s" % [c.a, c.b])
		var link := _solve_link(c, rooms[c.a], rooms[c.b])
		if link.is_empty():
			return {}
		links.append(link)
	return {"rooms": rooms, "links": links}


static func _fail(msg: String) -> Dictionary:
	push_error("layout: " + msg)
	return {}


# Finds the side of A that faces B, the overlap along that side, and the span.
static func _solve_link(c: Dictionary, a: Dictionary, b: Dictionary) -> Dictionary:
	var ra: Rect2 = a.rect
	var rb: Rect2 = b.rect
	var dir := Vector2.ZERO
	var gap := 0.0
	if rb.position.x >= ra.end.x - 0.001:
		dir = Vector2(1, 0); gap = rb.position.x - ra.end.x
	elif ra.position.x >= rb.end.x - 0.001:
		dir = Vector2(-1, 0); gap = ra.position.x - rb.end.x
	if rb.position.y >= ra.end.y - 0.001 or ra.position.y >= rb.end.y - 0.001:
		if dir != Vector2.ZERO:
			return _fail("%s -> %s: rooms are diagonal, no shared side" % [a.name, b.name])
		if rb.position.y >= ra.end.y - 0.001:
			dir = Vector2(0, 1); gap = rb.position.y - ra.end.y
		else:
			dir = Vector2(0, -1); gap = ra.position.y - rb.end.y
	if dir == Vector2.ZERO:
		return _fail("%s -> %s: rooms do not face each other" % [a.name, b.name])
	var along_x := dir.x == 0.0   # the strip runs along z; its cross axis is x
	var lo: float = max(ra.position.x, rb.position.x) if along_x else max(ra.position.y, rb.position.y)
	var hi: float = min(ra.end.x, rb.end.x) if along_x else min(ra.end.y, rb.end.y)
	var w: float = c.width
	var centre: float = c.get("at", (lo + hi) * 0.5 + c.get("offset", 0.0))
	if centre - w * 0.5 < lo + WALL_T - 0.01 or centre + w * 0.5 > hi - WALL_T + 0.01:
		if not (c.kind == "door" and centre - w * 0.5 >= lo - 0.01 and centre + w * 0.5 <= hi + 0.01):
			return _fail("%s -> %s: %.1fm strip at %.1f does not fit the shared side [%.1f, %.1f]" % [a.name, b.name, w, centre, lo, hi])
	if c.kind == "door":
		if gap > 0.01:
			return _fail("%s -> %s: door needs touching rooms (gap %.2f)" % [a.name, b.name, gap])
		if abs(a.y - b.y) > 0.05:
			return _fail("%s -> %s: door between different heights" % [a.name, b.name])
	elif gap < 0.5:
		return _fail("%s -> %s: %s needs a gap to span" % [a.name, b.name, c.kind])
	if c.kind == "stairs" and abs(a.y - b.y) < 0.2:
		return _fail("%s -> %s: stairs without a height change" % [a.name, b.name])
	if c.kind == "bridge" and abs(a.y - b.y) / max(gap, 0.01) > 0.35:
		return _fail("%s -> %s: bridge too steep, use stairs" % [a.name, b.name])
	# Edge coordinates (along dir) where the strip leaves A and meets B.
	var axis := 0 if dir.x != 0.0 else 1
	var edge_a: float = (ra.end[axis] if (dir.x + dir.y) > 0 else ra.position[axis])
	var edge_b: float = (rb.position[axis] if (dir.x + dir.y) > 0 else rb.end[axis])
	edge_a = _shape_edge(a, edge_a, centre, axis, -(dir.x + dir.y))
	edge_b = _shape_edge(b, edge_b, centre, axis, dir.x + dir.y)
	if abs(edge_b - edge_a) < 0.01 and c.kind != "door":
		return _fail("%s -> %s: zero-length span" % [a.name, b.name])
	var s := dir.x + dir.y
	var p0 := _pt(axis, edge_a, centre)
	var p1 := _pt(axis, edge_b, centre)
	var link := {"kind": c.kind, "a": a.name, "b": b.name, "width": w, "dir": dir,
		"style": c.get("style", "wood"),
		# span ends at the room edges, plus walk-strip ends reaching into the rooms
		"p0": Vector3(p0.x, a.y, p0.y), "p1": Vector3(p1.x, b.y, p1.y),
		"w0": _pt(axis, edge_a - s * ENTER, centre), "w1": _pt(axis, edge_b + s * ENTER, centre)}
	_open(a, dir, centre, w)
	_open(b, -dir, centre, w)
	return link


# For circle rooms, the edge along the strip's centre line sits on the circle.
static func _shape_edge(room: Dictionary, edge: float, centre: float, axis: int, toward: float) -> float:
	if room.shape != "circle":
		return edge
	var c: Vector2 = room.center
	var cross: float = centre - (c.y if axis == 0 else c.x)
	var half := sqrt(max(room.radius * room.radius - cross * cross, 0.0))
	var mid: float = c.x if axis == 0 else c.y
	return mid - toward * half


static func _pt(axis: int, along: float, cross: float) -> Vector2:
	return Vector2(along, cross) if axis == 0 else Vector2(cross, along)


static func _open(room: Dictionary, dir: Vector2, centre: float, w: float) -> void:
	if room.shape == "circle":
		var ang := atan2(dir.y, dir.x)
		var half := asin(clamp((w * 0.5 + 0.3) / room.radius, 0.0, 1.0))
		room.openings.rim.append(Vector2(ang - half, ang + half))
		return
	var side := "e" if dir.x > 0 else "w" if dir.x < 0 else "s" if dir.y > 0 else "n"
	room.openings[side].append(Vector2(centre - w * 0.5, centre + w * 0.5))


## Room floor test in world xz (ignores walls).
static func inside(room: Dictionary, p: Vector2, margin := 0.0) -> bool:
	if room.shape == "circle":
		return p.distance_to(room.center) <= room.radius - margin
	var r: Rect2 = room.rect.grow(-margin)
	return r.has_point(p)


## Prop world position from (u, v) fractions.
static func prop_pos(room: Dictionary, u: float, v: float) -> Vector3:
	var r: Rect2 = room.rect
	return Vector3(r.position.x + r.size.x * u, room.y, r.position.y + r.size.y * v)
