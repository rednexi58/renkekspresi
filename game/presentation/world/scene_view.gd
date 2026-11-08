class_name SceneView
extends Node3D
## The upper scene: a soft dirt path with stitched edges winding over the grass, rails on
## the path, a tunnel mound where the train enters, a little station at the final stop,
## and flowers, bushes and pebbles scattered around. Everything is built in the route's
## own coordinates; LevelWorld scales and places this node to fit the screen.
## Decoration is seeded per level and kept off the path.

const PATH_HALF_WIDTH := 1.05
const STITCH_SPACING := 0.42
const STITCH_INSET := 0.82
const RAIL_HALF_GAP := 0.28
const RAIL_SIZE := Vector2(0.07, 0.07)
const SLEEPER_SPACING := 0.42
const SLEEPER_SIZE := Vector3(0.9, 0.05, 0.16)
const DECORATION_ATTEMPTS := 90
const PATH_CLEARANCE := 1.5
const ZONE_COLOR := Color(1.0, 0.86, 0.3, 0.55)
const MOUND := Color("6dbb4a")
const TUNNEL := Color("2b2620")
const BOOTH_WALL := Color("fff1d8")
const BOOTH_ROOF := Color("e8473c")

var _models: ModelLibrary
var _routes: Array[RailRoute] = []
var _zones: Array[MeshInstance3D] = []
var _rng := RandomNumberGenerator.new()


func setup(models: ModelLibrary, level: LevelDefinition, routes: Array[RailRoute], engine: PuzzleEngine) -> void:
	_models = models
	_routes = routes
	_rng.seed = level.map_seed
	for lane in routes.size():
		_build_lane(routes[lane], engine)
	_decorate(level.theme)


## Ground rectangle of the scene in local coordinates (route plus a margin).
func bounds() -> Rect2:
	var result := _routes[0].bounds()
	for route in _routes:
		result = result.merge(route.bounds())
	return result.grow(1.6)


func loading_zones() -> Array[MeshInstance3D]:
	return _zones


func _build_lane(route: RailRoute, engine: PuzzleEngine) -> void:
	var full := PathExtruder.sample(route, 0.0, route.length)
	var path := PackedVector2Array([Vector2(-PATH_HALF_WIDTH, 0.0), Vector2(-PATH_HALF_WIDTH + 0.12, 0.05), Vector2(PATH_HALF_WIDTH - 0.12, 0.05), Vector2(PATH_HALF_WIDTH, 0.0)])
	_add_mesh("Path", PathExtruder.extrude(full, path, 0.0), _models.ground(Palette.PATH), false)
	_add_stitches(route)
	_add_sleepers(route)
	for side in [-1.0, 1.0]:
		var x: float = side * RAIL_HALF_GAP
		var rail := PackedVector2Array([Vector2(x - RAIL_SIZE.x * 0.5, 0.0), Vector2(x - RAIL_SIZE.x * 0.5, RAIL_SIZE.y), Vector2(x + RAIL_SIZE.x * 0.5, RAIL_SIZE.y), Vector2(x + RAIL_SIZE.x * 0.5, 0.0)])
		_add_mesh("Rail", PathExtruder.extrude(full, rail, 0.1), _models.material(Palette.RAIL, 0.5), false)
	var zone_path := PathExtruder.sample(route, engine.loading_start, engine.loading_end)
	var zone := _add_mesh("Loading zone", PathExtruder.extrude(zone_path, PackedVector2Array([Vector2(-0.82, 0.0), Vector2(0.82, 0.0)]), 0.075), _models.flat_material(ZONE_COLOR, true), false)
	zone.visible = false
	_zones.append(zone)
	_add_tunnel(route)
	_add_station_booth(route)


func _add_mesh(label: String, mesh: ArrayMesh, mat: Material, shadows: bool) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


## Dashed "stitching" just inside both path edges, as on a quilted fabric path.
func _add_stitches(route: RailRoute) -> void:
	var count := int(route.length / STITCH_SPACING)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _models.primitive("rounded_box")
	multimesh.instance_count = count * 2
	for i in count:
		var distance := (i + 0.5) * STITCH_SPACING
		var forward := route.direction_at(distance)
		var side := forward.cross(Vector3.UP).normalized()
		var basis := Basis.looking_at(forward, Vector3.UP).scaled(Vector3(0.07, 0.02, 0.22))
		for k in 2:
			var offset := side * STITCH_INSET * (1.0 if k == 0 else -1.0)
			multimesh.set_instance_transform(i * 2 + k, Transform3D(basis, route.point_at(distance) + offset + Vector3.UP * 0.06))
	var instance := MultiMeshInstance3D.new()
	instance.name = "Stitches"
	instance.multimesh = multimesh
	instance.material_override = _models.material(Palette.PATH_STITCH, 0.9)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _add_sleepers(route: RailRoute) -> void:
	var count := int(route.length / SLEEPER_SPACING)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _models.primitive("rounded_box")
	multimesh.instance_count = count
	for i in count:
		var distance := (i + 0.5) * SLEEPER_SPACING
		var basis := Basis.looking_at(route.direction_at(distance), Vector3.UP).scaled(SLEEPER_SIZE)
		multimesh.set_instance_transform(i, Transform3D(basis, route.point_at(distance) + Vector3.UP * 0.075))
	var instance := MultiMeshInstance3D.new()
	instance.name = "Sleepers"
	instance.multimesh = multimesh
	instance.material_override = _models.material(Palette.SLEEPER, 0.85)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


## A grassy mound with a dark arch: the train emerges from it.
func _add_tunnel(route: RailRoute) -> void:
	var tunnel := Node3D.new()
	tunnel.name = "Tunnel"
	tunnel.transform = Transform3D(Basis.looking_at(route.direction_at(0.4), Vector3.UP), route.point_at(0.0))
	add_child(tunnel)
	_models.shape(tunnel, "sphere", Vector3(0.0, 0.0, 0.9), Vector3(3.0, 2.2, 2.6), MOUND)
	_models.shape(tunnel, "sphere", Vector3(0.0, 0.25, -0.15), Vector3(1.25, 1.3, 0.5), TUNNEL, false)
	_models.shape(tunnel, "sphere", Vector3(0.0, 0.3, -0.12), Vector3(1.5, 1.55, 0.36), Palette.ROCK, false)
	_models.shape(tunnel, "sphere", Vector3(0.0, 0.25, -0.2), Vector3(1.2, 1.25, 0.4), TUNNEL, false)


## The final stop: buffer beam and a little station booth with a red roof.
func _add_station_booth(route: RailRoute) -> void:
	var stop := Node3D.new()
	stop.name = "Final stop"
	stop.transform = Transform3D(Basis.looking_at(route.direction_at(route.length - 0.4), Vector3.UP), route.point_at(route.length))
	add_child(stop)
	_models.shape(stop, "rounded_box", Vector3(0.0, 0.32, 0.0), Vector3(1.0, 0.24, 0.22), Palette.BUFFER)
	for side in [-0.32, 0.32]:
		_models.shape(stop, "rounded_box", Vector3(side, 0.18, -0.2), Vector3(0.1, 0.28, 0.4), Palette.CHASSIS)
	var booth := Node3D.new()
	booth.position = Vector3(1.55, 0.0, -0.3)
	stop.add_child(booth)
	_models.shape(booth, "rounded_box", Vector3(0.0, 0.5, 0.0), Vector3(1.0, 1.0, 0.9), BOOTH_WALL)
	_models.shape(booth, "prism", Vector3(0.0, 1.25, 0.0), Vector3(1.25, 0.55, 1.1), BOOTH_ROOF)
	_models.shape(booth, "box", Vector3(-0.51, 0.55, 0.0), Vector3(0.02, 0.35, 0.4), Color("6fc3e8"), false)
	_models.shape(booth, "cylinder", Vector3(0.62, 0.8, 0.4), Vector3(0.05, 1.6, 0.05), Palette.CHASSIS)
	_models.shape(booth, "box", Vector3(0.82, 1.45, 0.4), Vector3(0.4, 0.26, 0.03), Palette.DANGER, false)
	_models.contact_shadow(booth, Vector3(0.0, 0.01, 0.0), Vector2(1.7, 1.6), 0.35)


func _decorate(theme_id: int) -> void:
	var area := bounds().grow(4.0)
	for i in DECORATION_ATTEMPTS:
		var point := Vector3(_rng.randf_range(area.position.x, area.end.x), 0.0, _rng.randf_range(area.position.y, area.end.y))
		if _near_path(point):
			continue
		var roll := _rng.randf()
		if roll < 0.4:
			_flower(point)
		elif roll < 0.85:
			_bush(point, theme_id)
		else:
			_pebbles(point)


func _near_path(point: Vector3) -> bool:
	var limit := PATH_CLEARANCE * PATH_CLEARANCE
	for route in _routes:
		for p in route.points:
			if Vector2(p.x - point.x, p.z - point.z).length_squared() < limit:
				return true
		var start := route.point_at(0.0)
		var finish := route.point_at(route.length)
		if Vector2(start.x - point.x, start.z - point.z).length() < 2.4 or Vector2(finish.x - point.x, finish.z - point.z).length() < 3.0:
			return true
	return false


func _flower(point: Vector3) -> void:
	var petal := Palette.FLOWER_PETALS[_rng.randi_range(0, Palette.FLOWER_PETALS.size() - 1)]
	var size := _rng.randf_range(1.2, 1.7)
	_models.shape(self, "cylinder", point + Vector3(0.0, 0.12 * size, 0.0), Vector3(0.04, 0.24, 0.04) * size, Palette.BUSH.darkened(0.2), false)
	for k in 5:
		var angle := TAU * k / 5.0
		_models.shape(self, "sphere", point + Vector3(cos(angle) * 0.13, 0.26, sin(angle) * 0.13) * size, Vector3(0.16, 0.06, 0.16) * size, petal, false)
	_models.shape(self, "sphere", point + Vector3(0.0, 0.28 * size, 0.0), Vector3.ONE * 0.1 * size, Palette.FLOWER_CENTRE, false)


func _bush(point: Vector3, theme_id: int) -> void:
	var green := Palette.BUSH.lerp(Palette.scene_ground(theme_id), 0.15)
	for k in 3:
		var offset := Vector3(_rng.randf_range(-0.3, 0.3), 0.0, _rng.randf_range(-0.3, 0.3))
		var size := _rng.randf_range(0.6, 0.9)
		_models.shape(self, "sphere", point + offset + Vector3(0.0, size * 0.32, 0.0), Vector3(size, size * 0.8, size), green.lightened(_rng.randf_range(-0.05, 0.1)))
	_models.contact_shadow(self, point + Vector3(0.0, 0.01, 0.0), Vector2(1.3, 1.2), 0.25)


func _pebbles(point: Vector3) -> void:
	for k in _rng.randi_range(2, 3):
		var offset := Vector3(_rng.randf_range(-0.3, 0.3), 0.0, _rng.randf_range(-0.3, 0.3))
		var size := _rng.randf_range(0.18, 0.32)
		var stone := _models.shape(self, "low_sphere", point + offset + Vector3(0.0, size * 0.25, 0.0), Vector3(size * 1.3, size * 0.7, size), Palette.ROCK, false)
		stone.rotation.y = _rng.randf_range(0.0, TAU)
