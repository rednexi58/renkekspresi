class_name TrackBuilder
extends RefCounted
## Builds the rails of every lane: stone bed, sleepers (one MultiMesh per lane), two
## steel rails, a highlighted loading zone, a depot at the start and buffer stops at the
## final station. Returns the loading-zone nodes so the level can show them once a lane
## opens.

const BED_PROFILE := [Vector2(-1.05, 0.0), Vector2(-0.82, 0.12), Vector2(0.82, 0.12), Vector2(1.05, 0.0)]
const RAIL_HALF_GAP := 0.42
const RAIL_WIDTH := 0.11
const RAIL_HEIGHT := 0.14
const SLEEPER_SPACING := 0.55
const SLEEPER_SIZE := Vector3(1.4, 0.1, 0.26)
const ZONE_PROFILE := [Vector2(-0.98, 0.0), Vector2(0.98, 0.0)]

const SLEEPER_COLOR := Color("9a6a46")
const DEPOT_WALL := Color("e8e1d4")
const DEPOT_ROOF := Color("3b4f7a")
const TUNNEL := Color("232a3d")
const ZONE_COLOR := Color(1.0, 1.0, 1.0, 0.55)

var _models: ModelLibrary


func _init(models: ModelLibrary) -> void:
	_models = models


## Builds all lanes under `parent`. Returns one loading-zone MeshInstance3D per lane.
func build(parent: Node3D, routes: Array[RailRoute], engine: PuzzleEngine, bed_color: Color) -> Array[MeshInstance3D]:
	var zones: Array[MeshInstance3D] = []
	for lane in routes.size():
		var route := routes[lane]
		var lane_root := Node3D.new()
		lane_root.name = "Lane %d" % lane
		parent.add_child(lane_root)
		var full := PathExtruder.sample(route, 0.0, route.length)
		_add_mesh(lane_root, "Bed", PathExtruder.extrude(full, PackedVector2Array(BED_PROFILE)), _models.material(bed_color, 0.9), false)
		_add_sleepers(lane_root, route)
		for side in [-1.0, 1.0]:
			var x: float = side * RAIL_HALF_GAP
			var profile := PackedVector2Array([
				Vector2(x - RAIL_WIDTH * 0.5, 0.0), Vector2(x - RAIL_WIDTH * 0.5, RAIL_HEIGHT),
				Vector2(x + RAIL_WIDTH * 0.5, RAIL_HEIGHT), Vector2(x + RAIL_WIDTH * 0.5, 0.0)])
			_add_mesh(lane_root, "Rail", PathExtruder.extrude(full, profile, 0.12), _models.material(Palette.STEEL, 0.3, 0.6), true)
		var zone_path := PathExtruder.sample(route, engine.loading_start, engine.loading_end)
		var zone := _add_mesh(lane_root, "Loading zone", PathExtruder.extrude(zone_path, PackedVector2Array(ZONE_PROFILE), 0.135), _models.flat_material(ZONE_COLOR, true), false)
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
		multimesh.set_instance_transform(i, Transform3D(basis, route.point_at(distance) + Vector3.UP * 0.15))
	var instance := MultiMeshInstance3D.new()
	instance.name = "Sleepers"
	instance.multimesh = multimesh
	instance.material_override = _models.material(SLEEPER_COLOR, 0.85)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


## A small engine shed with a dark mouth where the train emerges.
func _add_depot(parent: Node3D, route: RailRoute) -> void:
	var depot := Node3D.new()
	depot.name = "Depot"
	parent.add_child(depot)
	var facing := route.direction_at(0.3)
	depot.transform = Transform3D(Basis.looking_at(facing, Vector3.UP), route.point_at(0.0))
	_models.shape(depot, "box", Vector3(-1.0, 0.95, 0.4), Vector3(0.45, 1.9, 2.0), DEPOT_WALL)
	_models.shape(depot, "box", Vector3(1.0, 0.95, 0.4), Vector3(0.45, 1.9, 2.0), DEPOT_WALL)
	_models.shape(depot, "box", Vector3(0.0, 0.95, 1.25), Vector3(1.6, 1.9, 0.3), TUNNEL, false)
	_models.shape(depot, "prism", Vector3(0.0, 2.3, 0.4), Vector3(2.8, 0.9, 2.3), DEPOT_ROOF)


## Red-and-white buffer stop marking the final stop (reaching it loses the level).
func _add_buffer_stop(parent: Node3D, route: RailRoute) -> void:
	var stop := Node3D.new()
	stop.name = "Final stop"
	parent.add_child(stop)
	var facing := route.direction_at(route.length - 0.3)
	stop.transform = Transform3D(Basis.looking_at(facing, Vector3.UP), route.point_at(route.length))
	_models.shape(stop, "box", Vector3(0.0, 0.45, 0.0), Vector3(1.6, 0.5, 0.35), Palette.DANGER)
	_models.shape(stop, "box", Vector3(-0.45, 0.45, -0.18), Vector3(0.28, 0.3, 0.1), Palette.WHITE, false)
	_models.shape(stop, "box", Vector3(0.45, 0.45, -0.18), Vector3(0.28, 0.3, 0.1), Palette.WHITE, false)
	_models.shape(stop, "cylinder", Vector3(0.95, 0.9, 0.0), Vector3(0.08, 1.8, 0.08), Palette.STEEL)
	_models.shape(stop, "box", Vector3(1.25, 1.6, 0.0), Vector3(0.6, 0.38, 0.05), Palette.DANGER)
