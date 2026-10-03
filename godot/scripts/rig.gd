class_name Rig
extends Camera3D
## Orbit camera around a focus point. The matched view is a shift-lens
## camera: the body only pitches down by pitch * (1 - keystone) and an
## off-centre frustum looks the rest of the way down, so vertical edges stay
## close to vertical as in the reference. scripts/viewmath.py mirrors this.

const DEFAULT_VIEW := {
	"yaw": 0.0, "pitch": 44.0, "dist": 110.0, "fov": 16.0,
	"focus": Vector3(0.0, 0.0, 0.0), "keystone": 0.45,
}

var yaw := 0.0
var pitch := 44.0
var dist := 110.0
var fov_deg := 16.0
var focus := Vector3.ZERO
var keystone := 0.45
var matched := {}
var interactive := true
var follow := false
var dragging := false
var panning := false


func _init() -> void:
	matched = DEFAULT_VIEW.duplicate()
	set_view(matched)


## --cam=yaw,pitch,dist,fov[,fx,fy,fz[,keystone]] overrides the matched view.
func override_from(values: PackedFloat64Array) -> void:
	if values.size() < 4:
		return
	var v := DEFAULT_VIEW.duplicate()
	v.yaw = values[0]
	v.pitch = values[1]
	v.dist = values[2]
	v.fov = values[3]
	if values.size() >= 7:
		v.focus = Vector3(values[4], values[5], values[6])
	if values.size() >= 8:
		v.keystone = values[7]
	matched = v
	set_view(v)


func set_view(v: Dictionary) -> void:
	yaw = v.yaw
	pitch = v.pitch
	dist = v.dist
	fov_deg = v.fov
	focus = v.focus
	keystone = v.keystone
	apply()


func reset() -> void:
	set_view(matched)


func apply() -> void:
	pitch = clampf(pitch, 5.0, 89.9)
	dist = clampf(dist, 3.0, 400.0)
	var y := deg_to_rad(yaw)
	var p := deg_to_rad(pitch)
	var tilt := p * (1.0 - keystone)
	var offset := Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p)) * dist
	var b := Basis(Vector3.UP, y) * Basis(Vector3.RIGHT, -tilt)
	transform = Transform3D(b, focus + offset)
	projection = Camera3D.PROJECTION_FRUSTUM
	near = clampf(dist * 0.02, 0.05, 2.0)
	far = dist + 400.0
	size = 2.0 * near * tan(deg_to_rad(fov_deg) * 0.5)
	frustum_offset = Vector2(0.0, -near * tan(p - tilt))


func _unhandled_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			panning = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist *= 0.9
			apply()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist *= 1.1
			apply()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if dragging:
			yaw -= mm.relative.x * 0.3
			pitch += mm.relative.y * 0.2
			apply()
		elif panning:
			var k := dist * 0.0015
			var y := deg_to_rad(yaw)
			focus += Vector3(cos(y), 0, -sin(y)) * -mm.relative.x * k + Vector3(sin(y), 0, cos(y)) * -mm.relative.y * k
			apply()


func _process(delta: float) -> void:
	if not interactive:
		return
	var changed := false
	if Input.is_action_pressed("orbit_left"):
		yaw -= 60.0 * delta
		changed = true
	if Input.is_action_pressed("orbit_right"):
		yaw += 60.0 * delta
		changed = true
	if Input.is_action_pressed("tilt_up"):
		pitch += 40.0 * delta
		changed = true
	if Input.is_action_pressed("tilt_down"):
		pitch -= 40.0 * delta
		changed = true
	if Input.is_action_just_pressed("reset_view"):
		follow = false
		reset()
	if Input.is_action_just_pressed("follow_toggle"):
		follow = not follow
		if follow:
			dist = minf(dist, 30.0)
	if changed:
		apply()
