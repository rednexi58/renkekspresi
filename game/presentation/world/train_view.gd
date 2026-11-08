class_name TrainView
extends Node3D
## Draws locomotives and wagons where the rules say they are. Read-only with respect to
## the rules: it mirrors PuzzleEngine state each frame and animates removals, but never
## decides which wagon leaves.

const WAGON_SCALE := 0.8
const ENGINE_SCALE := 0.82
## Height of the rail tops, where the wheels stand.
const RAIL_TOP := 0.17
const POP_SECONDS := 0.22

var _models: ModelLibrary
var _routes: Array[RailRoute] = []
var _engines: Array[Node3D] = []
var _wagons := {}


func setup(models: ModelLibrary, routes: Array[RailRoute], engine: PuzzleEngine, skin_id: String = "classic") -> void:
	_models = models
	_routes = routes
	for lane in routes.size():
		var locomotive := models.make_locomotive(skin_id)
		add_child(locomotive)
		_engines.append(locomotive)
	for wagon in engine.wagons:
		var view := models.make_wagon(wagon.color)
		view.visible = false
		add_child(view)
		_wagons[wagon.id] = view


func sync(engine: PuzzleEngine) -> void:
	for lane in _engines.size():
		var locomotive := _engines[lane]
		locomotive.visible = engine.has_lane(lane)
		if locomotive.visible:
			_place(locomotive, lane, engine.heads[lane], ENGINE_SCALE)
	for wagon in engine.wagons:
		var view: Node3D = _wagons[wagon.id]
		view.visible = wagon.distance >= 0.0
		if view.visible:
			_place(view, wagon.lane, wagon.distance, WAGON_SCALE)


## Global position of a wagon on its rail (used by match effects before it disappears).
func wagon_position(lane: int, distance: float) -> Vector3:
	return to_global(_routes[lane].point_at(distance) + Vector3.UP * 0.6)


## Pops the collected wagon off the rail; the rules have already removed it.
func remove_wagon(wagon_id: int) -> void:
	if not _wagons.has(wagon_id):
		return
	var view: Node3D = _wagons[wagon_id]
	_wagons.erase(wagon_id)
	var tween := create_tween()
	tween.tween_property(view, "scale", view.scale * 1.25, POP_SECONDS * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, "scale", Vector3.ONE * 0.01, POP_SECONDS * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(view.queue_free)


func _place(node: Node3D, lane: int, distance: float, size: float) -> void:
	var route := _routes[lane]
	var forward := route.direction_at(distance)
	node.transform = Transform3D(Basis.looking_at(forward, Vector3.UP).scaled(Vector3.ONE * size), route.point_at(distance) + Vector3.UP * RAIL_TOP)
