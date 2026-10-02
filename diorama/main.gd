extends Node3D
## Builds the diorama, the hero and the camera. User args (after `--`):
##   --seed=N  --capture=PATH  --frames=N  --size=WxH  --cam=yaw,pitch,dist,fov,tx,ty,tz  --nohud

const DEFAULT_CAM := [-1.0, -35.0, 69.0, 34.0, 28.0, -2.0, 21.5]

var args := {}
var materials := {}
var meshes := {}
var layout: Layout
var hero: Node3D
var hero_h := 0.3
var hero_yaw := 0.0
var walk_phase := 0.0
var camera: Camera3D
var cam := DEFAULT_CAM.duplicate()
var follow := false
var frames_left := -1
var hud: Label
var light_scale := 0.6

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("size"):
		var s: PackedStringArray = args["size"].split("x")
		get_window().size = Vector2i(int(s[0]), int(s[1]))
	if args.has("cam"):
		var c: PackedStringArray = args["cam"].split(",")
		for i in c.size():
			cam[i] = float(c[i])
	make_resources()
	make_environment()
	layout = Layout.new(int(args.get("seed", "7")))
	layout.generate()
	var world := Node3D.new()
	world.name = "World"
	add_child(world)
	layout.build_into(world, meshes, materials)
	for l in layout.lights:
		var o := OmniLight3D.new()
		o.position = l["pos"]
		o.light_color = l["color"]
		o.light_energy = l["energy"] * light_scale
		o.omni_range = l["range"]
		o.omni_attenuation = 1.4
		o.light_specular = 0.4
		world.add_child(o)
	make_hero()
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	update_camera(0.0)
	hud = Label.new()
	hud.position = Vector2(12, 8)
	hud.text = "WASD move  |  RMB orbit  MMB pan  wheel zoom  |  F follow  Home reset  F12 screenshot  F1 hide"
	hud.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	var canvas := CanvasLayer.new()
	add_child(canvas)
	canvas.add_child(hud)
	hud.visible = not (args.has("nohud") or args.has("capture"))
	if args.has("capture"):
		frames_left = int(args.get("frames", "12"))
	print("instances %d  batches %d  lights %d" % [count_instances(), layout.batches.size(), layout.lights.size()])

func count_instances() -> int:
	var n := 0
	for k in layout.batches:
		n += layout.batches[k]["xf"].size()
	return n

func make_resources() -> void:
	var b := BoxMesh.new()
	meshes["box"] = b
	var c := CylinderMesh.new()
	c.top_radius = 0.5
	c.bottom_radius = 0.5
	c.height = 1.0
	c.radial_segments = 10
	c.rings = 1
	meshes["cyl"] = c
	var c24 := c.duplicate()
	c24.radial_segments = 40
	meshes["cyl24"] = c24
	var bar := CylinderMesh.new()
	bar.top_radius = 0.42
	bar.bottom_radius = 0.42
	bar.height = 1.0
	bar.radial_segments = 12
	meshes["barrel"] = bar
	var cone := CylinderMesh.new()
	cone.top_radius = 0.25
	cone.bottom_radius = 0.5
	cone.height = 1.0
	cone.radial_segments = 10
	meshes["cone"] = cone
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 12
	s.rings = 6
	meshes["sphere"] = s
	var t := TorusMesh.new()
	t.inner_radius = 0.42
	t.outer_radius = 0.5
	t.rings = 32
	t.ring_segments = 6
	meshes["torus"] = t
	var kit_shader: Shader = load("res://shaders/kit.gdshader")
	var defs := {
		"stone": {"mode": 0, "rough": 0.9, "edge_light": 0.8, "edge_width": 0.06, "grit": 0.5},
		"brick": {"mode": 1, "rough": 0.92, "edge_light": 0.8, "grit": 0.4},
		"flag": {"mode": 0, "rough": 0.85, "edge_light": 1.1, "edge_width": 0.06, "grit": 0.45, "top_light": 0.1},
		"wood": {"mode": 2, "rough": 0.8, "edge_light": 0.35, "grit": 0.1, "edge_width": 0.03},
		"brass": {"mode": 3, "rough": 0.38, "metal": 0.85, "edge_light": 0.6, "grit": 0.25, "edge_width": 0.03},
		"iron": {"mode": 3, "rough": 0.55, "metal": 0.7, "edge_light": 0.6, "grit": 0.3, "edge_width": 0.03},
		"gold": {"mode": 3, "rough": 0.28, "metal": 1.0, "edge_light": 0.3, "grit": 0.05},
		"carpet": {"mode": 4, "rough": 1.0, "edge_light": 0.0, "grit": 0.1},
		"cloth": {"mode": 5, "rough": 1.0, "edge_light": 0.1, "grit": 0.15},
		"plain": {"mode": 5, "rough": 0.8, "edge_light": 0.2, "grit": 0.1},
		"paint": {"mode": 0, "rough": 0.5, "metal": 0.35, "edge_light": 0.9, "grit": 0.2, "edge_width": 0.02},
		"wax": {"mode": 5, "rough": 0.5, "edge_light": 0.0, "grit": 0.0, "bump": 0.0},
		"glow": {"mode": 6, "rough": 1.0, "edge_light": 0.0, "grit": 0.2, "glow": 3.0},
	}
	for k in defs:
		var m := ShaderMaterial.new()
		m.shader = kit_shader
		for p in defs[k]:
			m.set_shader_parameter(p, defs[k][p])
		materials[k] = m
	var f := ShaderMaterial.new()
	f.shader = load("res://shaders/flame.gdshader")
	f.set_shader_parameter("energy", 9.0)
	materials["flame"] = f

func make_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.175, 0.22)
	env.background_energy_multiplier = 1.6
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.36, 0.48)
	env.ambient_light_energy = 0.15
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 4.0
	env.ssao_power = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.15, 0.16, 0.21)
	env.fog_density = 0.0015
	env.fog_light_energy = 1.6
	env.fog_height = -6.0
	env.fog_height_density = 0.04
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.92
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-58.0), deg_to_rad(28.0), 0.0)
	sun.light_color = Color(1.0, 0.78, 0.55)
	sun.light_energy = 0.22
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	sun.shadow_blur = 1.5
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(-15.0), 0.0)
	fill.light_color = Color(1.0, 0.7, 0.5)
	fill.light_energy = 0.0
	fill.light_specular = 0.1
	add_child(fill)

func make_hero() -> void:
	hero = Node3D.new()
	hero.name = "Hero"
	add_child(hero)
	var k := Kit.new(1)
	k.figure(Vector3.ZERO, 0.0, 1.1, Color(0.62, 0.58, 0.52))
	k.cyl("brass", Vector3(0, 0.045, 0), 0.37, 0.05, Kit.BRASS)
	k.build_into(hero, meshes, materials)
	var lantern := OmniLight3D.new()
	lantern.position = Vector3(0.3, 1.1, 0.3)
	lantern.light_color = Color(1.0, 0.7, 0.4)
	lantern.light_energy = 1.2
	lantern.omni_range = 3.0
	hero.add_child(lantern)
	hero.position = Vector3(19.7, 0.3, 27.5)
	hero_h = 0.3

func _process(delta: float) -> void:
	move_hero(delta)
	update_camera(delta)
	if frames_left > 0:
		frames_left -= 1
		if frames_left == 0:
			capture(args["capture"])
			get_tree().quit()

func move_hero(delta: float) -> void:
	var input := Vector2(
		Input.get_axis("ui_left", "ui_right") + float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		Input.get_axis("ui_up", "ui_down") + float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	if input.length() < 0.1:
		walk_phase = 0.0
		hero.position.y = lerpf(hero.position.y, hero_h, minf(1.0, delta * 12.0))
		return
	input = input.limit_length(1.0)
	var yaw := deg_to_rad(float(cam[0]))
	var dir := Vector2(input.x * cos(yaw) + input.y * sin(yaw), -input.x * sin(yaw) + input.y * cos(yaw))
	var step := dir * 3.2 * delta
	var p := Vector2(hero.position.x, hero.position.z)
	# try full move, then each axis (slide along walls)
	for cand in [p + step, p + Vector2(step.x, 0), p + Vector2(0, step.y)]:
		var h := Walk.height_at(layout.walk, cand, hero_h)
		if not is_nan(h) and not blocked(cand):
			p = cand
			hero_h = h
			break
	hero_yaw = lerp_angle(hero_yaw, atan2(dir.x, dir.y), minf(1.0, delta * 10.0))
	walk_phase += delta * 11.0
	hero.position = Vector3(p.x, hero_h + absf(sin(walk_phase)) * 0.06, p.y)
	hero.rotation.y = hero_yaw

func blocked(p: Vector2) -> bool:
	for b in layout.blockers:
		if p.distance_to(Vector2(b.x, b.y)) < b.z + 0.25:
			return true
	return false

func update_camera(delta: float) -> void:
	var target := Vector3(cam[4], cam[5], cam[6])
	if follow:
		var want := hero.position
		cam[4] = lerpf(cam[4], want.x, minf(1.0, delta * 4.0))
		cam[5] = lerpf(cam[5], want.y, minf(1.0, delta * 4.0))
		cam[6] = lerpf(cam[6], want.z, minf(1.0, delta * 4.0))
		target = Vector3(cam[4], cam[5], cam[6])
	var b := Basis.from_euler(Vector3(deg_to_rad(cam[1]), deg_to_rad(cam[0]), 0.0))
	camera.transform = Transform3D(b, target + b.z * float(cam[2]))
	camera.fov = cam[3]
	camera.near = 0.5
	camera.far = 400.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			cam[0] -= event.relative.x * 0.3
			cam[1] = clampf(cam[1] - event.relative.y * 0.3, -88.0, -8.0)
		elif event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			var k: float = cam[2] * 0.0015
			var yaw := deg_to_rad(float(cam[0]))
			cam[4] -= (event.relative.x * cos(yaw) + event.relative.y * sin(yaw)) * k
			cam[6] -= (-event.relative.x * sin(yaw) + event.relative.y * cos(yaw)) * k
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam[2] = maxf(6.0, cam[2] * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam[2] = minf(160.0, cam[2] * 1.1)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F:
				follow = not follow
				if follow:
					cam[2] = minf(cam[2], 26.0)
			KEY_HOME:
				cam = DEFAULT_CAM.duplicate()
				follow = false
			KEY_F12:
				capture("user://screenshot_%d.png" % Time.get_unix_time_from_system())
			KEY_F1:
				hud.visible = not hud.visible
			KEY_F11:
				var w := get_window()
				w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN

func capture(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("captured ", path)
