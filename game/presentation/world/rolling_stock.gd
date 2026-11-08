class_name RollingStock
extends RefCounted
## Procedural railway vehicles with realistic proportions: a ribbed freight boxcar with
## sliding doors, ladders, couplers and two bogies, and a diesel hood locomotive with cab,
## nose, roof fans and headlights.
##
## Each model is one ArrayMesh whose surfaces are named by material role ("paint",
## "roof", "frame", ...). ModelLibrary assigns materials by role, so one boxcar mesh is
## shared by all five colours. Meshes are generated once per run and cached.
##
## Axes: length along Z with the front at -Z (Godot's forward), Y up, ground at y = 0.

const LENGTH := 1.62
const WIDTH := 0.74
const BODY_BOTTOM := 0.34
const BODY_HEIGHT := 0.66
const ROOF_HEIGHT := 0.07

static var _cache := {}


static func boxcar() -> ArrayMesh:
	if not _cache.has("boxcar"):
		_cache["boxcar"] = _build_boxcar()
	return _cache["boxcar"]


static func locomotive() -> ArrayMesh:
	if not _cache.has("locomotive"):
		_cache["locomotive"] = _build_locomotive()
	return _cache["locomotive"]


## Height of the roof surface of a boxcar (decals such as arrows sit just above it).
static func roof_top() -> float:
	return BODY_BOTTOM + BODY_HEIGHT + ROOF_HEIGHT


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


# --- Shared running gear -------------------------------------------------------------

static func _bogie(tools: Dictionary, z: float, axles: int, wheel_radius: float, gauge: float) -> void:
	var spacing := wheel_radius * 2.5
	var length := spacing * (axles - 1) + wheel_radius * 2.2
	MeshKit.rounded_box(tools["frame"], Vector3(gauge + 0.12, 0.1, length), 0.03, _at(Vector3(0.0, wheel_radius + 0.03, z)))
	for a in axles:
		var az := z + (a - (axles - 1) * 0.5) * spacing
		for side in [-1.0, 1.0]:
			MeshKit.cylinder_x(tools["wheel"], wheel_radius, 0.06, _at(Vector3(side * gauge * 0.5, wheel_radius, az)))
			MeshKit.cylinder_x(tools["steel"], wheel_radius * 0.45, 0.07, _at(Vector3(side * (gauge * 0.5 + 0.01), wheel_radius, az)), 10)
		MeshKit.cylinder_x(tools["frame"], 0.025, gauge, _at(Vector3(0.0, wheel_radius, az)), 8)


static func _couplers(tools: Dictionary, half_length: float, height: float) -> void:
	for side in [-1.0, 1.0]:
		MeshKit.rounded_box(tools["frame"], Vector3(0.12, 0.08, 0.16), 0.02, _at(Vector3(0.0, height, side * (half_length + 0.06))))
		MeshKit.rounded_box(tools["steel"], Vector3(0.16, 0.06, 0.05), 0.015, _at(Vector3(0.0, height, side * (half_length + 0.15))))


# --- Boxcar --------------------------------------------------------------------------

static func _build_boxcar() -> ArrayMesh:
	var tools := _tools(["paint", "paint_shade", "roof", "frame", "steel", "wheel"])
	var half := LENGTH * 0.5
	var body_centre := BODY_BOTTOM + BODY_HEIGHT * 0.5
	# Underframe with side sills.
	MeshKit.rounded_box(tools["frame"], Vector3(WIDTH - 0.04, 0.08, LENGTH - 0.02), 0.025, _at(Vector3(0.0, BODY_BOTTOM - 0.04, 0.0)))
	for side in [-1.0, 1.0]:
		MeshKit.rounded_box(tools["frame"], Vector3(0.04, 0.06, LENGTH), 0.015, _at(Vector3(side * (WIDTH * 0.5 - 0.02), BODY_BOTTOM - 0.06, 0.0)))
	_bogie(tools, -half + 0.34, 2, 0.1, 0.5)
	_bogie(tools, half - 0.34, 2, 0.1, 0.5)
	_couplers(tools, half, BODY_BOTTOM - 0.05)
	# Body shell.
	MeshKit.rounded_box(tools["paint"], Vector3(WIDTH, BODY_HEIGHT, LENGTH), 0.035, _at(Vector3(0.0, body_centre, 0.0)), 3)
	# Vertical ribs along both sides, skipping the door opening.
	var rib_count := 11
	for i in rib_count:
		var z := lerpf(-half + 0.08, half - 0.08, float(i) / (rib_count - 1))
		if absf(z) < 0.3:
			continue
		for side in [-1.0, 1.0]:
			MeshKit.rounded_box(tools["paint_shade"], Vector3(0.025, BODY_HEIGHT - 0.06, 0.035), 0.01, _at(Vector3(side * (WIDTH * 0.5 + 0.008), body_centre, z)), 1)
	# End ribs.
	for side in [-1.0, 1.0]:
		for k in 3:
			MeshKit.rounded_box(tools["paint_shade"], Vector3(WIDTH - 0.1, 0.03, 0.025), 0.01, _at(Vector3(0.0, BODY_BOTTOM + 0.15 + k * 0.18, side * (half + 0.008))), 1)
	# Sliding doors with top rail and handles.
	for side in [-1.0, 1.0]:
		var x: float = side * (WIDTH * 0.5 + 0.012)
		MeshKit.rounded_box(tools["paint_shade"], Vector3(0.02, BODY_HEIGHT - 0.08, 0.52), 0.012, _at(Vector3(x, body_centre - 0.01, 0.0)), 1)
		MeshKit.rounded_box(tools["steel"], Vector3(0.025, 0.025, 0.7), 0.008, _at(Vector3(x + side * 0.01, BODY_BOTTOM + BODY_HEIGHT - 0.02, 0.0)), 1)
		MeshKit.rounded_box(tools["steel"], Vector3(0.02, 0.18, 0.025), 0.006, _at(Vector3(x + side * 0.015, body_centre, 0.2)), 1)
		# Corner ladders.
		for end in [-1.0, 1.0]:
			var lz: float = end * (half - 0.05)
			for rung in 4:
				MeshKit.rounded_box(tools["steel"], Vector3(0.018, 0.014, 0.1), 0.004, _at(Vector3(x + side * 0.02, BODY_BOTTOM + 0.12 + rung * 0.14, lz)), 1)
	# Roof: slightly wider overhang with seams across.
	MeshKit.rounded_box(tools["roof"], Vector3(WIDTH + 0.05, ROOF_HEIGHT, LENGTH + 0.04), 0.03, _at(Vector3(0.0, BODY_BOTTOM + BODY_HEIGHT + ROOF_HEIGHT * 0.5 - 0.01, 0.0)), 2)
	# Raised end caps only: a clean roof keeps the painted arrow the strongest shape
	# when seen from above.
	for side in [-1.0, 1.0]:
		MeshKit.rounded_box(tools["paint_shade"], Vector3(WIDTH + 0.05, 0.02, 0.05), 0.008, _at(Vector3(0.0, roof_top() - 0.002, side * (half - 0.02))), 1)
	return _commit(tools)


# --- Diesel locomotive ---------------------------------------------------------------

static func _build_locomotive() -> ArrayMesh:
	var tools := _tools(["paint", "stripe", "roof", "frame", "steel", "wheel", "glass", "lamp"])
	var length := 2.1
	var half := length * 0.5
	var deck := 0.36
	MeshKit.rounded_box(tools["frame"], Vector3(0.78, 0.1, length), 0.03, _at(Vector3(0.0, deck - 0.05, 0.0)))
	_bogie(tools, -half + 0.42, 3, 0.09, 0.5)
	_bogie(tools, half - 0.42, 3, 0.09, 0.5)
	_couplers(tools, half, deck - 0.06)
	# Fuel tank between bogies.
	MeshKit.rounded_box(tools["frame"], Vector3(0.56, 0.16, 0.6), 0.06, _at(Vector3(0.0, deck - 0.16, 0.05)))
	# Long hood behind the cab.
	var hood_start := -0.32
	var hood_length := half - 0.06 - hood_start
	MeshKit.rounded_box(tools["paint"], Vector3(0.6, 0.56, hood_length), 0.06, _at(Vector3(0.0, deck + 0.28, hood_start + hood_length * 0.5)), 3)
	MeshKit.rounded_box(tools["roof"], Vector3(0.56, 0.05, hood_length - 0.04), 0.02, _at(Vector3(0.0, deck + 0.575, hood_start + hood_length * 0.5)), 2)
	# Radiator fans on the hood roof.
	for k in 3:
		var fz := hood_start + 0.3 + k * 0.32
		MeshKit.cylinder_y(tools["frame"], 0.13, 0.13, 0.03, _at(Vector3(0.0, deck + 0.6, fz)), 16)
		MeshKit.cylinder_y(tools["steel"], 0.05, 0.05, 0.035, _at(Vector3(0.0, deck + 0.6, fz)), 10)
	MeshKit.cylinder_y(tools["frame"], 0.05, 0.045, 0.12, _at(Vector3(0.0, deck + 0.6, hood_start + 0.12)), 10)
	# Hood side louvres.
	for side in [-1.0, 1.0]:
		for k in 5:
			MeshKit.rounded_box(tools["frame"], Vector3(0.012, 0.22, 0.05), 0.006, _at(Vector3(side * 0.302, deck + 0.3, hood_start + 0.25 + k * 0.12)), 1)
	# Cab: taller box with wrap-around windows.
	var cab_z := -0.55
	MeshKit.rounded_box(tools["paint"], Vector3(0.74, 0.72, 0.46), 0.05, _at(Vector3(0.0, deck + 0.36, cab_z)), 3)
	MeshKit.rounded_box(tools["roof"], Vector3(0.78, 0.07, 0.52), 0.03, _at(Vector3(0.0, deck + 0.74, cab_z)), 2)
	MeshKit.rounded_box(tools["glass"], Vector3(0.6, 0.2, 0.02), 0.02, _at(Vector3(0.0, deck + 0.52, cab_z - 0.235)), 1)
	for side in [-1.0, 1.0]:
		MeshKit.rounded_box(tools["glass"], Vector3(0.02, 0.2, 0.3), 0.02, _at(Vector3(side * 0.375, deck + 0.52, cab_z)), 1)
	# Short nose with headlights.
	var nose_length := 0.28
	var nose_z := cab_z - 0.23 - nose_length * 0.5
	MeshKit.rounded_box(tools["paint"], Vector3(0.58, 0.4, nose_length), 0.07, _at(Vector3(0.0, deck + 0.2, nose_z)), 3)
	for side in [-1.0, 1.0]:
		MeshKit.cylinder_x(tools["lamp"], 0.04, 0.02, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(side * 0.16, deck + 0.3, nose_z - nose_length * 0.5 - 0.005)), 10)
	# Livery stripe and walkway handrails along the whole engine.
	for side in [-1.0, 1.0]:
		MeshKit.rounded_box(tools["stripe"], Vector3(0.012, 0.07, hood_length + 0.02), 0.01, _at(Vector3(side * 0.305, deck + 0.12, hood_start + hood_length * 0.5)), 1)
		MeshKit.rounded_box(tools["stripe"], Vector3(0.012, 0.07, 0.46), 0.01, _at(Vector3(side * 0.375, deck + 0.12, cab_z)), 1)
		MeshKit.rounded_box(tools["steel"], Vector3(0.015, 0.015, length - 0.2), 0.005, _at(Vector3(side * 0.37, deck + 0.3, 0.1)), 1)
		for k in 6:
			MeshKit.rounded_box(tools["steel"], Vector3(0.012, 0.3, 0.012), 0.004, _at(Vector3(side * 0.37, deck + 0.15, -0.2 + k * 0.24)), 1)
	return _commit(tools)
