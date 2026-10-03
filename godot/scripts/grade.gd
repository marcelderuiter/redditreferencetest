class_name Grade
extends CanvasLayer
## Full-screen display pass: vignette plus the reference-match LUT
## (godot/luts/00_reference_match.cube, display sRGB in and out).

const LUT_PATH := "res://luts/00_reference_match.cube"

var rect := ColorRect.new()
var material := ShaderMaterial.new()
var has_lut := false


func _init(lut_mode: String, vignette: float) -> void:
	layer = 100
	material.shader = load("res://shaders/post.gdshader")
	material.set_shader_parameter("vignette", vignette)
	rect.material = material
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	if lut_mode != "off":
		has_lut = load_cube(LUT_PATH)
	set_lut_enabled(has_lut)


func set_lut_enabled(on: bool) -> void:
	material.set_shader_parameter("use_lut", on and has_lut)


func lut_enabled() -> bool:
	return material.get_shader_parameter("use_lut")


func load_cube(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_warning("no LUT at %s, grading disabled" % path)
		return false
	var text := FileAccess.get_file_as_string(path)
	var n := 0
	var values := PackedFloat32Array()
	for line in text.split("\n"):
		line = line.strip_edges()
		if line.is_empty() or line.begins_with("#") or line.begins_with("TITLE") or line.begins_with("DOMAIN"):
			continue
		if line.begins_with("LUT_3D_SIZE"):
			n = line.split(" ", false)[1].to_int()
			continue
		var parts := line.split(" ", false)
		if parts.size() == 3:
			values.append(parts[0].to_float())
			values.append(parts[1].to_float())
			values.append(parts[2].to_float())
	if n < 2 or values.size() != n * n * n * 3:
		push_warning("bad LUT %s" % path)
		return false
	# .cube order is red fastest, then green, then blue: slice = blue.
	var slices: Array[Image] = []
	for b in n:
		var bytes := PackedByteArray()
		bytes.resize(n * n * 16)
		for g in n:
			for r in n:
				var src := ((b * n + g) * n + r) * 3
				var dst := (g * n + r) * 16
				bytes.encode_float(dst, values[src])
				bytes.encode_float(dst + 4, values[src + 1])
				bytes.encode_float(dst + 8, values[src + 2])
				bytes.encode_float(dst + 12, 1.0)
		slices.append(Image.create_from_data(n, n, false, Image.FORMAT_RGBAF, bytes))
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGBAF, n, n, n, false, slices)
	material.set_shader_parameter("lut", tex)
	material.set_shader_parameter("lut_size", float(n))
	return true
