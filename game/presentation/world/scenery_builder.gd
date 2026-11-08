class_name SceneryBuilder
extends RefCounted
## Ground, the station (platform, building, canopy, lamps) and themed decoration.
## Decoration is seeded per level (map_seed) so a level always looks the same, and it is
## kept off rails, the station and the yard so it can never hide a piece the player must
## read.

const GROUND_SIZE := Vector3(120.0, 1.0, 120.0)
const RAIL_CLEARANCE := 1.7
const DECORATION_ATTEMPTS := 150

const TRUNK := Color("5b3d2a")
const BARK := Color("6e4a33")
const ROCK := Color("9a958d")
const CANYON_STONE: Array[Color] = [Color("b8683c"), Color("c97d4e"), Color("a85a33")]
const WATER := Color("2f8fbf")
const SHORE := Color("e8d6a6")
const HOUSE_WALLS: Array[Color] = [Color("efe3cc"), Color("e7d2c0"), Color("dfe3e6")]
const HOUSE_ROOFS: Array[Color] = [Color("9b3d2f"), Color("4d5c6b"), Color("7a4a2f")]
const WINDOW := Color("2f4a5c")
const LAMP_POST := Color("2d3238")
const BENCH := Color("6b4a35")
const SNOW := Color("f7fbff")

var _models: ModelLibrary
var _rng := RandomNumberGenerator.new()
var _foliage := Color()


func _init(models: ModelLibrary) -> void:
	_models = models


func build(parent: Node3D, level: LevelDefinition, routes: Array[RailRoute], layout: WorldLayout) -> void:
	var colors := Palette.theme(level.theme)
	_foliage = colors["foliage"]
	_rng.seed = level.map_seed
	var ground := _models.shape_with(parent, "box", Vector3(0.0, -0.5, 0.0), GROUND_SIZE, _models.grass(colors["ground"]), false)
	ground.name = "Ground"
	_add_yard(parent, layout, colors)
	_add_station(parent, layout, colors)
	var bounds := _route_bounds(routes)
	if level.theme == 1:
		_add_water(parent, bounds)
	var blocked := _blocked_areas(layout)
	var placed := 0
	for i in DECORATION_ATTEMPTS:
		var point := Vector3(_rng.randf_range(-15.0, 15.0), 0.0, _rng.randf_range(bounds.position.y - 6.0, bounds.end.y + 1.0))
		if _near_rail(point, routes) or _inside(point, blocked) or (level.theme == 1 and point.x < -9.5):
			continue
		_decorate(parent, point, level.theme, placed)
		placed += 1
	_add_side_rows(parent, layout, level.theme)


# --- Yard and station ----------------------------------------------------------------

func _add_yard(parent: Node3D, layout: WorldLayout, colors: Dictionary) -> void:
	var yard := layout.yard_rect()
	var centre := Vector3(0.0, 0.0, yard.get_center().y)
	var curb := _models.shape_with(parent, "rounded_box", centre + Vector3(0.0, 0.06, 0.0), Vector3(yard.size.x + 0.5, 0.16, yard.size.y + 0.5), _models.concrete(Palette.CURB), false)
	curb.name = "Yard curb"
	var bed := _models.shape_with(parent, "box", centre + Vector3(0.0, 0.1, 0.0), Vector3(yard.size.x, 0.12, yard.size.y), _models.gravel(colors["gravel"]), false)
	bed.name = "Yard gravel"


func _add_station(parent: Node3D, layout: WorldLayout, colors: Dictionary) -> void:
	var width := WorldLayout.BERTH_SPACING * 5.0 + 1.2
	var z := WorldLayout.STATION_Z
	var bed := _models.shape_with(parent, "box", Vector3(0.0, 0.06, z), Vector3(width, 0.12, 2.9), _models.gravel(colors["gravel"]), false)
	bed.name = "Siding gravel"
	# Passenger platform between the sidings and the yard, with the yellow safety edge.
	var platform := _models.shape_with(parent, "rounded_box", Vector3(0.0, 0.2, z + 2.05), Vector3(width, 0.4, 1.2), _models.concrete(Palette.PLATFORM), false)
	platform.name = "Platform"
	_models.shape(parent, "box", Vector3(0.0, 0.405, z + 1.52), Vector3(width, 0.012, 0.12), Palette.PLATFORM_EDGE, false)
	for i in 6:
		var x := (i - 2.5) * WorldLayout.BERTH_SPACING
		_lamp(parent, Vector3(x, 0.4, z + 2.35))
	_canopy(parent, width, z + 2.05)
	_station_house(parent, Vector3(width * 0.5 + 2.2, 0.0, z + 1.2))


## Platform canopy: a thin roof on slim columns along the back of the platform. Kept
## low and narrow so it frames the sidings without covering any wagon.
func _canopy(parent: Node3D, width: float, z: float) -> void:
	for i in 7:
		var x := (i - 3.0) * (width - 1.0) / 6.0
		_models.shape(parent, "cylinder", Vector3(x, 1.1, z + 0.35), Vector3(0.09, 1.4, 0.09), Palette.STATION_TRIM)
	var roof := _models.shape(parent, "rounded_box", Vector3(0.0, 1.85, z + 0.3), Vector3(width, 0.07, 0.7), Palette.CANOPY)
	roof.rotation_degrees = Vector3(-8.0, 0.0, 0.0)


func _lamp(parent: Node3D, base: Vector3) -> void:
	_models.shape(parent, "cylinder", base + Vector3(0.0, 0.7, 0.0), Vector3(0.06, 1.4, 0.06), LAMP_POST)
	_models.shape(parent, "rounded_box", base + Vector3(0.0, 1.42, -0.12), Vector3(0.16, 0.08, 0.3), LAMP_POST)
	_models.shape_with(parent, "sphere", base + Vector3(0.0, 1.36, -0.22), Vector3.ONE * 0.1, _models.material(Palette.LAMP, 0.3, 0.0, 1.2), false)


func _station_house(parent: Node3D, at: Vector3) -> void:
	var house := Node3D.new()
	house.name = "Station house"
	house.position = at
	parent.add_child(house)
	_models.shape(house, "rounded_box", Vector3(0.0, 1.0, 0.0), Vector3(2.4, 2.0, 2.6), Palette.STATION_WALL)
	_models.shape(house, "rounded_box", Vector3(0.0, 0.12, 0.0), Vector3(2.5, 0.24, 2.7), Palette.STATION_TRIM)
	_models.shape(house, "prism", Vector3(0.0, 2.45, 0.0), Vector3(2.9, 1.0, 3.0), Palette.STATION_ROOF)
	_models.shape(house, "rounded_box", Vector3(0.0, 2.95, 0.6), Vector3(0.3, 0.6, 0.3), Palette.STATION_TRIM)
	for k in 3:
		var z := -0.8 + k * 0.8
		_models.shape(house, "box", Vector3(-1.21, 1.15, z), Vector3(0.03, 0.6, 0.4), WINDOW, false)
	_models.shape(house, "box", Vector3(-1.21, 0.6, 0.0), Vector3(0.03, 1.0, 0.5), Palette.STATION_TRIM, false)
	_models.contact_shadow(house, Vector3(0.0, 0.02, 0.0), Vector2(3.6, 3.8), 0.35)


func _route_bounds(routes: Array[RailRoute]) -> Rect2:
	var bounds := routes[0].bounds()
	for route in routes:
		bounds = bounds.merge(route.bounds())
	return bounds


func _blocked_areas(layout: WorldLayout) -> Array[Rect2]:
	var yard := layout.yard_rect()
	var station := Rect2(Vector2(-10.5, WorldLayout.STATION_Z - 2.0), Vector2(21.0, 5.0))
	var house := Rect2(Vector2(WorldLayout.BERTH_SPACING * 2.5 + 0.6, WorldLayout.STATION_Z - 1.0), Vector2(4.0, 4.0))
	var areas: Array[Rect2] = [yard.grow(0.9), station, house]
	return areas


func _inside(point: Vector3, areas: Array[Rect2]) -> bool:
	for area in areas:
		if area.has_point(Vector2(point.x, point.z)):
			return true
	return false


func _near_rail(point: Vector3, routes: Array[RailRoute]) -> bool:
	var limit := RAIL_CLEARANCE * RAIL_CLEARANCE
	for route in routes:
		for p in route.points:
			if Vector2(p.x - point.x, p.z - point.z).length_squared() < limit:
				return true
	return false


# --- Decoration ----------------------------------------------------------------------

func _decorate(parent: Node3D, point: Vector3, theme_id: int, index: int) -> void:
	match theme_id:
		1:
			if index % 7 == 0:
				_house(parent, point)
			elif index % 3 == 0:
				_rock_cluster(parent, point, ROCK)
			else:
				_broadleaf(parent, point)
		2:
			if index % 6 == 0:
				_house(parent, point)
			elif index % 3 == 0:
				_bush(parent, point)
			else:
				_broadleaf(parent, point)
		3:
			if index % 4 == 0:
				_house(parent, point)
			elif index % 3 == 0:
				_bush(parent, point)
			else:
				_pine(parent, point, false)
		4:
			if index % 3 == 0:
				_bush(parent, point)
			else:
				_mesa(parent, point)
		5:
			if index % 5 == 0:
				_rock_cluster(parent, point, ROCK.lightened(0.2))
			else:
				_pine(parent, point, true)
		_:
			if index % 4 == 0:
				_rock_cluster(parent, point, ROCK)
			elif index % 3 == 0:
				_bush(parent, point)
			else:
				_pine(parent, point, false)


## Dense rows of trees (or rocks) beside the yard frame the play area like a forest edge.
func _add_side_rows(parent: Node3D, layout: WorldLayout, theme_id: int) -> void:
	var yard := layout.yard_rect()
	for side in [-1.0, 1.0]:
		var z := yard.position.y - 1.0
		while z < yard.end.y + 4.0:
			for column in 3:
				var point := Vector3(side * (yard.size.x * 0.5 + 1.5 + column * 1.8 + _rng.randf_range(-0.3, 0.3)), 0.0, z + _rng.randf_range(-0.5, 0.5))
				if theme_id == 4:
					_mesa(parent, point)
				elif theme_id == 1 or theme_id == 2:
					_broadleaf(parent, point)
				else:
					_pine(parent, point, theme_id == 5)
			z += 1.9


func _pine(parent: Node3D, point: Vector3, snowy: bool) -> void:
	var size := _rng.randf_range(0.8, 1.35)
	var tilt := Vector3(_rng.randf_range(-0.04, 0.04), _rng.randf_range(0.0, TAU), _rng.randf_range(-0.04, 0.04))
	var tree := Node3D.new()
	tree.position = point
	tree.rotation = tilt
	tree.scale = Vector3.ONE * size
	parent.add_child(tree)
	_models.shape(tree, "cylinder", Vector3(0.0, 0.3, 0.0), Vector3(0.14, 0.6, 0.14), TRUNK)
	for layer in 4:
		var width := 1.45 - layer * 0.3
		var shade := _foliage.lightened(layer * 0.05).darkened(0.05 if layer == 0 else 0.0)
		_models.shape(tree, "cone", Vector3(0.0, 0.75 + layer * 0.45, 0.0), Vector3(width, 0.85, width), shade)
		if snowy:
			_models.shape(tree, "cone", Vector3(0.0, 0.98 + layer * 0.45, 0.0), Vector3(width * 0.62, 0.42, width * 0.62), SNOW, false)
	_models.contact_shadow(tree, Vector3(0.0, 0.03, 0.0), Vector2(1.7, 1.7), 0.35)


func _broadleaf(parent: Node3D, point: Vector3) -> void:
	var size := _rng.randf_range(0.8, 1.25)
	var tree := Node3D.new()
	tree.position = point
	tree.rotation.y = _rng.randf_range(0.0, TAU)
	tree.scale = Vector3.ONE * size
	parent.add_child(tree)
	_models.shape(tree, "cylinder", Vector3(0.0, 0.55, 0.0), Vector3(0.16, 1.1, 0.16), BARK)
	var base := _foliage.lightened(0.08)
	for blob in [Vector4(0.0, 1.45, 0.0, 1.25), Vector4(0.38, 1.25, 0.15, 0.85), Vector4(-0.35, 1.3, -0.12, 0.9), Vector4(0.05, 1.9, -0.05, 0.8)]:
		var tint := base.lightened(_rng.randf_range(-0.06, 0.1))
		_models.shape(tree, "sphere", Vector3(blob.x, blob.y, blob.z), Vector3(blob.w, blob.w * 0.85, blob.w), tint)
	_models.contact_shadow(tree, Vector3(0.0, 0.03, 0.0), Vector2(2.0, 2.0), 0.35)


func _bush(parent: Node3D, point: Vector3) -> void:
	var tint := _foliage.lightened(0.12)
	for k in 3:
		var offset := Vector3(_rng.randf_range(-0.35, 0.35), 0.0, _rng.randf_range(-0.35, 0.35))
		var size := _rng.randf_range(0.45, 0.7)
		_models.shape(parent, "sphere", point + offset + Vector3(0.0, size * 0.35, 0.0), Vector3(size, size * 0.75, size), tint.lightened(_rng.randf_range(-0.05, 0.08)))
	_models.contact_shadow(parent, point + Vector3(0.0, 0.03, 0.0), Vector2(1.4, 1.4), 0.3)


func _rock_cluster(parent: Node3D, point: Vector3, color: Color) -> void:
	for k in _rng.randi_range(2, 3):
		var offset := Vector3(_rng.randf_range(-0.4, 0.4), 0.0, _rng.randf_range(-0.4, 0.4))
		var size := _rng.randf_range(0.35, 0.8)
		var rock := _models.shape_with(parent, "low_sphere", point + offset + Vector3(0.0, size * 0.22, 0.0), Vector3(size * 1.3, size * 0.75, size), _models.concrete(color), true)
		rock.rotation = Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf_range(0.0, TAU), _rng.randf_range(-0.3, 0.3))
	_models.contact_shadow(parent, point + Vector3(0.0, 0.03, 0.0), Vector2(1.6, 1.4), 0.3)


func _mesa(parent: Node3D, point: Vector3) -> void:
	var size := _rng.randf_range(0.8, 1.3)
	for layer in 3:
		var width := (1.5 - layer * 0.32) * size
		var stone := _models.shape_with(parent, "low_sphere", point + Vector3(0.0, (0.28 + layer * 0.4) * size, 0.0), Vector3(width, 0.55 * size, width * 0.85), _models.concrete(CANYON_STONE[layer]))
		stone.rotation.y = _rng.randf_range(0.0, TAU)
	_models.contact_shadow(parent, point + Vector3(0.0, 0.03, 0.0), Vector2(2.2, 2.0), 0.3)


func _house(parent: Node3D, point: Vector3) -> void:
	var house := Node3D.new()
	house.position = point
	house.rotation.y = _rng.randf_range(-0.5, 0.5)
	parent.add_child(house)
	var style := _rng.randi_range(0, HOUSE_WALLS.size() - 1)
	_models.shape(house, "rounded_box", Vector3(0.0, 0.65, 0.0), Vector3(1.6, 1.3, 1.3), HOUSE_WALLS[style])
	_models.shape(house, "prism", Vector3(0.0, 1.62, 0.0), Vector3(1.85, 0.75, 1.45), HOUSE_ROOFS[style])
	_models.shape(house, "rounded_box", Vector3(0.45, 1.85, 0.3), Vector3(0.22, 0.5, 0.22), HOUSE_ROOFS[style].darkened(0.2))
	_models.shape(house, "box", Vector3(0.0, 0.38, 0.66), Vector3(0.32, 0.62, 0.03), Palette.STATION_TRIM, false)
	for side in [-0.48, 0.48]:
		_models.shape(house, "box", Vector3(side, 0.8, 0.66), Vector3(0.3, 0.3, 0.03), WINDOW, false)
	_models.contact_shadow(house, Vector3(0.0, 0.03, 0.0), Vector2(2.4, 2.1), 0.35)


func _add_water(parent: Node3D, bounds: Rect2) -> void:
	var centre_z := bounds.get_center().y
	var depth := bounds.size.y + 30.0
	_models.shape(parent, "box", Vector3(-11.2, 0.0, centre_z), Vector3(2.4, 0.06, depth), SHORE, false)
	_models.shape_with(parent, "box", Vector3(-19.0, 0.02, centre_z), Vector3(14.0, 0.06, depth), _models.textured("water", PackedColorArray([WATER.darkened(0.1), WATER, WATER.lightened(0.15)]), 0.06, 0.12, 0.15), false)
