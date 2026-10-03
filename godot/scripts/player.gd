class_name Player
extends Node3D
## A small armoured adventurer that walks the walk grid. WASD / arrows move
## relative to the camera; Shift runs. Height follows the grid (stairs, ramps).

var grid: WalkGrid
var camera: OrbitCamera
var speed := 3.2
var _y_vel := 0.0


func _ready() -> void:
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.25
	cap.height = 1.3
	body.mesh = cap
	body.position = Vector3(0, 0.65, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.25, 0.32, 0.55)
	m.metallic = 0.6
	m.roughness = 0.4
	body.material_override = m
	add_child(body)
	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.17
	sph.height = 0.34
	head.mesh = sph
	head.position = Vector3(0, 1.45, 0)
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.75, 0.6, 0.35)
	hm.metallic = 0.8
	hm.roughness = 0.3
	head.material_override = hm
	add_child(head)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 1.8, 0)
	lamp.light_color = Color(1.0, 0.7, 0.4)
	lamp.light_energy = 0.8
	lamp.omni_range = 4.0
	add_child(lamp)


func _physics_process(delta: float) -> void:
	if grid == null:
		return
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): input.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): input.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): input.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): input.x += 1
	if input != Vector2.ZERO:
		var yaw := deg_to_rad(camera.yaw if camera else 0.0)
		var move := input.normalized().rotated(yaw) * speed * delta
		if Input.is_key_pressed(KEY_SHIFT):
			move *= 1.8
		var p := Vector2(position.x, position.z)
		# Try the full move, then each axis, so walls slide instead of stick.
		for cand in [p + move, p + Vector2(move.x, 0), p + Vector2(0, move.y)]:
			if grid.can_step(p, cand):
				position.x = cand.x
				position.z = cand.y
				rotation.y = atan2(-move.x, -move.y)
				break
	var h := grid.height_at(Vector2(position.x, position.z))
	if h > -999.0:
		position.y = lerpf(position.y, h, minf(1.0, delta * 14.0))
