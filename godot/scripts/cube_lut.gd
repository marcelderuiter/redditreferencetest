class_name CubeLut
extends RefCounted
## Loads a .cube 3D LUT (red fastest) into an ImageTexture3D.

var texture: ImageTexture3D
var size := 0


static func load_cube(path: String) -> CubeLut:
	var lut := CubeLut.new()
	if not FileAccess.file_exists(path):
		push_warning("no LUT at %s; grading disabled" % path)
		return lut
	var f := FileAccess.open(path, FileAccess.READ)
	var values := PackedFloat32Array()
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#") or line.begins_with("TITLE") or line.begins_with("DOMAIN"):
			continue
		if line.begins_with("LUT_3D_SIZE"):
			lut.size = int(line.split(" ", false)[1])
			continue
		var p := line.split(" ", false)
		if p.size() == 3:
			values.append(float(p[0]))
			values.append(float(p[1]))
			values.append(float(p[2]))
	var n := lut.size
	if n < 2 or values.size() != n * n * n * 3:
		push_error("bad LUT %s" % path)
		lut.size = 0
		return lut
	var slices: Array[Image] = []
	for b in n:
		var data := values.slice(b * n * n * 3, (b + 1) * n * n * 3).to_byte_array()
		slices.append(Image.create_from_data(n, n, false, Image.FORMAT_RGBF, data))
	lut.texture = ImageTexture3D.new()
	lut.texture.create(Image.FORMAT_RGBF, n, n, n, false, slices)
	return lut
