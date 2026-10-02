extends SceneTree
## Headless check: flood-fill the walk surfaces from the hero spawn and report
## whether every room is reachable.  godot --headless --path diorama --script res://tools/check.gd

const STEP := 0.25
const PROBES := {
	"gatehouse": Vector2(9.0, 5.0), "gatehouse dais": Vector2(6.0, -1.0), "study": Vector2(17.0, 4.0),
	"forge": Vector2(7.0, 22.0), "hall": Vector2(19.7, 27.0), "ruin": Vector2(9.0, 30.0),
	"chapel": Vector2(40.5, 11.0), "treasury": Vector2(51.0, 12.0), "mechanism": Vector2(40.5, 21.0),
	"barracks": Vector2(46.0, 40.0), "east landing": Vector2(53.5, 26.0), "lift": Vector2(28.0, 31.0),
	"low landing": Vector2(30.5, 40.6),
}

func _init() -> void:
	var layout := Layout.new(7)
	layout.generate()
	var seen := {}
	var start := Vector2(19.7, 27.5)
	var queue := [[start, 0.3]]
	seen[_key(start)] = 0.3
	while not queue.is_empty():
		var cur: Array = queue.pop_back()
		var p: Vector2 = cur[0]
		for d in [Vector2(STEP, 0), Vector2(-STEP, 0), Vector2(0, STEP), Vector2(0, -STEP)]:
			var q: Vector2 = p + d
			var k := _key(q)
			if seen.has(k):
				continue
			var h := Walk.height_at(layout.walk, q, cur[1], 0.35)
			if is_nan(h) or _blocked(layout, q):
				continue
			seen[k] = h
			queue.append([q, h])
	var ok := true
	for name in PROBES:
		var reached := false
		var c: Vector2 = PROBES[name]
		for dx in range(-4, 5):
			for dz in range(-4, 5):
				if seen.has(_key(c + Vector2(dx, dz) * STEP)):
					reached = true
		print("  %-15s %s" % [name, "reachable" if reached else "UNREACHABLE"])
		ok = ok and reached
	print("cells %d  %s" % [seen.size(), "all reachable" if ok else "FAILED"])
	quit(0 if ok else 1)

func _key(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x / STEP), roundi(p.y / STEP))

func _blocked(layout: Layout, p: Vector2) -> bool:
	for b in layout.blockers:
		if p.distance_to(Vector2(b.x, b.y)) < b.z + 0.2:
			return true
	return false
