class_name WalkGrid
extends RefCounted
## Walkable surface as a grid of cells (CELL metres) with a floor height each.
## Built from the solved layout: room floors minus parapets (except where a
## connection opens them), plus each connection's strip ramping between the
## two rooms' heights. Props punch blocked circles into it.

const CELL := 0.25
const MAX_STEP := 0.3   # max height change between neighbouring cells

var height := {}   # Vector2i -> float
var owner := {}    # Vector2i -> room or link name
var rooms := {}


func _init(solved: Dictionary) -> void:
	rooms = solved.rooms
	for room in rooms.values():
		_add_room(room)
	for link in solved.links:
		_add_link(link)


static func key(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


static func centre(k: Vector2i) -> Vector2:
	return (Vector2(k) + Vector2(0.5, 0.5)) * CELL


func _add_room(room: Dictionary) -> void:
	var r: Rect2 = room.rect
	var k0 := key(r.position)
	var k1 := key(r.end)
	for x in range(k0.x, k1.x + 1):
		for z in range(k0.y, k1.y + 1):
			var k := Vector2i(x, z)
			var p := centre(k)
			if Layout.inside(room, p, 0.15) and not _in_wall(room, p):
				height[k] = room.y
				owner[k] = room.name


func _in_wall(room: Dictionary, p: Vector2) -> bool:
	var t := Layout.WALL_T + 0.1
	if room.shape == "circle":
		if room.walls.get("rim", 0.0) <= 0.0 or p.distance_to(room.center) < room.radius - t:
			return false
		var ang: float = (p - room.center).angle()
		for o in room.openings.rim:
			if _ang_in(ang, o):
				return false
		return true
	var r: Rect2 = room.rect
	var sides := {"w": [p.x - r.position.x, p.y], "e": [r.end.x - p.x, p.y],
		"n": [p.y - r.position.y, p.x], "s": [r.end.y - p.y, p.x]}
	for side in sides:
		if room.walls.get(side, 0.0) <= 0.0 or sides[side][0] > t:
			continue
		var along: float = sides[side][1]
		var open := false
		for o in room.openings[side]:
			if along > o.x + 0.15 and along < o.y - 0.15:
				open = true
		if not open:
			return true
	return false


static func _ang_in(a: float, o: Vector2) -> bool:
	var mid := (o.x + o.y) * 0.5
	return abs(wrapf(a - mid, -PI, PI)) <= (o.y - o.x) * 0.5


func _add_link(link: Dictionary) -> void:
	var dir: Vector2 = link.dir
	var w0: Vector2 = link.w0
	var w1: Vector2 = link.w1
	var a_y: float = link.p0.y
	var b_y: float = link.p1.y
	var e0 := Vector2(link.p0.x, link.p0.z).dot(dir)
	var e1 := Vector2(link.p1.x, link.p1.z).dot(dir)
	var cross_dir := Vector2(-dir.y, dir.x)
	var half: float = link.width * 0.5 - 0.2
	var length := w0.distance_to(w1)
	var steps := int(length / (CELL * 0.5)) + 1
	for i in steps + 1:
		var p := w0.lerp(w1, float(i) / steps)
		var t := clampf((p.dot(dir) - e0) / max(e1 - e0, 0.001), 0.0, 1.0)
		var y := lerpf(a_y, b_y, t)
		var c := -half
		while c <= half + 0.001:
			var k := key(p + cross_dir * c)
			height[k] = y
			owner[k] = "%s>%s" % [link.a, link.b]
			c += CELL * 0.5


func block(p: Vector2, radius: float) -> void:
	var k0 := key(p - Vector2(radius, radius))
	var k1 := key(p + Vector2(radius, radius))
	for x in range(k0.x, k1.x + 1):
		for z in range(k0.y, k1.y + 1):
			var k := Vector2i(x, z)
			if centre(k).distance_to(p) <= radius:
				height.erase(k)


func walkable(p: Vector2) -> bool:
	return height.has(key(p))


func height_at(p: Vector2) -> float:
	return height.get(key(p), -1000.0)


func can_step(from: Vector2, to: Vector2) -> bool:
	var a := key(from)
	var b := key(to)
	if not height.has(b):
		return false
	if not height.has(a):
		return true
	return abs(height[b] - height[a]) <= MAX_STEP * max(1.0, from.distance_to(to) / CELL)


func spawn_point() -> Vector2:
	var room: Dictionary = rooms[Layout.SPAWN_ROOM]
	var target: Vector2 = room.rect.get_center() + Vector2(0, room.rect.size.y * 0.2)
	var best := Vector2i.ZERO
	var best_d := INF
	for k in height:
		if owner[k] == room.name and centre(k).distance_to(target) < best_d:
			best_d = centre(k).distance_to(target)
			best = k
	return centre(best)


## BFS from spawn. Returns {reachable, total, rooms: {name: [reached, total]}, unreached: [owners]}.
func reachability() -> Dictionary:
	var start := key(spawn_point())
	var seen := {start: true}
	var queue := [start]
	var head := 0
	while head < queue.size():
		var k: Vector2i = queue[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = k + d
			if seen.has(n) or not height.has(n):
				continue
			if abs(height[n] - height[k]) > MAX_STEP:
				continue
			seen[n] = true
			queue.append(n)
	var per := {}
	for k in height:
		var o: String = owner[k]
		if not per.has(o):
			per[o] = [0, 0]
		per[o][1] += 1
		if seen.has(k):
			per[o][0] += 1
	var unreached := []
	for o in per:
		if per[o][0] < per[o][1]:
			var where := Vector2.ZERO
			for k in height:
				if owner[k] == o and not seen.has(k):
					where = centre(k)
					break
			unreached.append("%s (%d/%d), e.g. at x=%.2f z=%.2f" % [o, per[o][0], per[o][1], where.x, where.y])
	for name in rooms:
		if not per.has(name):
			unreached.append("%s (no floor)" % name)
	return {"reachable": seen.size(), "total": height.size(), "per": per, "unreached": unreached}
