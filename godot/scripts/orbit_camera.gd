class_name OrbitCamera
extends Camera3D
## Orbit camera around a focus point. Right-drag or Q/E/Z/X orbit, wheel or
## +/- zoom, F toggles following the player, R resets to the matched view.

var default_view := {}
var yaw := 0.0
var pitch := 52.0
var dist := 60.0
var focus := Vector3.ZERO
var follow := false
var target: Node3D
var _dragging := false


func reset_view() -> void:
	yaw = default_view.yaw
	pitch = default_view.pitch
	dist = default_view.dist
	fov = default_view.fov
	focus = default_view.focus
	follow = false
	projection = PROJECTION_PERSPECTIVE
	_apply()


func top_down(solved: Dictionary) -> void:
	var bounds := Rect2()
	var first := true
	for room in solved.rooms.values():
		bounds = room.rect if first else bounds.merge(room.rect)
		first = false
	projection = PROJECTION_ORTHOGONAL
	size = max(bounds.size.y, bounds.size.x * 0.75) + 4.0
	position = Vector3(bounds.get_center().x, 60.0, bounds.get_center().y)
	rotation = Vector3(-PI * 0.5, 0, 0)
	far = 200.0


func _apply() -> void:
	var f := focus
	if follow and target:
		f = target.global_position + Vector3(0, 1.0, 0)
	var rot := Basis(Vector3.UP, deg_to_rad(-yaw)) * Basis(Vector3.RIGHT, deg_to_rad(-pitch))
	position = f + rot * Vector3(0, 0, dist)
	look_at(f, Vector3.UP)
	near = 0.5
	far = 400.0


func _process(delta: float) -> void:
	if projection == PROJECTION_ORTHOGONAL:
		return
	var turn := 0.0
	if Input.is_key_pressed(KEY_Q): turn -= 1.0
	if Input.is_key_pressed(KEY_E): turn += 1.0
	yaw += turn * 70.0 * delta
	var tilt := 0.0
	if Input.is_key_pressed(KEY_Z): tilt -= 1.0
	if Input.is_key_pressed(KEY_X): tilt += 1.0
	pitch = clampf(pitch + tilt * 50.0 * delta, 10.0, 89.0)
	if Input.is_key_pressed(KEY_EQUAL): dist = maxf(dist - 30.0 * delta, 6.0)
	if Input.is_key_pressed(KEY_MINUS): dist = minf(dist + 30.0 * delta, 150.0)
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			dist = maxf(dist * 0.9, 6.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			dist = minf(dist * 1.1, 150.0)
	elif event is InputEventMouseMotion and _dragging:
		yaw += event.relative.x * 0.3
		pitch = clampf(pitch + event.relative.y * 0.3, 10.0, 89.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			reset_view()
		elif event.keycode == KEY_F:
			follow = not follow
			if follow:
				dist = minf(dist, 22.0)
