extends Node
## Entry point. User args (after `--`):
##   --capture=PATH  render, save PNG, quit        --frames=N  frames before capture
##   --size=WxH      capture size                  --seed=N    detail seed
##   --lut=off|auto  apply luts/00_reference_match.cube
##   --vignette=F    vignette strength             --cam=yaw,pitch,dist,fov[,fx,fy,fz]
##   --check         headless: verify every walkable cell is reachable, then quit
##   --topdown=PATH  orthographic top-down capture (layout audit)

const LUT_PATH := "res://luts/00_reference_match.cube"

# Matched view of reference/reference.png.
const VIEW := {"yaw": 0.0, "pitch": 45.0, "dist": 56.0, "fov": 30.0, "focus": Vector3(0.0, 0.0, 0.0)}

var args := {}
var solved: Dictionary
var grid: WalkGrid
var viewport: SubViewport
var world: Node3D
var cam: OrbitCamera
var player: Player
var post: ColorRect


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	solved = Layout.solve()
	if solved.is_empty():
		push_error("layout failed to solve")
		get_tree().quit(1)
		return
	grid = WalkGrid.new(solved)
	var seed := int(args.get("seed", "7"))
	var builder := Builder.new(solved, grid, seed)
	_block_props()
	if args.has("check"):
		_check()
		return
	_setup_viewport()
	builder.build(world)
	_setup_environment()
	_setup_player_and_camera()
	_setup_post()
	if args.has("capture") or args.has("topdown"):
		_capture.call_deferred()


func _block_props() -> void:
	for c in Builder.plan_clutter(solved):
		grid.block(Vector2(c[1].x, c[1].z), c[2])
	for room_name in Layout.PROPS:
		var room: Dictionary = solved.rooms[room_name]
		for e in Layout.PROPS[room_name]:
			var r: float = Props.FOOTPRINT.get(e[0], 0.0)
			if r > 0.0:
				var p := Layout.prop_pos(room, e[1], e[2])
				grid.block(Vector2(p.x, p.z), r)


func _check() -> void:
	var r := grid.reachability()
	print("walk grid: %d cells, %d reachable from spawn in '%s'" % [r.total, r.reachable, Layout.SPAWN_ROOM])
	var names: Array = r.per.keys()
	names.sort()
	for o in names:
		print("  %-20s %5d / %5d" % [o, r.per[o][0], r.per[o][1]])
	# Every connection must have floor under both of its ends.
	var bad := []
	for link in solved.links:
		for end in [[link.w0, link.a], [link.w1, link.b]]:
			var k := WalkGrid.key(end[0])
			var room: Dictionary = solved.rooms[end[1]]
			if not Layout.inside(room, end[0]):
				bad.append("%s>%s ends outside %s" % [link.a, link.b, end[1]])
	if r.unreached.is_empty() and bad.is_empty():
		print("OK: every walkable area is reachable; every connection lands on a floor")
		get_tree().quit(0)
	else:
		for u in r.unreached + bad:
			print("FAIL: ", u)
		get_tree().quit(1)


func _setup_viewport() -> void:
	var container := SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)
	viewport = SubViewport.new()
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.positional_shadow_atlas_size = 2048
	if args.has("capture") or args.has("topdown"):
		var sz: PackedStringArray = args.get("size", "1080x810").split("x")
		viewport.size = Vector2i(int(sz[0]), int(sz[1]))
		container.stretch = false
		container.size = Vector2(viewport.size)
	else:
		container.stretch = true
	container.add_child(viewport)
	world = Node3D.new()
	world.name = "World"
	viewport.add_child(world)


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.03, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34, 0.42, 0.45)
	env.ambient_light_energy = 0.24
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.6
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.085, 0.1, 0.14)
	env.fog_density = 0.01
	env.fog_height = -8.0
	env.fog_height_density = 0.04
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_strength = 1.0
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 4.0
	env.ssao_power = 1.8
	env.ssao_detail = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.95, 0.85, 0.75)
	sun.light_energy = 0.5
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	world.add_child(sun)
	# Cool fill from the abyss side so shadowed faces keep some blue.
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.42, 0.58, 0.68)
	fill.light_energy = 0.4
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_specular = 0.0
	world.add_child(fill)


func _setup_player_and_camera() -> void:
	player = Player.new()
	player.grid = grid
	world.add_child(player)
	var sp := grid.spawn_point()
	player.position = Vector3(sp.x, grid.height_at(sp), sp.y)
	cam = OrbitCamera.new()
	cam.default_view = VIEW.duplicate()
	if args.has("cam"):
		var v: PackedStringArray = args.cam.split(",")
		cam.default_view.yaw = float(v[0])
		cam.default_view.pitch = float(v[1])
		cam.default_view.dist = float(v[2])
		cam.default_view.fov = float(v[3])
		if v.size() >= 7:
			cam.default_view.focus = Vector3(float(v[4]), float(v[5]), float(v[6]))
	cam.target = player
	world.add_child(cam)
	cam.reset_view()
	player.camera = cam
	if args.has("capture"):
		player.visible = false


func _setup_post() -> void:
	var layer := CanvasLayer.new()
	viewport.add_child(layer)
	post = ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/post.gdshader")
	m.set_shader_parameter("vignette", float(args.get("vignette", "0.25")))
	var lut_mode: String = args.get("lut", "auto")
	if lut_mode == "auto":
		var lut := CubeLut.load_cube(LUT_PATH)
		if lut.texture:
			m.set_shader_parameter("lut", lut.texture)
			m.set_shader_parameter("lut_size", float(lut.size))
			m.set_shader_parameter("use_lut", true)
	post.material = m
	layer.add_child(post)


func _capture() -> void:
	var frames := int(args.get("frames", "45"))
	if args.has("topdown"):
		cam.top_down(solved)
		post.visible = false
	for i in frames:
		await RenderingServer.frame_post_draw
	var img := viewport.get_texture().get_image()
	print("camera pos %s fov %.1f keep %d vp %s img %s" % [cam.global_position, cam.fov, cam.keep_aspect, viewport.size, img.get_size()])
	var path: String = args.get("capture", args.get("topdown", ""))
	img.save_png(path)
	print("captured ", path)
	get_tree().quit(0)
