extends RefCounted

# Presentation-only colour lookup tables for the final grade. Profiles are
# Adobe/Resolve .cube 3D LUTs mapping display sRGB to display sRGB: the shipped
# examples in res://luts (tools/make_luts.py) and any the player drops into
# user://luts. A table becomes an N*N x N strip texture (blue slices side by
# side, red across each slice, green down) that shaders/finish.gdshader samples
# with two filtered taps. Nothing here reads or writes simulation state.
const BUILT_IN_DIR := "res://luts"
const USER_DIR := "user://luts"
const MIN_SIZE := 2
const MAX_SIZE := 65


# Sorted built-ins first, then user files. Titles are read on load; the list
# shows file names so scanning stays cheap.
static func profiles() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for directory in [BUILT_IN_DIR, USER_DIR]:
		if not DirAccess.dir_exists_absolute(directory):
			continue
		var files := Array(DirAccess.get_files_at(directory))
		files.sort()
		for file: String in files:
			if file.get_extension().to_lower() == "cube":
				found.append({"name": _display_name(file), "path": directory.path_join(file),
					"user": directory == USER_DIR})
	return found


# Returns {"texture", "size", "title"} or {"error"}. Rejects the whole file on
# any malformed entry rather than grading with a partial table.
static func load_cube(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {"error": "Could not read %s (%s)." % [path.get_file(), error_string(FileAccess.get_open_error())]}
	var size := 0
	var title := ""
	var values := PackedFloat32Array()
	var line_number := 0
	for raw: String in text.split("\n"):
		line_number += 1
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var fields := line.replace("\t", " ").split(" ", false)
		var keyword := fields[0].to_upper()
		if keyword == "TITLE":
			title = line.substr(5).strip_edges().trim_prefix("\"").trim_suffix("\"")
		elif keyword == "LUT_3D_SIZE":
			if size != 0 or fields.size() != 2 or not fields[1].is_valid_int():
				return {"error": "Line %d: invalid LUT_3D_SIZE." % line_number}
			size = fields[1].to_int()
			if size < MIN_SIZE or size > MAX_SIZE:
				return {"error": "LUT size %d is outside %d-%d." % [size, MIN_SIZE, MAX_SIZE]}
		elif keyword == "LUT_1D_SIZE":
			return {"error": "1D LUTs are not supported; export a 3D .cube."}
		elif keyword in ["DOMAIN_MIN", "DOMAIN_MAX", "LUT_3D_INPUT_RANGE"]:
			var expected: Array = [0.0, 0.0, 0.0] if keyword == "DOMAIN_MIN" else [1.0, 1.0, 1.0]
			if keyword == "LUT_3D_INPUT_RANGE":
				expected = [0.0, 1.0]
			if fields.size() != expected.size() + 1:
				return {"error": "Line %d: invalid %s." % [line_number, keyword]}
			for index in expected.size():
				if not fields[index + 1].is_valid_float() or absf(fields[index + 1].to_float() - expected[index]) > 0.0001:
					return {"error": "Only the 0-1 input domain is supported."}
		elif fields[0].is_valid_float():
			if size == 0:
				return {"error": "Line %d: table data before LUT_3D_SIZE." % line_number}
			if fields.size() != 3:
				return {"error": "Line %d: expected three values." % line_number}
			for field: String in fields:
				if not field.is_valid_float():
					return {"error": "Line %d: invalid number." % line_number}
				var value: float = field.to_float()
				if is_nan(value) or is_inf(value):
					return {"error": "Line %d: non-finite value." % line_number}
				values.append(clampf(value, 0.0, 1.0))
		# Other keywords (e.g. from grading tools) carry no table meaning here.
	if size == 0:
		return {"error": "Missing LUT_3D_SIZE."}
	var count := size * size * size
	if values.size() != count * 3:
		return {"error": "Expected %d entries, found %d." % [count, values.size() / 3]}
	# .cube order is red fastest, then green, then blue; the strip puts blue
	# slices along x and green down y.
	var strip := PackedFloat32Array()
	strip.resize(count * 3)
	for b in size:
		for g in size:
			for r in size:
				var source := (r + g * size + b * size * size) * 3
				var target := (r + b * size + g * size * size) * 3
				strip[target] = values[source]
				strip[target + 1] = values[source + 1]
				strip[target + 2] = values[source + 2]
	var image := Image.create_from_data(size * size, size, false, Image.FORMAT_RGBF, strip.to_byte_array())
	# Half floats keep LUT precision and stay filterable on Compatibility GPUs.
	image.convert(Image.FORMAT_RGBH)
	return {"texture": ImageTexture.create_from_image(image), "size": size,
		"title": title if not title.is_empty() else _display_name(path.get_file())}


static func _display_name(file: String) -> String:
	var stem := file.get_basename()
	# Drop an ordering prefix such as "01_".
	var parts := stem.split("_", false, 1)
	if parts.size() == 2 and parts[0].is_valid_int():
		stem = parts[1]
	return stem.replace("_", " ").to_upper()
