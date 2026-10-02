class_name Lut
extends RefCounted
## Loads a 3D .cube colour LUT (display sRGB in and out) into a Texture3D.

static func load_cube(path: String) -> ImageTexture3D:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("LUT not found: %s" % path)
		return null
	var n := 0
	var values := PackedFloat32Array()
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("LUT_3D_SIZE"):
			n = int(line.split(" ", false)[1])
			continue
		if not (line[0].is_valid_int() or line[0] == "." or line[0] == "-"):
			continue  # TITLE, DOMAIN_MIN/MAX
		var p := line.split(" ", false)
		values.append(float(p[0]))
		values.append(float(p[1]))
		values.append(float(p[2]))
	if n < 2 or values.size() != n * n * n * 3:
		push_warning("bad LUT: %s" % path)
		return null
	# .cube order: red varies fastest, then green, then blue -> x, y, slice.
	var slices: Array[Image] = []
	var stride := n * n * 3
	for b in n:
		var bytes := values.slice(b * stride, (b + 1) * stride).to_byte_array()
		slices.append(Image.create_from_data(n, n, false, Image.FORMAT_RGBF, bytes))
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGBF, n, n, n, false, slices)
	return tex
