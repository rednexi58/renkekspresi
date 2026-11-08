extends SceneTree
## Offline asset tool: converts the original train geometry (tools/source_models/*.json,
## exported from the earlier version in Unity's left-handed axes) into Godot ArrayMesh
## resources in assets/models/.
##
## Parts are merged into one surface per material ROLE (paint, chassis, steel, brass,
## glass, lamp, cream, accent) and each surface is named after its role. At runtime
## ModelLibrary assigns materials by surface name, so one wagon mesh serves every colour
## and restyling the palette never requires re-exporting geometry.
##
## Run:  godot --headless --path game --script res://tools/build_train_meshes.gd

const SOURCES := {
	"res://tools/source_models/Wagon0.json": "res://assets/models/wagon.res",
	"res://tools/source_models/Locomotive.json": "res://assets/models/locomotive.res",
}

## Source RGB (2 decimals) -> role. The wagon body colour of Wagon0 is the paint role.
const ROLES := {
	"0.90,0.36,0.32": "paint",
	"0.90,0.37,0.32": "paint",
	"0.13,0.22,0.27": "chassis",
	"0.51,0.60,0.62": "steel",
	"0.86,0.71,0.42": "brass",
	"0.66,0.89,0.91": "glass",
	"1.00,0.95,0.70": "lamp",
	"0.92,0.91,0.85": "cream",
	"0.84,0.34,0.29": "accent",
}


func _initialize() -> void:
	var failed := false
	for source: String in SOURCES:
		var mesh := _convert(source)
		if mesh == null:
			failed = true
			continue
		var error := ResourceSaver.save(mesh, SOURCES[source], ResourceSaver.FLAG_COMPRESS)
		if error != OK:
			printerr("Could not save %s (%d)" % [SOURCES[source], error])
			failed = true
		else:
			print("Saved %s: %d surfaces, AABB %s" % [SOURCES[source], mesh.get_surface_count(), mesh.get_aabb()])
	quit(1 if failed else 0)


func _convert(path: String) -> ArrayMesh:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		printerr("Invalid model file: " + path)
		return null
	var tools := {}
	for part: Dictionary in parsed["parts"]:
		var role := _role_of(part)
		if role.is_empty():
			printerr("%s: unmapped part colour %s" % [path, _key(part)])
			return null
		if not tools.has(role):
			var created := SurfaceTool.new()
			created.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[role] = {"tool": created, "count": 0}
		_append_part(tools[role], part)
	var mesh := ArrayMesh.new()
	var roles: Array = tools.keys()
	roles.sort()
	for role: String in roles:
		var tool: SurfaceTool = tools[role]["tool"]
		tool.index()
		mesh = tool.commit(mesh)
		mesh.surface_set_name(mesh.get_surface_count() - 1, role)
	return mesh


func _append_part(entry: Dictionary, part: Dictionary) -> void:
	var tool: SurfaceTool = entry["tool"]
	var vertices: Array = part["vertices"]
	var normals: Array = part["normals"]
	var triangles: Array = part["triangles"]
	# Unity is left-handed (+Z forward); Godot is right-handed (-Z forward). Mirroring Z
	# keeps the model's front facing travel direction. The mirror also flips each
	# triangle's handedness, which turns the source's counter-clockwise faces into the
	# clockwise front faces Godot expects, so the index order is kept as is.
	var i := 0
	while i < triangles.size():
		for corner in [0, 1, 2]:
			var index := int(triangles[i + corner])
			var n: Dictionary = normals[index]
			var v: Dictionary = vertices[index]
			tool.set_normal(Vector3(n["x"], n["y"], -float(n["z"])))
			tool.add_vertex(Vector3(v["x"], v["y"], -float(v["z"])))
		i += 3
	entry["count"] += vertices.size()


static func _key(part: Dictionary) -> String:
	return "%.2f,%.2f,%.2f" % [part["r"], part["g"], part["b"]]


func _role_of(part: Dictionary) -> String:
	return ROLES.get(_key(part), "")
