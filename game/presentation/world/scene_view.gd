class_name SceneView
extends Node3D
## The upper scene: a railway (see TrackBuilder) winding over the grass, a tunnel mound
## where the train enters, a little station at the final stop,
## and flowers, bushes and pebbles scattered around. Everything is built in the route's
## own coordinates; LevelWorld scales and places this node to fit the screen.
## Decoration is seeded per level and kept off the path.

const DECORATION_ATTEMPTS := 70
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
var _winter := false
## All decoration lives under one node so it can be clipped against the shelf band.
var _decor := Node3D.new()


## `theme_id` is the scenery to show (Season.theme_for), not necessarily the level's own.
func setup(models: ModelLibrary, level: LevelDefinition, routes: Array[RailRoute], engine: PuzzleEngine, theme_id: int) -> void:
	_models = models
	_routes = routes
	_rng.seed = level.map_seed
	_winter = theme_id == Season.SNOW_THEME
	_decor.name = "Decoration"
	add_child(_decor)
	for lane in routes.size():
		_build_lane(routes[lane], engine)
	_decorate(theme_id)


## Ground rectangle of the scene in local coordinates (route plus a margin).
func bounds() -> Rect2:
	var result := _routes[0].bounds()
	for route in _routes:
		result = result.merge(route.bounds())
	return result.grow(1.6)


var _zone_pulse := 0.0


## Breathing highlight on loading zones of lanes that are open.
func pulse_zones(delta: float) -> void:
	_zone_pulse += delta
	var alpha := 0.35 + 0.25 * sin(_zone_pulse * 5.0)
	for zone in _zones:
		if zone.visible:
			(zone.material_override as StandardMaterial3D).albedo_color.a = alpha


func loading_zones() -> Array[MeshInstance3D]:
	return _zones


func _build_lane(route: RailRoute, engine: PuzzleEngine) -> void:
	TrackBuilder.new(_models, _winter).build(self, route)
	var zone_path := PathExtruder.sample(route, engine.loading_start, engine.loading_end)
	var half := TrackBuilder.BALLAST_HALF_WIDTH + 0.12
	var zone := _add_mesh("Loading zone", PathExtruder.extrude(zone_path, PackedVector2Array([Vector2(-half, 0.0), Vector2(half, 0.0)]), TrackBuilder.BALLAST_TOP + 0.004), _models.flat_material(ZONE_COLOR, true), false)
	zone.visible = false
	_zones.append(zone)
	_add_tunnel(route)
	_add_station_booth(route)
	if _winter:
		_add_lamps(route)


## Winter evenings: little lamp posts with warm glowing bulbs along the track.
func _add_lamps(route: RailRoute) -> void:
	var spacing := 6.5
	var count := int(route.length / spacing)
	for i in count:
		var distance := (i + 0.6) * spacing
		var side := route.direction_at(distance).cross(Vector3.UP).normalized() * (1.6 if i % 2 == 0 else -1.6)
		var at := route.point_at(distance) + side
		if _near_path_within(at, 1.2):
			continue
		_models.shape(_decor, "cylinder", at + Vector3(0.0, 0.55, 0.0), Vector3(0.07, 1.1, 0.07), Color("39404d"))
		_models.shape(_decor, "rounded_box", at + Vector3(0.0, 1.16, 0.0), Vector3(0.24, 0.12, 0.24), Color("39404d"))
		_models.shape(_decor, "sphere", at + Vector3(0.0, 1.02, 0.0), Vector3.ONE * 0.2, Palette.LAMP_GLOW, false)
		_taken.append(at)


func _add_mesh(label: String, mesh: ArrayMesh, mat: Material, shadows: bool) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


## A grassy mound with a dark arch: the train emerges from it.
func _add_tunnel(route: RailRoute) -> void:
	var tunnel := Node3D.new()
	tunnel.name = "Tunnel"
	tunnel.transform = Transform3D(Basis.looking_at(route.direction_at(0.4), Vector3.UP), route.point_at(0.0))
	add_child(tunnel)
	_models.shape(tunnel, "sphere", Vector3(0.0, 0.0, 0.9), Vector3(3.0, 2.2, 2.6), Palette.SNOW if _winter else MOUND)
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


## Fills the scene in layers so it feels like a place rather than a board: soft grass
## patches, a pond, a theme landmark, rock outcrops and a frame of trees around the edge,
## then small flowers, bushes and pebbles in the gaps. Every item reserves a footprint
## so nothing overlaps and nothing touches the path.
func _decorate(theme_id: int) -> void:
	var inner := bounds()
	var outer := inner.grow(9.0)
	for i in 26:
		var patch := _free_point(outer, 1.0, 0.0)
		if patch.y >= 0.0:
			_grass_patch(patch, theme_id)
	var pond := _free_point(inner.grow(2.0), 2.4, 2.6)
	if pond.y >= 0.0:
		_pond(pond, theme_id)
	for i in 2:
		var landmark := _free_point(inner.grow(3.0), 2.2, 2.4)
		if landmark.y >= 0.0:
			_landmark(landmark, theme_id, i)
	for i in 5:
		var outcrop := _free_point(outer, 2.0, 1.8)
		if outcrop.y >= 0.0:
			_outcrop(outcrop, theme_id)
	for i in 70:
		var edge := _free_point(outer, 1.1, 1.05, inner.grow(0.5))
		if edge.y >= 0.0:
			_tree(edge, theme_id)
	for i in 30:
		var fence := _free_point(inner, 1.6, 1.2)
		if fence.y >= 0.0 and i % 3 == 0:
			_fence(fence)
	for i in DECORATION_ATTEMPTS:
		var point := _free_point(outer, 0.9, 0.4)
		if point.y < 0.0:
			continue
		var roll := _rng.randf()
		if _winter:
			if roll < 0.55:
				_snow_drift(point)
			elif roll < 0.85:
				_bush(point, theme_id)
			else:
				_pebbles(point)
		elif roll < 0.45:
			_flower(point)
		elif roll < 0.8:
			_bush(point, theme_id)
		else:
			_pebbles(point)


var _taken: Array[Vector3] = []


## A random free ground point (y = 0) in `area` at least `clearance` from the path and
## `radius` from every reserved footprint, optionally outside `avoid`. Returns a point
## with y = -1 when no free spot was found. The footprint is reserved on success.
func _free_point(area: Rect2, clearance: float, radius: float, avoid: Rect2 = Rect2()) -> Vector3:
	for attempt in 12:
		var point := Vector3(_rng.randf_range(area.position.x, area.end.x), 0.0, _rng.randf_range(area.position.y, area.end.y))
		if avoid.has_area() and avoid.has_point(Vector2(point.x, point.z)):
			continue
		if _near_path_within(point, clearance):
			continue
		var free := true
		for taken in _taken:
			if Vector2(taken.x - point.x, taken.z - point.z).length() < taken.y + radius:
				free = false
				break
		if free:
			if radius > 0.0:
				_taken.append(Vector3(point.x, radius, point.z))
			return point
	return Vector3(0.0, -1.0, 0.0)


func _near_path_within(point: Vector3, clearance: float) -> bool:
	var limit := clearance * clearance
	for route in _routes:
		for p in route.points:
			if Vector2(p.x - point.x, p.z - point.z).length_squared() < limit:
				return true
		var start := route.point_at(0.0)
		var finish := route.point_at(route.length)
		if Vector2(start.x - point.x, start.z - point.z).length() < 2.4 or Vector2(finish.x - point.x, finish.z - point.z).length() < 3.2:
			return true
	return false


func _grass_patch(point: Vector3, theme_id: int) -> void:
	var tint := Palette.scene_ground(theme_id).darkened(_rng.randf_range(0.03, 0.06))
	var patch := _models.shape_with(_decor, "sphere", point + Vector3(0.0, 0.0, 0.0), Vector3(_rng.randf_range(2.0, 4.0), 0.02, _rng.randf_range(1.4, 2.8)), _models.flat_material(tint), false)
	patch.rotation.y = _rng.randf_range(0.0, TAU)


func _pond(point: Vector3, theme_id: int) -> void:
	var water := Color("dff3ff") if theme_id == 5 else Color("5cc6ef")
	_models.shape(_decor, "sphere", point + Vector3(0.0, 0.0, 0.0), Vector3(4.4, 0.08, 3.2), Color("e9dcc0"), false)
	_models.shape_with(_decor, "sphere", point + Vector3(0.0, 0.02, 0.0), Vector3(4.0, 0.08, 2.8), _models.material(water, 0.15), false)
	_models.shape_with(_decor, "sphere", point + Vector3(-0.5, 0.04, -0.4), Vector3(1.6, 0.04, 0.9), _models.flat_material(water.lightened(0.3)), false)
	if theme_id != 5:
		for k in 3:
			var pad := point + Vector3(_rng.randf_range(-1.2, 1.2), 0.07, _rng.randf_range(-0.7, 0.7))
			_models.shape(_decor, "cylinder", pad, Vector3(0.42, 0.03, 0.42), Color("4fae4a"), false)
			if k == 0:
				_models.shape(_decor, "sphere", pad + Vector3(0.05, 0.08, 0.0), Vector3(0.18, 0.12, 0.18), Color("ff9ec4"), false)
	for k in 5:
		var angle := _rng.randf_range(0.0, TAU)
		var stone := point + Vector3(cos(angle) * 2.05, 0.08, sin(angle) * 1.45)
		_models.shape(_decor, "low_sphere", stone, Vector3(0.45, 0.25, 0.38), Palette.ROCK, false)


## One landmark per slot, chosen by theme: cottage, lighthouse, barn with hay, water tower,
## cactus group or snowman.
func _landmark(point: Vector3, theme_id: int, index: int) -> void:
	match theme_id:
		1:
			if index == 0:
				_lighthouse(point)
			else:
				_cottage(point, Color("6fb7e8"))
		2:
			if index == 0:
				_barn(point)
			else:
				_hay(point)
		3:
			if index == 0:
				_water_tower(point)
			else:
				_cottage(point, Color("b5543d"))
		4:
			_cactus(point)
		5:
			if index == 0:
				_snowman(point)
			else:
				_cottage(point, Color("e8473c"))
		_:
			_cottage(point, Color("e8473c") if index == 0 else Color("4a7bd1"))


func _cottage(point: Vector3, roof: Color) -> void:
	var house := Node3D.new()
	house.position = point
	house.rotation.y = _rng.randf_range(-0.4, 0.4)
	_decor.add_child(house)
	_models.shape(house, "rounded_box", Vector3(0.0, 0.6, 0.0), Vector3(1.6, 1.2, 1.3), Color("fff3dc"))
	_models.shape(house, "prism", Vector3(0.0, 1.55, 0.0), Vector3(1.9, 0.8, 1.5), roof)
	_models.shape(house, "rounded_box", Vector3(0.0, 0.38, 0.66), Vector3(0.36, 0.7, 0.06), Color("8a5a3c"))
	for side in [-0.5, 0.5]:
		_models.shape(house, "rounded_box", Vector3(side, 0.78, 0.66), Vector3(0.3, 0.3, 0.05), Color("8fd6f2"))
	_models.shape(house, "rounded_box", Vector3(0.45, 1.85, -0.2), Vector3(0.24, 0.5, 0.24), Color("c9b9a6"))
	_models.contact_shadow(house, Vector3(0.0, 0.01, 0.0), Vector2(2.6, 2.3), 0.3)


func _lighthouse(point: Vector3) -> void:
	for k in 4:
		var color := Color("ffffff") if k % 2 == 0 else Color("e8473c")
		_models.shape(_decor, "cylinder", point + Vector3(0.0, 0.35 + k * 0.6, 0.0), Vector3(0.9 - k * 0.1, 0.6, 0.9 - k * 0.1), color)
	_models.shape(_decor, "cylinder", point + Vector3(0.0, 2.75, 0.0), Vector3(0.62, 0.4, 0.62), Palette.LAMP)
	_models.shape(_decor, "cone", point + Vector3(0.0, 3.2, 0.0), Vector3(0.8, 0.5, 0.8), Color("2c3e78"))
	_models.contact_shadow(_decor, point + Vector3(0.0, 0.01, 0.0), Vector2(1.6, 1.6), 0.35)


func _barn(point: Vector3) -> void:
	var barn := Node3D.new()
	barn.position = point
	_decor.add_child(barn)
	_models.shape(barn, "rounded_box", Vector3(0.0, 0.75, 0.0), Vector3(1.9, 1.5, 1.5), Color("d9483b"))
	_models.shape(barn, "prism", Vector3(0.0, 1.85, 0.0), Vector3(2.1, 0.8, 1.65), Color("7a4a33"))
	_models.shape(barn, "rounded_box", Vector3(0.0, 0.55, 0.76), Vector3(0.8, 1.0, 0.05), Color("fff3dc"))
	_models.contact_shadow(barn, Vector3(0.0, 0.01, 0.0), Vector2(2.8, 2.4), 0.3)


func _hay(point: Vector3) -> void:
	for k in 3:
		var bale := _models.shape(_decor, "cylinder", point + Vector3((k - 1) * 0.75, 0.32, _rng.randf_range(-0.2, 0.2)), Vector3(0.62, 0.6, 0.62), Color("f2c75c"))
		bale.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	_models.contact_shadow(_decor, point + Vector3(0.0, 0.01, 0.0), Vector2(2.6, 1.3), 0.3)


func _water_tower(point: Vector3) -> void:
	for x in [-0.4, 0.4]:
		for z in [-0.4, 0.4]:
			_models.shape(_decor, "cylinder", point + Vector3(x, 0.7, z), Vector3(0.1, 1.4, 0.1), Color("6b4a35"))
	_models.shape(_decor, "cylinder", point + Vector3(0.0, 1.75, 0.0), Vector3(1.2, 0.8, 1.2), Color("9c6b45"))
	_models.shape(_decor, "cone", point + Vector3(0.0, 2.35, 0.0), Vector3(1.35, 0.45, 1.35), Color("5a6470"))
	_models.contact_shadow(_decor, point + Vector3(0.0, 0.01, 0.0), Vector2(1.8, 1.8), 0.3)


func _cactus(point: Vector3) -> void:
	var green := Color("4fae5a")
	_models.shape(_decor, "capsule", point + Vector3(0.0, 0.8, 0.0), Vector3(0.45, 1.6, 0.45), green)
	_models.shape(_decor, "capsule", point + Vector3(0.38, 0.95, 0.0), Vector3(0.28, 0.7, 0.28), green)
	_models.shape(_decor, "capsule", point + Vector3(-0.36, 0.75, 0.0), Vector3(0.26, 0.6, 0.26), green)
	_models.shape(_decor, "sphere", point + Vector3(0.0, 1.62, 0.0), Vector3.ONE * 0.18, Color("ff7aa8"), false)
	_models.contact_shadow(_decor, point + Vector3(0.0, 0.01, 0.0), Vector2(1.4, 1.2), 0.3)


func _snowman(point: Vector3) -> void:
	_models.shape(_decor, "sphere", point + Vector3(0.0, 0.45, 0.0), Vector3.ONE * 0.95, Color("ffffff"))
	_models.shape(_decor, "sphere", point + Vector3(0.0, 1.15, 0.0), Vector3.ONE * 0.65, Color("ffffff"))
	_models.shape(_decor, "cone", point + Vector3(0.0, 1.18, -0.38), Vector3(0.1, 0.3, 0.1), Color("ff8a2a"))
	_models.shape(_decor, "rounded_box", point + Vector3(0.0, 0.88, 0.0), Vector3(0.7, 0.1, 0.7), Color("e8473c"))
	_models.contact_shadow(_decor, point + Vector3(0.0, 0.01, 0.0), Vector2(1.4, 1.4), 0.3)


func _outcrop(point: Vector3, theme_id: int) -> void:
	var stone := Color("c97d4e") if theme_id == 4 else Color("aaa49a")
	for k in _rng.randi_range(3, 5):
		var offset := Vector3(_rng.randf_range(-0.8, 0.8), 0.0, _rng.randf_range(-0.6, 0.6))
		var size := _rng.randf_range(0.7, 1.3)
		var rock := _models.shape(_decor, "low_sphere" if theme_id != 4 else "rounded_box", point + offset + Vector3(0.0, size * 0.4, 0.0), Vector3(size * 1.2, size * 0.9, size), stone.lightened(_rng.randf_range(-0.06, 0.08)))
		rock.rotation = Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(0.0, TAU), _rng.randf_range(-0.2, 0.2))
	if theme_id == 5:
		_models.shape(_decor, "sphere", point + Vector3(0.0, 1.0, 0.0), Vector3(1.6, 0.35, 1.2), Color("ffffff"), false)
	_models.contact_shadow(_decor, point + Vector3(0.0, 0.01, 0.0), Vector2(3.0, 2.4), 0.3)


## Cute trees: round broadleaf on warm themes, layered pines on cool ones, snowy on snow.
func _tree(point: Vector3, theme_id: int) -> void:
	if theme_id == 4:
		if _rng.randf() < 0.6:
			_cactus(point)
		else:
			_outcrop(point, theme_id)
		return
	var pine := theme_id == 5 or theme_id == 3 or _rng.randf() < 0.45
	var size := _rng.randf_range(0.85, 1.3)
	var tree := Node3D.new()
	tree.position = point
	tree.scale = Vector3.ONE * size
	_decor.add_child(tree)
	_models.shape(tree, "cylinder", Vector3(0.0, 0.3, 0.0), Vector3(0.2, 0.6, 0.2), Color("8a5a3c"))
	if pine:
		var green := Color("3f9e5a")
		for layer in 3:
			var width := 1.5 - layer * 0.38
			_models.shape(tree, "cone", Vector3(0.0, 0.75 + layer * 0.48, 0.0), Vector3(width, 0.9, width), green.lightened(layer * 0.07))
			if theme_id == 5:
				_models.shape(tree, "cone", Vector3(0.0, 0.98 + layer * 0.48, 0.0), Vector3(width * 0.6, 0.42, width * 0.6), Color("ffffff"), false)
	else:
		var leaf := Color("6cc04a")
		_models.shape(tree, "sphere", Vector3(0.0, 1.2, 0.0), Vector3(1.45, 1.3, 1.45), leaf)
		_models.shape(tree, "sphere", Vector3(0.35, 1.55, 0.2), Vector3(0.8, 0.75, 0.8), leaf.lightened(0.12))
		if _rng.randf() < 0.35:
			for k in 3:
				var angle := _rng.randf_range(0.0, TAU)
				_models.shape(tree, "sphere", Vector3(cos(angle) * 0.62, 1.15 + _rng.randf_range(-0.2, 0.3), sin(angle) * 0.62), Vector3.ONE * 0.18, Color("ff5a5a"), false)
	_models.contact_shadow(tree, Vector3(0.0, 0.01, 0.0), Vector2(1.9, 1.9), 0.32)


func _fence(point: Vector3) -> void:
	var fence := Node3D.new()
	fence.position = point
	fence.rotation.y = _rng.randf_range(0.0, PI)
	_decor.add_child(fence)
	for k in 4:
		_models.shape(fence, "rounded_box", Vector3(-0.9 + k * 0.6, 0.32, 0.0), Vector3(0.12, 0.64, 0.12), Color("c99a6a"))
	for y in [0.22, 0.46]:
		_models.shape(fence, "rounded_box", Vector3(0.0, y, 0.0), Vector3(2.0, 0.08, 0.06), Color("b5865a"))


func _flower(point: Vector3) -> void:
	var petal := Palette.FLOWER_PETALS[_rng.randi_range(0, Palette.FLOWER_PETALS.size() - 1)]
	var size := _rng.randf_range(1.2, 1.7)
	_models.shape(_decor, "cylinder", point + Vector3(0.0, 0.12 * size, 0.0), Vector3(0.04, 0.24, 0.04) * size, Palette.BUSH.darkened(0.2), false)
	for k in 5:
		var angle := TAU * k / 5.0
		_models.shape(_decor, "sphere", point + Vector3(cos(angle) * 0.13, 0.26, sin(angle) * 0.13) * size, Vector3(0.16, 0.06, 0.16) * size, petal, false)
	_models.shape(_decor, "sphere", point + Vector3(0.0, 0.28 * size, 0.0), Vector3.ONE * 0.1 * size, Palette.FLOWER_CENTRE, false)


## Soft heaps of snow in place of flowers in winter.
func _snow_drift(point: Vector3) -> void:
	for k in _rng.randi_range(1, 3):
		var offset := Vector3(_rng.randf_range(-0.35, 0.35), 0.0, _rng.randf_range(-0.35, 0.35))
		var size := _rng.randf_range(0.45, 0.85)
		_models.shape(_decor, "low_sphere", point + offset, Vector3(size * 1.4, size * 0.45, size), Palette.SNOW, false)


func _bush(point: Vector3, theme_id: int) -> void:
	var green := Palette.BUSH.lerp(Palette.scene_ground(theme_id), 0.15)
	for k in 3:
		var offset := Vector3(_rng.randf_range(-0.3, 0.3), 0.0, _rng.randf_range(-0.3, 0.3))
		var size := _rng.randf_range(0.6, 0.9)
		_models.shape(_decor, "sphere", point + offset + Vector3(0.0, size * 0.32, 0.0), Vector3(size, size * 0.8, size), green.lightened(_rng.randf_range(-0.05, 0.1)))
		if _winter:
			_models.shape(_decor, "sphere", point + offset + Vector3(0.0, size * 0.62, 0.0), Vector3(size * 0.8, size * 0.32, size * 0.8), Palette.SNOW, false)
	_models.contact_shadow(_decor, point + Vector3(0.0, 0.01, 0.0), Vector2(1.3, 1.2), 0.25)


func _pebbles(point: Vector3) -> void:
	for k in _rng.randi_range(2, 3):
		var offset := Vector3(_rng.randf_range(-0.3, 0.3), 0.0, _rng.randf_range(-0.3, 0.3))
		var size := _rng.randf_range(0.18, 0.32)
		var stone := _models.shape(_decor, "low_sphere", point + offset + Vector3(0.0, size * 0.25, 0.0), Vector3(size * 1.3, size * 0.7, size), Palette.ROCK, false)
		stone.rotation.y = _rng.randf_range(0.0, TAU)
