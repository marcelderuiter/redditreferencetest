extends Node3D
## Entry point. Builds the level from Plan, presents it, and either runs the
## game or (with --capture) renders the matched view to a PNG and quits.

var args: Args
var layout: Layout
var grid: Layout.Grid
var rig: Rig
var grade: Grade
var player: Player
var lights: Array[OmniLight3D] = []
var help: Label
var t := 0.0


func _ready() -> void:
	args = Args.parse()
	layout = Plan.build()
	layout.resolve()
	grid = layout.build_grid()
	if args.check:
		var report := layout.check(grid)
		print(report.text)
		get_tree().quit(0 if report.ok else 1)
		return
	for e in layout.errors:
		push_error("layout: " + e)
	if args.size != Vector2i.ZERO:
		get_window().size = args.size
	var t0 := Time.get_ticks_msec()
	var kit := Kit.new(args.seed)
	Build.new(kit, layout).all()
	Props.build_all(kit, layout)
	World.backdrop(kit, layout)
	var geo := Node3D.new()
	geo.name = "Level"
	add_child(geo)
	var pieces := kit.flush(geo)
	lights = World.setup(self, kit.lights)
	print("built %d instanced pieces, %d lights in %d ms" % [pieces, lights.size(), Time.get_ticks_msec() - t0])
	rig = Rig.new()
	add_child(rig)
	rig.override_from(args.cam)
	rig.current = true
	player = Player.new(grid, layout.spawn_point(), rig)
	add_child(player)
	grade = Grade.new(args.lut, args.vignette)
	add_child(grade)
	if args.topdown:
		rig.matched = {"yaw": 0.0, "pitch": 89.9, "dist": 160.0, "fov": 20.0,
			"focus": Vector3(0.5, 0.0, -3.75), "keystone": 0.0}
		rig.reset()
	if not args.capture.is_empty():
		rig.interactive = false
		player.set_physics_process(false)
		_capture.call_deferred()
	else:
		_add_help()


func _capture() -> void:
	RenderingServer.global_shader_parameter_set("anim_time", 0.0)
	for i in args.frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := args.capture
	if not path.is_absolute_path():
		path = ProjectSettings.globalize_path("res://").path_join(path)
	img.save_png(path)
	print("captured %s (%dx%d)" % [path, img.get_width(), img.get_height()])
	get_tree().quit()


func _process(delta: float) -> void:
	if not args.capture.is_empty():
		return
	t += delta
	RenderingServer.global_shader_parameter_set("anim_time", t)
	for i in lights.size():
		var o := lights[i]
		var f := 0.88 + 0.08 * sin(t * 9.0 + i * 1.7) + 0.04 * sin(t * 23.0 + i * 0.3)
		o.light_energy = o.get_meta("base_energy") * f
	if Input.is_action_just_pressed("toggle_grade"):
		grade.set_lut_enabled(not grade.lut_enabled())
	if Input.is_action_just_pressed("toggle_help") and help:
		help.visible = not help.visible


func _add_help() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 110
	help = Label.new()
	help.text = "WASD / arrows: walk   Shift: run\nRight-drag or Q/E, Z/X: orbit   Wheel: zoom   Middle-drag: pan\nF: follow the knight   R: reset to the matched view   G: toggle grade   F1: hide help"
	help.position = Vector2(12, 10)
	help.add_theme_color_override("font_color", Color(1.0, 0.86, 0.6))
	help.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	help.add_theme_constant_override("shadow_offset_x", 1)
	help.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(help)
	add_child(layer)
