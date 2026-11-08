class_name WagonModels
extends RefCounted
## Chunky, tactile rolling stock in the style of premium casual puzzlers: a rounded
## wagon body with a lighter roof cap, plank texture, dark chassis and four wheels that
## peek out at the sides (so a wagon still reads as a wagon from straight above), and a
## round-boilered locomotive with cab, chimney and brass bands.
##
## Each model is one ArrayMesh whose surfaces are named by material role; ModelLibrary
## assigns materials by role, so one wagon mesh serves every colour. Built once, cached.
## Axes: length along Z, front at -Z, Y up, wheels touching y = 0.

const LENGTH := 2.0
const WIDTH := 1.12
const BODY_BOTTOM := 0.3
const BODY_HEIGHT := 0.6
const ROOF_HEIGHT := 0.14
const WHEEL_RADIUS := 0.21

static var _cache := {}


static func wagon() -> ArrayMesh:
	if not _cache.has("wagon"):
		_cache["wagon"] = _build_wagon()
	return _cache["wagon"]


static func locomotive() -> ArrayMesh:
	if not _cache.has("locomotive"):
		_cache["locomotive"] = _build_locomotive()
	return _cache["locomotive"]


## Height of the top of the roof (arrow and capacity decals sit just above it).
static func roof_top() -> float:
	return BODY_BOTTOM + BODY_HEIGHT + ROOF_HEIGHT - 0.02


static func _tools(roles: Array) -> Dictionary:
	var tools := {}
	for role: String in roles:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[role] = tool
	return tools


static func _commit(tools: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for role: String in tools:
		var tool: SurfaceTool = tools[role]
		tool.index()
		mesh = tool.commit(mesh)
		mesh.surface_set_name(mesh.get_surface_count() - 1, role)
	return mesh


static func _at(position: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, position)


static func _wheels(tools: Dictionary, z_positions: Array, radius: float, half_track: float) -> void:
	for z: float in z_positions:
		for side in [-1.0, 1.0]:
			var x: float = side * half_track
			MeshKit.cylinder_x(tools["wheel"], radius, 0.16, _at(Vector3(x, radius, z)), 18)
			MeshKit.cylinder_x(tools["hub"], radius * 0.42, 0.18, _at(Vector3(x, radius, z)), 12)


static func _build_wagon() -> ArrayMesh:
	var tools := _tools(["paint", "roof", "chassis", "wheel", "hub", "trim"])
	var half := LENGTH * 0.5
	# Chassis: a dark tray under the body, slightly inset.
	MeshKit.rounded_box(tools["chassis"], Vector3(WIDTH - 0.16, 0.16, LENGTH - 0.1), 0.06, _at(Vector3(0.0, BODY_BOTTOM - 0.02, 0.0)), 2)
	_wheels(tools, [-half + 0.45, half - 0.45], WHEEL_RADIUS, WIDTH * 0.5 - 0.06)
	# Body: soft rounded block.
	MeshKit.rounded_box(tools["paint"], Vector3(WIDTH, BODY_HEIGHT, LENGTH), 0.12, _at(Vector3(0.0, BODY_BOTTOM + BODY_HEIGHT * 0.5, 0.0)), 3)
	# A trim band around the base of the body gives a finished, manufactured edge.
	MeshKit.rounded_box(tools["trim"], Vector3(WIDTH + 0.04, 0.08, LENGTH + 0.04), 0.04, _at(Vector3(0.0, BODY_BOTTOM + 0.05, 0.0)), 2)
	# Roof cap: lighter, slightly overhanging, very rounded: the face seen from above.
	MeshKit.rounded_box(tools["roof"], Vector3(WIDTH + 0.06, ROOF_HEIGHT, LENGTH + 0.06), 0.07, _at(Vector3(0.0, BODY_BOTTOM + BODY_HEIGHT + ROOF_HEIGHT * 0.5 - 0.04, 0.0)), 3)
	# Couplers.
	for side in [-1.0, 1.0]:
		MeshKit.rounded_box(tools["chassis"], Vector3(0.22, 0.12, 0.16), 0.04, _at(Vector3(0.0, BODY_BOTTOM - 0.02, side * (half + 0.06))), 1)
	return _commit(tools)


static func _build_locomotive() -> ArrayMesh:
	var tools := _tools(["engine", "cab", "chassis", "wheel", "hub", "brass", "lamp"])
	var length := 2.3
	var half := length * 0.5
	MeshKit.rounded_box(tools["chassis"], Vector3(1.02, 0.2, length), 0.07, _at(Vector3(0.0, 0.32, 0.0)), 2)
	_wheels(tools, [-0.62, -0.05, 0.52], 0.24, 0.47)
	# Boiler: a long rounded cylinder lying along Z (front part of the engine).
	var boiler_length := 1.35
	var boiler_z := -half + 0.12 + boiler_length * 0.5
	var boiler := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.0, 0.78, boiler_z))
	MeshKit.cylinder_x(tools["engine"], 0.38, boiler_length, boiler, 22)
	for k in 3:
		var band := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.0, 0.78, boiler_z - boiler_length * 0.5 + 0.2 + k * 0.45))
		MeshKit.cylinder_x(tools["brass"], 0.395, 0.06, band, 22)
	# Smokebox front and chimney.
	MeshKit.cylinder_x(tools["chassis"], 0.33, 0.08, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.0, 0.78, -half + 0.08)), 20)
	MeshKit.cylinder_y(tools["chassis"], 0.12, 0.16, 0.42, _at(Vector3(0.0, 1.08, -half + 0.36)), 14)
	MeshKit.cylinder_y(tools["brass"], 0.17, 0.17, 0.06, _at(Vector3(0.0, 1.48, -half + 0.36)), 14)
	MeshKit.cylinder_y(tools["brass"], 0.1, 0.06, 0.16, _at(Vector3(0.0, 1.12, boiler_z + 0.25)), 12)
	# Headlamp and red buffer beam.
	MeshKit.cylinder_x(tools["lamp"], 0.1, 0.05, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.0, 1.0, -half + 0.03)), 14)
	MeshKit.rounded_box(tools["cab"], Vector3(1.08, 0.18, 0.12), 0.05, _at(Vector3(0.0, 0.34, -half - 0.02)), 1)
	# Cab at the back with a darker overhanging roof.
	MeshKit.rounded_box(tools["cab"], Vector3(1.0, 0.78, 0.78), 0.1, _at(Vector3(0.0, 0.82, half - 0.42)), 3)
	MeshKit.rounded_box(tools["engine"], Vector3(1.12, 0.14, 0.92), 0.06, _at(Vector3(0.0, 1.26, half - 0.42)), 2)
	for side in [-1.0, 1.0]:
		MeshKit.rounded_box(tools["lamp"], Vector3(0.03, 0.26, 0.36), 0.04, _at(Vector3(side * 0.505, 0.98, half - 0.44)), 1)
	return _commit(tools)
