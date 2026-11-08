class_name TrackBuilder
extends RefCounted
## Builds the rails of every lane: stone bed, sleepers (one MultiMesh per lane), two
## steel rails, a highlighted loading zone, a depot at the start and buffer stops at the
## final station. Returns the loading-zone nodes so the level can show them once a lane
## opens.

const BED_PROFILE := [Vector2(-0.92, -0.02), Vector2(-0.6, 0.13), Vector2(0.6, 0.13), Vector2(0.92, -0.02)]
const RAIL_HALF_GAP := 0.25
const RAIL_WIDTH := 0.06
const RAIL_HEIGHT := 0.08
const SLEEPER_SPACING := 0.34
const SLEEPER_SIZE := Vector3(0.95, 0.07, 0.15)
const ZONE_PROFILE := [Vector2(-0.8, 0.0), Vector2(0.8, 0.0)]

const DEPOT_WALL := Color("b5543d")
const DEPOT_ROOF := Color("3d4249")
const TUNNEL := Color("15181d")
const ZONE_COLOR := Color(1.0, 0.92, 0.45, 0.5)

var _models: ModelLibrary


func _init(models: ModelLibrary) -> void:
	_models = models


## Builds all lanes under `parent`. Returns one loading-zone MeshInstance3D per lane.
func build(parent: Node3D, routes: Array[RailRoute], engine: PuzzleEngine, gravel_color: Color) -> Array[MeshInstance3D]:
	var zones: Array[MeshInstance3D] = []
	for lane in routes.size():
		var route := routes[lane]
		var lane_root := Node3D.new()
		lane_root.name = "Lane %d" % lane
		parent.add_child(lane_root)
		var full := PathExtruder.sample(route, 0.0, route.length)
		_add_mesh(lane_root, "Bed", PathExtruder.extrude(full, PackedVector2Array(BED_PROFILE)), _models.gravel(gravel_color), false)
		_add_sleepers(lane_root, route)
		for side in [-1.0, 1.0]:
			var x: float = side * RAIL_HALF_GAP
			var profile := PackedVector2Array([
				Vector2(x - RAIL_WIDTH * 0.5, 0.0), Vector2(x - RAIL_WIDTH * 0.5, RAIL_HEIGHT),
				Vector2(x + RAIL_WIDTH * 0.5, RAIL_HEIGHT), Vector2(x + RAIL_WIDTH * 0.5, 0.0)])
			_add_mesh(lane_root, "Rail", PathExtruder.extrude(full, profile, 0.16), _models.material(Palette.RAIL, 0.25, 0.8), true)
		var zone_path := PathExtruder.sample(route, engine.loading_start, engine.loading_end)
		var zone := _add_mesh(lane_root, "Loading zone", PathExtruder.extrude(zone_path, PackedVector2Array(ZONE_PROFILE), 0.142), _models.flat_material(ZONE_COLOR, true), false)
		zone.visible = false
		zones.append(zone)
		_add_depot(lane_root, route)
		_add_buffer_stop(lane_root, route)
	return zones


func _add_mesh(parent: Node3D, label: String, mesh: ArrayMesh, mat: Material, shadows: bool) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _add_sleepers(parent: Node3D, route: RailRoute) -> void:
	var count := int(route.length / SLEEPER_SPACING)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _models.primitive("box")
	multimesh.instance_count = count
	for i in count:
		var distance := (i + 0.5) * SLEEPER_SPACING
		var forward := route.direction_at(distance)
		var basis := Basis.looking_at(forward, Vector3.UP).scaled(SLEEPER_SIZE)
		multimesh.set_instance_transform(i, Transform3D(basis, route.point_at(distance) + Vector3.UP * 0.155))
	var instance := MultiMeshInstance3D.new()
	instance.name = "Sleepers"
	instance.multimesh = multimesh
	instance.material_override = _models.wood()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


## A small engine shed with a dark mouth where the train emerges.
func _add_depot(parent: Node3D, route: RailRoute) -> void:
	var depot := Node3D.new()
	depot.name = "Depot"
	parent.add_child(depot)
	var facing := route.direction_at(0.3)
	depot.transform = Transform3D(Basis.looking_at(facing, Vector3.UP), route.point_at(0.0))
	_models.shape(depot, "rounded_box", Vector3(-0.85, 0.8, 0.9), Vector3(0.4, 1.6, 2.6), DEPOT_WALL)
	_models.shape(depot, "rounded_box", Vector3(0.85, 0.8, 0.9), Vector3(0.4, 1.6, 2.6), DEPOT_WALL)
	_models.shape(depot, "box", Vector3(0.0, 0.8, 2.1), Vector3(1.4, 1.6, 0.3), TUNNEL, false)
	_models.shape(depot, "rounded_box", Vector3(0.0, 1.45, -0.38), Vector3(2.1, 0.3, 0.12), DEPOT_WALL)
	_models.shape(depot, "prism", Vector3(0.0, 2.0, 0.9), Vector3(2.4, 0.8, 2.8), DEPOT_ROOF)


## Red-and-white buffer stop marking the final stop (reaching it loses the level).
func _add_buffer_stop(parent: Node3D, route: RailRoute) -> void:
	var stop := Node3D.new()
	stop.name = "Final stop"
	parent.add_child(stop)
	var facing := route.direction_at(route.length - 0.3)
	stop.transform = Transform3D(Basis.looking_at(facing, Vector3.UP), route.point_at(route.length))
	# The train arrives from +Z (behind), so the beam and buffers face that way.
	_models.shape(stop, "rounded_box", Vector3(0.0, 0.42, -0.05), Vector3(0.9, 0.22, 0.2), Color("c62f2f"))
	for side in [-0.3, 0.3]:
		_models.shape(stop, "rounded_box", Vector3(side, 0.25, -0.3), Vector3(0.1, 0.3, 0.5), Palette.CHASSIS)
		var buffer := _models.shape(stop, "cylinder", Vector3(side, 0.42, 0.12), Vector3(0.12, 0.16, 0.12), Palette.STEEL)
		buffer.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	_models.shape(stop, "box", Vector3(0.0, 0.42, 0.06), Vector3(0.5, 0.1, 0.02), Palette.WHITE, false)


## A short straight piece of track (sleepers and two rails) centred at `centre`, running
## along `facing`. Used for yard tracks under parked wagons and for station sidings.
func build_stub(parent: Node3D, centre: Vector3, facing: Vector3, length: float, with_buffer: bool = false) -> Node3D:
	var stub := Node3D.new()
	stub.name = "Track stub"
	stub.transform = Transform3D(Basis.looking_at(facing, Vector3.UP), centre)
	parent.add_child(stub)
	var sleepers := int(length / SLEEPER_SPACING)
	for i in sleepers:
		var z := -length * 0.5 + (i + 0.5) * length / sleepers
		_models.shape_with(stub, "box", Vector3(0.0, 0.035, z), SLEEPER_SIZE, _models.wood(), false)
	for side in [-1.0, 1.0]:
		_models.shape_with(stub, "box", Vector3(side * RAIL_HALF_GAP, 0.1, 0.0), Vector3(RAIL_WIDTH, RAIL_HEIGHT, length), _models.material(Palette.RAIL, 0.25, 0.8), false)
	if with_buffer:
		var stop := Node3D.new()
		stop.position = Vector3(0.0, 0.0, -length * 0.5)
		stub.add_child(stop)
		_models.shape(stop, "rounded_box", Vector3(0.0, 0.32, 0.0), Vector3(0.7, 0.16, 0.14), Color("c62f2f"))
		for side in [-0.24, 0.24]:
			_models.shape(stop, "rounded_box", Vector3(side, 0.18, -0.15), Vector3(0.08, 0.24, 0.36), Palette.CHASSIS)
	return stub
