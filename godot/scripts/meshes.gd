class_name Meshes
extends RefCounted
## Procedural meshes. Every face is emitted clockwise (Godot's front face).


## Unit cube [-0.5, 0.5]^3 with chamfered edges (bevel b in unit space),
## flat shaded so the chamfers catch light like chipped stone edges.
static func bevel_box(b: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 0.5
	var i := 0.5 - b
	# 6 faces
	for axis in 3:
		for s in [-1.0, 1.0]:
			var pts := []
			for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				pts.append(_axis_pt(axis, s * h, c.x * i, c.y * i))
			_poly(st, pts)
	# 12 edges
	for axis in 3:   # edge runs along this axis
		var a1 := (axis + 1) % 3
		var a2 := (axis + 2) % 3
		for s1 in [-1.0, 1.0]:
			for s2 in [-1.0, 1.0]:
				var pts := []
				for e in [-1.0, 1.0]:
					var p := Vector3.ZERO
					p[axis] = e * i
					p[a1] = s1 * h
					p[a2] = s2 * i
					pts.append(p)
				for e in [1.0, -1.0]:
					var p := Vector3.ZERO
					p[axis] = e * i
					p[a1] = s1 * i
					p[a2] = s2 * h
					pts.append(p)
				_poly(st, pts)
	# 8 corners
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_poly(st, [Vector3(sx * h, sy * i, sz * i), Vector3(sx * i, sy * h, sz * i), Vector3(sx * i, sy * i, sz * h)])
	return st.commit()


static func _axis_pt(axis: int, v: float, a: float, b: float) -> Vector3:
	var p := Vector3.ZERO
	p[axis] = v
	p[(axis + 1) % 3] = a
	p[(axis + 2) % 3] = b
	return p


## Emits a convex planar polygon as a fan, facing away from the origin.
static func _poly(st: SurfaceTool, pts: Array) -> void:
	var c := Vector3.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var n: Vector3 = (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
	if n.dot(c) > 0.0:   # counter-clockwise seen from outside: flip
		pts = pts.duplicate()
		pts.reverse()
		n = -n
	for k in range(1, pts.size() - 1):
		for p in [pts[0], pts[k], pts[k + 1]]:
			st.set_normal(-n)
			st.set_uv(Vector2(p.x + p.z, p.y) + Vector2(0.5, 0.5))
			st.add_vertex(p)


static func box() -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3.ONE
	return m


static func cylinder(segments := 12, top := 0.5, bottom := 0.5) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = 1.0
	m.radial_segments = segments
	m.rings = 1
	return m


static func sphere(segments := 12) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = segments
	m.rings = segments / 2
	return m


static func torus(inner := 0.42, outer := 0.5, segments := 48) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = segments
	m.ring_segments = 8
	return m


## Flame: a vertical teardrop quad pair (crossed), unit height.
static func flame() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for yaw in [0.0, PI * 0.5]:
		var r := Vector3(cos(yaw), 0, sin(yaw)) * 0.5
		var a := -r
		var b := r
		var top := Vector3(0, 1, 0)
		var quad := [[a, Vector2(0, 1)], [b, Vector2(1, 1)], [b + top, Vector2(1, 0)], [a + top, Vector2(0, 0)]]
		for idx in [0, 1, 2, 0, 2, 3, 0, 2, 1, 0, 3, 2]:
			st.set_uv(quad[idx][1])
			st.set_normal(Vector3(0, 0, 1))
			st.add_vertex(quad[idx][0])
	return st.commit()


## Gothic arch panel: unit-wide, unit-tall flat shape (pointed top), in xy.
static func arch_panel() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 0.6, 0)]
	var n := 8
	for k in range(1, n):
		var t := float(k) / n
		var ang := t * PI
		pts.append(Vector3(0.5 * cos(ang) * (1.0 - 0.15 * sin(ang)), 0.6 + 0.4 * pow(sin(ang), 0.7), 0))
	pts.append(Vector3(-0.5, 0.6, 0))
	var c := Vector3(0, 0.5, 0)
	for k in pts.size():
		var p0: Vector3 = pts[k]
		var p1: Vector3 = pts[(k + 1) % pts.size()]
		for p in [c, p1, p0]:
			st.set_normal(Vector3(0, 0, 1))
			st.set_uv(Vector2(p.x + 0.5, 1.0 - p.y))
			st.add_vertex(p)
	return st.commit()
