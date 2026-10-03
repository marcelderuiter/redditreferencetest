class_name Player
extends Node3D
## The knight. Walks on the layout's walk grid (the same cells the
## reachability check flood-fills), steps up and down stairs, never off edges.

const SPEED := 2.6
const RUN := 1.9
const RADIUS := 0.22

var grid: Layout.Grid
var rig: Rig
var body := Node3D.new()
var legs: Array[Node3D] = []
var phase := 0.0
var floor_y := 0.0


func _init(g: Layout.Grid, spawn: Vector3, camera: Rig) -> void:
	grid = g
	rig = camera
	position = spawn
	floor_y = spawn.y
	name = "Player"


func _ready() -> void:
	add_child(body)
	_build_model()


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var moving := input.length() > 0.05
	if moving:
		var yaw := deg_to_rad(rig.yaw)
		var dir := Vector2(input.x, input.y).rotated(-yaw)
		var speed := SPEED * (RUN if Input.is_action_pressed("run") else 1.0)
		var step := dir * speed * delta
		var p := Vector2(position.x, position.z)
		# Slide along walls: try the full move, then each axis alone.
		for cand in [p + step, p + Vector2(step.x, 0), p + Vector2(0, step.y)]:
			var h := _stand_height(cand)
			if not is_nan(h):
				position.x = cand.x
				position.z = cand.y
				floor_y = h
				break
		body.rotation.y = lerp_angle(body.rotation.y, atan2(dir.x, dir.y), clampf(delta * 12.0, 0.0, 1.0))
		phase += delta * speed * 3.2
	else:
		phase = lerpf(phase, roundf(phase / PI) * PI, clampf(delta * 8.0, 0.0, 1.0))
	position.y = move_toward(position.y, floor_y, delta * 3.0)
	for i in legs.size():
		legs[i].rotation.x = sin(phase + i * PI) * 0.5
	if rig.follow:
		rig.focus = rig.focus.lerp(position + Vector3(0, 1.0, 0), clampf(delta * 5.0, 0.0, 1.0))
		rig.apply()


## Floor height for the knight standing at p, or NAN if any part of its
## footprint would leave the walkable cells or climb more than one step.
func _stand_height(p: Vector2) -> float:
	var h := grid.floor_at(p)
	if is_nan(h) or absf(h - floor_y) > Layout.MAX_STEP:
		return NAN
	for off in [Vector2(RADIUS, 0), Vector2(-RADIUS, 0), Vector2(0, RADIUS), Vector2(0, -RADIUS)]:
		var o := grid.floor_at(p + off)
		if is_nan(o) or absf(o - h) > Layout.MAX_STEP:
			return NAN
	return h


func _part(mesh: Mesh, mat: Material, pos: Vector3, size: Vector3, parent: Node3D = body) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.scale = size
	parent.add_child(m)
	return m


func _build_model() -> void:
	var block := Kit.bevel_box(0.09)
	var steel := ShaderMaterial.new()
	steel.shader = load("res://shaders/metal.gdshader")
	steel.set_shader_parameter("base_color", Color(0.55, 0.53, 0.5))
	steel.set_shader_parameter("roughness_v", 0.35)
	var brass := ShaderMaterial.new()
	brass.shader = load("res://shaders/metal.gdshader")
	var cloth := ShaderMaterial.new()
	cloth.shader = load("res://shaders/cloth.gdshader")
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 1.0
	_part(cyl, brass, Vector3(0, 0.03, 0), Vector3(0.8, 0.06, 0.8))
	for s in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(s * 0.12, 0.9, 0)
		body.add_child(hip)
		_part(block, steel, Vector3(0, -0.42, 0), Vector3(0.17, 0.82, 0.2), hip)
		_part(block, steel, Vector3(0, -0.8, 0.05), Vector3(0.19, 0.1, 0.3), hip)
		legs.append(hip)
	_part(block, steel, Vector3(0, 0.98, 0), Vector3(0.44, 0.22, 0.28))
	_part(block, steel, Vector3(0, 1.3, 0), Vector3(0.46, 0.46, 0.3))
	_part(block, brass, Vector3(0, 1.31, 0.16), Vector3(0.12, 0.3, 0.02))
	for s in [-1.0, 1.0]:
		_part(sphere, steel, Vector3(s * 0.29, 1.48, 0), Vector3(0.24, 0.2, 0.26))
		_part(block, steel, Vector3(s * 0.32, 1.18, 0.04), Vector3(0.13, 0.5, 0.14))
	_part(cyl, steel, Vector3(0, 1.76, 0), Vector3(0.24, 0.26, 0.25))
	_part(sphere, steel, Vector3(0, 1.9, 0), Vector3(0.24, 0.14, 0.25))
	_part(block, cloth, Vector3(0, 1.05, -0.2), Vector3(0.5, 0.95, 0.04))
	_part(block, steel, Vector3(0.3, 0.75, 0.25), Vector3(0.06, 0.95, 0.02))
	_part(cyl, brass, Vector3(-0.34, 1.15, 0.18), Vector3(0.6, 0.05, 0.6)).rotation = Vector3(PI * 0.5, 0, 0.2)
