extends Node3D

# Presentation for the Rust-generated diorama. Rust owns generation and player
# movement; this script builds MultiMesh batches, lights, environment, camera
# and the final LUT/compare pass, and runs the capture mode used by tools/.
const ColorLut = preload("res://color_lut.gd")
const FINISH_SHADER = preload("res://shaders/finish.gdshader")
const SHADERS := {
	"stone": preload("res://shaders/stone.gdshader"),
	"wood": preload("res://shaders/wood.gdshader"),
	"metal": preload("res://shaders/metal.gdshader"),
	"gold": preload("res://shaders/gold.gdshader"),
	"cloth": preload("res://shaders/cloth.gdshader"),
	"paint": preload("res://shaders/paint.gdshader"),
	"wax": preload("res://shaders/wax.gdshader"),
	"flame": preload("res://shaders/flame.gdshader"),
	"glow": preload("res://shaders/glow.gdshader"),
	"backdrop": preload("res://shaders/backdrop.gdshader"),
}
const NO_SHADOW := ["flame"]
const REFERENCE_PATH := "../reference/reference.png"

var bridge: PlatformsBridge
var materials := {}
var meshes := {}
var lights: Array[Dictionary] = []
var camera: Camera3D
var env: Environment
var player: Node3D
var player_light: OmniLight3D
var finish: ShaderMaterial
var hud: Label
var noise_textures: Array[NoiseTexture2D] = []

# Camera orbit state (degrees / metres).
var focus := Vector3(31.0, -1.0, 19.5)
var yaw := 0.0
var pitch := 50.0
var distance := 96.0
var follow := false
var dragging := false
var panning := false

var lut_profiles: Array[Dictionary] = []
var lut_index := -1
var lut_strength := 1.0
var compare_mode := 0
var has_reference := false
var options := {}
var frame := 0
var clock := 0.0


func _ready() -> void:
	options = _parse_args()
	var size_text: String = options.get("size", "")
	if not size_text.is_empty():
		var parts := size_text.split("x")
		get_window().size = Vector2i(parts[0].to_int(), parts[1].to_int())
	bridge = PlatformsBridge.new()
	bridge.generate(int(options.get("seed", "7")))
	_make_noise()
	_make_materials()
	_make_meshes()
	_build_batches(self, bridge.batches(), true)
	_build_lights()
	_build_environment()
	_build_camera()
	_build_player()
	_build_finish()
	_build_hud()
	_apply_camera_option()
	_select_lut(options.get("lut", "auto"))


func _parse_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		var text: String = arg.trim_prefix("--")
		var eq := text.find("=")
		if eq < 0:
			out[text] = "1"
		else:
			out[text.substr(0, eq)] = text.substr(eq + 1)
	return out


func _make_noise() -> void:
	for spec in [[0.024, 4, 512, 11], [0.006, 3, 512, 29]]:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = spec[0]
		noise.fractal_octaves = spec[1]
		noise.seed = spec[3]
		var tex := NoiseTexture2D.new()
		tex.width = spec[2]
		tex.height = spec[2]
		tex.seamless = true
		tex.generate_mipmaps = true
		tex.noise = noise
		noise_textures.append(tex)


func _make_materials() -> void:
	for name in SHADERS:
		var m := ShaderMaterial.new()
		m.shader = SHADERS[name]
		m.set_shader_parameter("noise_fine", noise_textures[0])
		m.set_shader_parameter("noise_coarse", noise_textures[1])
		materials[name] = m


func _make_meshes() -> void:
	var source: Dictionary = bridge.meshes()
	for name in source:
		var d: Dictionary = source[name]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = d["positions"]
		arrays[Mesh.ARRAY_NORMAL] = d["normals"]
		arrays[Mesh.ARRAY_TEX_UV] = d["uvs"]
		arrays[Mesh.ARRAY_INDEX] = d["indices"]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		meshes[name] = mesh


func _build_batches(parent: Node3D, batches: Array, shadows: bool) -> void:
	for b: Dictionary in batches:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = meshes[b["mesh"]]
		mm.instance_count = b["count"]
		mm.buffer = b["buffer"]
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = materials[b["material"]]
		if not shadows or b["material"] in NO_SHADOW:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)


func _build_lights() -> void:
	for d: Dictionary in bridge.lights():
		var light := OmniLight3D.new()
		light.position = d["position"]
		light.light_color = d["color"]
		light.light_energy = d["energy"]
		light.omni_range = d["range"]
		light.omni_attenuation = 1.9
		light.light_specular = 0.6
		light.shadow_enabled = d["shadow"]
		light.shadow_bias = 0.05
		light.shadow_normal_bias = 1.5
		add_child(light)
		lights.append({"node": light, "energy": d["energy"], "flicker": d["flicker"], "phase": randf() * 100.0})
	# Cool moonlight from high behind-left gives form to the stone.
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-58.0, -35.0, 0.0)
	moon.light_color = Color(0.5, 0.65, 1.0)
	moon.light_energy = 0.16
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 220.0
	moon.shadow_blur = 1.5
	add_child(moon)


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.022, 0.034, 0.068)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.54, 0.46)
	env.ambient_light_energy = 0.2
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.35
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 0.9
	env.ssao_intensity = 3.0
	env.ssao_power = 1.6
	env.ssao_detail = 0.8
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for level in 7:
		env.set_glow_level(level, 1.0 if level in [1, 2, 3, 4] else 0.0)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.03, 0.046, 0.09)
	env.fog_light_energy = 1.0
	env.fog_density = 0.004
	env.fog_height = -3.0
	env.fog_height_density = 0.03
	env.fog_aerial_perspective = 0.0
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 30.0
	camera.near = 1.0
	camera.far = 600.0
	var attributes := CameraAttributesPractical.new()
	attributes.dof_blur_far_enabled = true
	attributes.dof_blur_far_distance = 125.0
	attributes.dof_blur_far_transition = 45.0
	attributes.dof_blur_amount = 0.09
	camera.attributes = attributes
	add_child(camera)
	camera.current = true
	_update_camera()


func _apply_camera_option() -> void:
	var text: String = options.get("cam", "")
	if text.is_empty():
		return
	var v := text.split(",")
	if v.size() >= 4:
		yaw = v[0].to_float()
		pitch = v[1].to_float()
		distance = v[2].to_float()
		camera.fov = v[3].to_float()
	if v.size() >= 7:
		focus = Vector3(v[4].to_float(), v[5].to_float(), v[6].to_float())
	_update_camera()


func _update_camera() -> void:
	var target := focus
	if follow and player:
		target = player.position + Vector3(0, 0.8, 0)
	var dir := Vector3(sin(deg_to_rad(yaw)) * cos(deg_to_rad(pitch)), sin(deg_to_rad(pitch)), cos(deg_to_rad(yaw)) * cos(deg_to_rad(pitch)))
	camera.position = target + dir * distance
	camera.look_at(target, Vector3.UP)
	if camera.attributes:
		var focal := distance
		camera.attributes.dof_blur_far_distance = focal + 22.0


func _build_player() -> void:
	player = Node3D.new()
	player.name = "Player"
	add_child(player)
	_build_batches(player, bridge.player_batches(), true)
	player_light = OmniLight3D.new()
	player_light.position = Vector3(0.0, 4.4, 1.2)
	player_light.light_color = Color(1.0, 0.62, 0.3)
	player_light.light_energy = 1.0
	player_light.omni_range = 5.0
	player_light.light_specular = 0.2
	player.add_child(player_light)
	var state: Dictionary = bridge.advance(0.0, Vector2.ZERO)
	player.position = state["position"]


func _build_finish() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	finish = ShaderMaterial.new()
	finish.shader = FINISH_SHADER
	finish.set_shader_parameter("vignette", float(options.get("vignette", "0.25")))
	var path := ProjectSettings.globalize_path("res://").path_join(REFERENCE_PATH).simplify_path()
	# The reference image is supplied locally (reference/README.md); without it
	# the compare view stays off.
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image:
			image.generate_mipmaps()
			finish.set_shader_parameter("reference", ImageTexture.create_from_image(image))
			has_reference = true
	compare_mode = int(options.get("compare", "0")) if has_reference else 0
	finish.set_shader_parameter("compare_mode", compare_mode)
	rect.material = finish
	layer.add_child(rect)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(12, 10)
	hud.add_theme_color_override("font_color", Color(0.95, 0.88, 0.7))
	hud.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hud.add_theme_constant_override("outline_size", 4)
	hud.visible = not options.has("capture") and not options.has("nohud")
	layer.add_child(hud)


# "auto" picks the fitted reference match when present; "off" disables.
func _select_lut(choice: String) -> void:
	lut_profiles = ColorLut.profiles()
	lut_strength = float(options.get("strength", "1.0"))
	lut_index = -1
	if choice == "off":
		_apply_lut()
		return
	for i in lut_profiles.size():
		var p: Dictionary = lut_profiles[i]
		if (choice == "auto" and p["path"].get_file().begins_with("00_")) or p["path"] == choice or p["name"].to_lower() == choice.to_lower() or p["path"].get_file() == choice:
			lut_index = i
	if lut_index < 0 and choice.ends_with(".cube"):
		lut_profiles.append({"name": choice.get_file(), "path": choice, "user": true})
		lut_index = lut_profiles.size() - 1
	_apply_lut()


func _apply_lut() -> void:
	if lut_index < 0 or lut_index >= lut_profiles.size():
		finish.set_shader_parameter("lut_size", 0)
		finish.set_shader_parameter("lut_strength", 0.0)
		return
	var loaded := ColorLut.load_cube(lut_profiles[lut_index]["path"])
	if loaded.has("error"):
		push_error(loaded["error"])
		lut_index = -1
		finish.set_shader_parameter("lut_size", 0)
		return
	finish.set_shader_parameter("lut", loaded["texture"])
	finish.set_shader_parameter("lut_size", loaded["size"])
	finish.set_shader_parameter("lut_strength", lut_strength)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			panning = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(distance * 0.92, 6.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(distance * 1.08, 240.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and compare_mode == 1:
			finish.set_shader_parameter("divider", mb.position.x / get_viewport().get_visible_rect().size.x)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if dragging:
			yaw -= mm.relative.x * 0.25
			pitch = clampf(pitch + mm.relative.y * 0.2, 10.0, 89.0)
		elif panning:
			var right := camera.global_transform.basis.x
			var fwd := Vector3(-sin(deg_to_rad(yaw)), 0, -cos(deg_to_rad(yaw)))
			focus += (-right * mm.relative.x + fwd * mm.relative.y) * distance * 0.0012
		elif compare_mode == 1 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			finish.set_shader_parameter("divider", mm.position.x / get_viewport().get_visible_rect().size.x)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_L:
				lut_index = (lut_index + 2) % (lut_profiles.size() + 1) - 1
				_apply_lut()
			KEY_BRACKETLEFT:
				lut_strength = clampf(lut_strength - 0.1, 0.0, 1.0)
				_apply_lut()
			KEY_BRACKETRIGHT:
				lut_strength = clampf(lut_strength + 0.1, 0.0, 1.0)
				_apply_lut()
			KEY_TAB:
				if has_reference:
					compare_mode = (compare_mode + 1) % 3
					finish.set_shader_parameter("compare_mode", compare_mode)
			KEY_F:
				follow = not follow
				if follow:
					distance = minf(distance, 30.0)
			KEY_HOME:
				focus = Vector3(31.0, -1.0, 19.5)
				yaw = 0.0
				pitch = 50.0
				distance = 96.0
				follow = false
			KEY_F1:
				hud.visible = not hud.visible
			KEY_F11:
				var w := get_window()
				w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
			KEY_F12:
				_save_screenshot("user://screenshot_%d.png" % Time.get_unix_time_from_system())
			KEY_ESCAPE:
				get_tree().quit()


func _process(delta: float) -> void:
	frame += 1
	clock += delta
	var input := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left") + float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up") + float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	input = input.limit_length(1.0).rotated(-deg_to_rad(yaw))
	var state: Dictionary = bridge.advance(delta, input)
	if state.has("position"):
		var bob := absf(sin(float(state["stride"]) * 3.4)) * 0.06
		player.position = state["position"] + Vector3(0, bob, 0)
		player.rotation.y = state["yaw"]
	for l in lights:
		if l["flicker"] > 0.0:
			var t: float = clock * 9.0 + l["phase"]
			var n := sin(t) * 0.5 + sin(t * 2.31 + 1.7) * 0.3 + sin(t * 5.13) * 0.2
			l["node"].light_energy = l["energy"] * (1.0 + l["flicker"] * n)
	_update_camera()
	if hud.visible:
		var lut_name: String = "OFF" if lut_index < 0 else lut_profiles[lut_index]["name"]
		hud.text = "FPS %d   LUT %s (%d%%)   compare %s\nWASD move · RMB orbit · MMB pan · wheel zoom · F follow · L LUT · [ ] strength · Tab compare · Home reset · F12 shot · F1 hide" % [
			Engine.get_frames_per_second(), lut_name, roundi(lut_strength * 100.0), ["off", "split", "reference"][compare_mode] if has_reference else "n/a (no reference)"]
	if options.has("capture"):
		_capture_step()


func _noise_ready() -> bool:
	for tex in noise_textures:
		if tex.get_image() == null:
			return false
	return true


var _capture_wait := 0


func _capture_step() -> void:
	if not _noise_ready():
		return
	_capture_wait += 1
	if _capture_wait == int(options.get("frames", "60")):
		print("fps %d (%.2f ms cpu process)" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
		await RenderingServer.frame_post_draw
		_save_screenshot(options["capture"])
		get_tree().quit()


func _save_screenshot(path: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var target := path if path.begins_with("user://") or path.begins_with("/") else ProjectSettings.globalize_path("res://").path_join(path).simplify_path()
	var err := image.save_png(target)
	print("saved %s (%s)" % [target, error_string(err)])
