class_name Batch
extends RefCounted
## Collects instances per (mesh, material) and emits one MultiMeshInstance3D each.

var _groups := {}   # key -> {mesh, material, xforms, colors, custom}
var _meshes := {}
var _materials := {}


func register_mesh(name: String, mesh: Mesh) -> void:
	_meshes[name] = mesh


func register_material(name: String, material: Material) -> void:
	_materials[name] = material


func add(mesh: String, material: String, xf: Transform3D, color := Color.WHITE, custom := Color(0, 0, 0, 0)) -> void:
	var k := mesh + "|" + material
	if not _groups.has(k):
		assert(_meshes.has(mesh), "unknown mesh " + mesh)
		assert(_materials.has(material), "unknown material " + material)
		_groups[k] = {"mesh": mesh, "material": material, "xforms": [], "colors": [], "custom": []}
	var g: Dictionary = _groups[k]
	g.xforms.append(xf)
	g.colors.append(color)
	g.custom.append(custom)


## Box helper: centre, size, optional basis rotation (yaw radians).
func box(mesh: String, material: String, centre: Vector3, size: Vector3, yaw := 0.0, color := Color.WHITE, custom := Color(0, 0, 0, 0)) -> void:
	var b := Basis(Vector3.UP, yaw) * Basis.from_scale(size)
	add(mesh, material, Transform3D(b, centre), color, custom)


func instance_count() -> int:
	var n := 0
	for g in _groups.values():
		n += g.xforms.size()
	return n


func emit(parent: Node3D, shadows := true) -> void:
	for g in _groups.values():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = _meshes[g.mesh]
		mm.instance_count = g.xforms.size()
		for i in g.xforms.size():
			mm.set_instance_transform(i, g.xforms[i])
			mm.set_instance_color(i, g.colors[i])
			mm.set_instance_custom_data(i, g.custom[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = _materials[g.material]
		mi.name = g.mesh + "_" + g.material
		if not shadows or g.material in ["flame", "glow", "carpet"]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
	_groups.clear()
