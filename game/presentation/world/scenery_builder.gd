class_name SceneryBuilder
extends RefCounted
## Ground and themed decoration around the rails. Decoration is seeded per level
## (map_seed) so a level always looks the same, and it never stands on a rail, the
## station or the yard, so it can never hide a piece the player needs to read.

const GROUND_SIZE := Vector3(90.0, 1.0, 90.0)
const RAIL_CLEARANCE := 1.9
const DECORATION_ATTEMPTS := 70

const TRUNK := Color("8a5a3c")
const TREE_GREENS: Array[Color] = [Color("2fb36b"), Color("49c978"), Color("7ad96b")]
const SNOW_TREE := Color("3e9c7a")
const SNOW := Color("ffffff")
const HOUSE_WALLS: Array[Color] = [Color("fff1d6"), Color("ffe0e6"), Color("e3f1ff")]
const HOUSE_ROOFS: Array[Color] = [Color("ff6f5e"), Color("3f8cff"), Color("ffb321")]
const WINDOW := Color("9fe9ff")
const ROCK := Color("d9c2a3")
const CANYON_STONE: Array[Color] = [Color("e59a63"), Color("f2b27b"), Color("c97a4c")]
const WATER := Color("4fc3f7")
const SHALLOW := Color("8fe3f5")
const FLOWERS: Array[Color] = [Color("ff6fa8"), Color("ffffff"), Color("ffd23f")]

var _models: ModelLibrary
var _rng := RandomNumberGenerator.new()


func _init(models: ModelLibrary) -> void:
	_models = models


func build(parent: Node3D, level: LevelDefinition, routes: Array[RailRoute], layout: WorldLayout) -> void:
	var colors := Palette.theme(level.theme)
	_rng.seed = level.map_seed
	var ground := _models.shape(parent, "box", Vector3(0.0, -0.5, 0.0), GROUND_SIZE, colors["ground"], false)
	ground.name = "Ground"
	_add_station_area(parent, layout, colors)
	var bounds := _route_bounds(routes)
	if level.theme == 1:
		_add_water(parent, bounds)
	var blocked := _blocked_areas(layout)
	var placed := 0
	for i in DECORATION_ATTEMPTS:
		var point := Vector3(_rng.randf_range(-13.0, 13.0), 0.0, _rng.randf_range(bounds.position.y - 4.0, bounds.end.y + 1.0))
		if _near_rail(point, routes) or _inside(point, blocked) or (level.theme == 1 and point.x < -9.0):
			continue
		_decorate(parent, point, level.theme, placed)
		placed += 1
	_add_side_trees(parent, layout, level.theme)


func _add_station_area(parent: Node3D, layout: WorldLayout, colors: Dictionary) -> void:
	var yard := layout.yard_rect()
	var board_edge := _models.shape(parent, "box", Vector3(0.0, 0.06, yard.get_center().y + 0.12), Vector3(yard.size.x + 0.3, 0.2, yard.size.y + 0.4), Palette.BOARD_EDGE, false)
	board_edge.name = "Board lip"
	var board := _models.shape(parent, "box", Vector3(0.0, 0.1, yard.get_center().y), Vector3(yard.size.x, 0.2, yard.size.y), Palette.BOARD, false)
	board.name = "Puzzle board"
	var width := WorldLayout.BERTH_SPACING * 5.0 + 0.8
	var base := _models.shape(parent, "box", Vector3(0.0, 0.1, WorldLayout.STATION_Z + 0.1), Vector3(width + 0.3, 0.2, 3.1), Palette.PLATFORM_EDGE, false)
	base.name = "Platform base"
	var platform := _models.shape(parent, "box", Vector3(0.0, 0.16, WorldLayout.STATION_Z), Vector3(width, 0.2, 2.8), Palette.PLATFORM, false)
	platform.name = "Station platform"
	var edge := _models.shape(parent, "box", Vector3(0.0, 0.27, WorldLayout.STATION_Z - 1.25), Vector3(width, 0.03, 0.2), Palette.GOLD_DARK, false)
	edge.name = "Platform safety line"


func _route_bounds(routes: Array[RailRoute]) -> Rect2:
	var bounds := routes[0].bounds()
	for route in routes:
		bounds = bounds.merge(route.bounds())
	return bounds


func _blocked_areas(layout: WorldLayout) -> Array[Rect2]:
	var yard := layout.yard_rect()
	return [yard.grow(0.8), Rect2(Vector2(-8.5, WorldLayout.STATION_Z - 2.0), Vector2(17.0, 4.0))]


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


func _decorate(parent: Node3D, point: Vector3, theme_id: int, index: int) -> void:
	match theme_id:
		1:
			if index % 4 == 0:
				_house(parent, point)
			elif index % 3 == 0:
				_rock(parent, point, ROCK)
			else:
				_round_tree(parent, point)
		2:
			if index % 3 == 0:
				_house(parent, point)
			elif index % 3 == 1:
				_flowers(parent, point)
			else:
				_round_tree(parent, point)
		3:
			if index % 2 == 0:
				_house(parent, point)
			else:
				_round_tree(parent, point)
		4:
			_canyon_rock(parent, point)
		5:
			_pine(parent, point, true)
		_:
			if index % 3 == 0:
				_pine(parent, point, false)
			elif index % 5 == 1:
				_flowers(parent, point)
			else:
				_round_tree(parent, point)


## A row of trees beside the yard frames the play area without crowding it.
func _add_side_trees(parent: Node3D, layout: WorldLayout, theme_id: int) -> void:
	var yard := layout.yard_rect()
	for side in [-1.0, 1.0]:
		var z := yard.position.y
		while z < yard.end.y:
			var point := Vector3(side * (yard.size.x * 0.5 + 1.6), 0.0, z)
			if theme_id == 4:
				_canyon_rock(parent, point)
			elif theme_id == 5:
				_pine(parent, point, true)
			else:
				_round_tree(parent, point)
			z += 2.6


func _round_tree(parent: Node3D, point: Vector3) -> void:
	var size := _rng.randf_range(0.85, 1.25)
	_models.shape(parent, "cylinder", point + Vector3(0.0, 0.45 * size, 0.0), Vector3(0.22, 0.9, 0.22) * size, TRUNK)
	var green := TREE_GREENS[_rng.randi_range(0, TREE_GREENS.size() - 1)]
	_models.shape(parent, "sphere", point + Vector3(0.0, 1.35 * size, 0.0), Vector3(1.35, 1.25, 1.35) * size, green)
	_models.shape(parent, "sphere", point + Vector3(0.25, 1.85 * size, 0.1), Vector3(0.8, 0.75, 0.8) * size, green.lightened(0.12))


func _pine(parent: Node3D, point: Vector3, snowy: bool) -> void:
	var size := _rng.randf_range(0.85, 1.2)
	_models.shape(parent, "cylinder", point + Vector3(0.0, 0.3 * size, 0.0), Vector3(0.2, 0.6, 0.2) * size, TRUNK)
	var green := SNOW_TREE if snowy else TREE_GREENS[0]
	for layer in 3:
		var width := (1.5 - layer * 0.35) * size
		_models.shape(parent, "cone", point + Vector3(0.0, (0.9 + layer * 0.55) * size, 0.0), Vector3(width, 0.95 * size, width), green.lightened(layer * 0.06))
	if snowy:
		_models.shape(parent, "cone", point + Vector3(0.0, 2.15 * size, 0.0), Vector3(0.55, 0.4, 0.55) * size, SNOW, false)


func _house(parent: Node3D, point: Vector3) -> void:
	var house := Node3D.new()
	house.position = point
	house.rotation.y = _rng.randf_range(-0.4, 0.4)
	parent.add_child(house)
	var style := _rng.randi_range(0, HOUSE_WALLS.size() - 1)
	_models.shape(house, "box", Vector3(0.0, 0.6, 0.0), Vector3(1.4, 1.2, 1.2), HOUSE_WALLS[style])
	_models.shape(house, "prism", Vector3(0.0, 1.55, 0.0), Vector3(1.6, 0.7, 1.35), HOUSE_ROOFS[style])
	_models.shape(house, "box", Vector3(0.0, 0.35, 0.61), Vector3(0.32, 0.6, 0.04), Palette.INK_SOFT, false)
	for side in [-0.42, 0.42]:
		_models.shape(house, "box", Vector3(side, 0.75, 0.61), Vector3(0.28, 0.28, 0.04), WINDOW, false)


func _rock(parent: Node3D, point: Vector3, color: Color) -> void:
	var size := _rng.randf_range(0.6, 1.1)
	var rock := _models.shape(parent, "low_sphere", point + Vector3(0.0, 0.25 * size, 0.0), Vector3(1.1, 0.65, 0.9) * size, color)
	rock.rotation.y = _rng.randf_range(0.0, TAU)


func _canyon_rock(parent: Node3D, point: Vector3) -> void:
	var size := _rng.randf_range(0.8, 1.3)
	for layer in 3:
		var width := (1.5 - layer * 0.3) * size
		_models.shape(parent, "low_sphere", point + Vector3(0.0, (0.3 + layer * 0.42) * size, 0.0), Vector3(width, 0.5 * size, width * 0.85), CANYON_STONE[layer])


func _flowers(parent: Node3D, point: Vector3) -> void:
	for i in 5:
		var offset := Vector3(_rng.randf_range(-0.6, 0.6), 0.12, _rng.randf_range(-0.6, 0.6))
		_models.shape(parent, "sphere", point + offset, Vector3.ONE * 0.24, FLOWERS[i % FLOWERS.size()], false)


func _add_water(parent: Node3D, bounds: Rect2) -> void:
	var centre_z := bounds.get_center().y
	var depth := bounds.size.y + 14.0
	_models.shape(parent, "box", Vector3(-16.0, 0.01, centre_z), Vector3(12.0, 0.04, depth), WATER, false)
	_models.shape(parent, "box", Vector3(-10.4, 0.02, centre_z), Vector3(1.4, 0.04, depth), SHALLOW, false)
