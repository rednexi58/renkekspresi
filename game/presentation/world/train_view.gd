class_name TrainView
extends Node3D
## Draws locomotives and wagons where the rules say they are. Read-only with respect to
## the rules: it mirrors PuzzleEngine state each frame and animates removals, but never
## decides which wagon leaves.

const WAGON_SCALE := 0.8
const ENGINE_SCALE := 0.82
const POP_SECONDS := 0.26
const POP_LIFT := 0.9
## Distance from a car's centre to each of its two bogies (wheel sets) along the rail.
## A car is placed on its bogies, like a real one: its body spans the chord between them,
## so it follows curves smoothly instead of pointing along the tangent at one point.
const WAGON_BOGIE := 0.44
const ENGINE_BOGIE := 0.5

var _models: ModelLibrary
var _routes: Array[RailRoute] = []
var _engines: Array[Node3D] = []
var _wagons := {}


func setup(models: ModelLibrary, routes: Array[RailRoute], engine: PuzzleEngine, skin_id: String = "classic") -> void:
	_models = models
	_routes = routes
	for lane in routes.size():
		var locomotive := models.make_locomotive(skin_id)
		_add_ground_shadow(locomotive, 2.3)
		add_child(locomotive)
		_engines.append(locomotive)
	for wagon in engine.wagons:
		var view := models.make_wagon(wagon.color)
		_add_ground_shadow(view, WagonModels.LENGTH)
		view.visible = false
		add_child(view)
		_wagons[wagon.id] = view


func sync(engine: PuzzleEngine) -> void:
	for lane in _engines.size():
		var locomotive := _engines[lane]
		locomotive.visible = engine.has_lane(lane)
		if locomotive.visible:
			_place(locomotive, lane, engine.heads[lane], ENGINE_SCALE, ENGINE_BOGIE)
	for wagon in engine.wagons:
		var view: Node3D = _wagons[wagon.id]
		view.visible = wagon.distance >= 0.0
		if view.visible:
			_place(view, wagon.lane, wagon.distance, WAGON_SCALE, WAGON_BOGIE)


## Global position of a wagon on its rail (used by match effects before it disappears).
func wagon_position(lane: int, distance: float) -> Vector3:
	return to_global(_routes[lane].point_at(distance) + Vector3.UP * 0.6)


## Lifts the collected wagon off the rail while it shrinks away; the rules have already
## removed it. It never grows, so it cannot overlap its neighbours as they close the gap.
func remove_wagon(wagon_id: int) -> void:
	if not _wagons.has(wagon_id):
		return
	var view: Node3D = _wagons[wagon_id]
	_wagons.erase(wagon_id)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(view, "position:y", view.position.y + POP_LIFT, POP_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, "scale", Vector3.ONE * 0.01, POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(view.queue_free)


## Soft dark patch under a car, on the sleepers, so it sits on the track instead of
## floating over it (the sun's shadow alone is too thin from this camera angle).
func _add_ground_shadow(car: Node3D, length: float) -> void:
	var height := (TrackBuilder.BALLAST_TOP + TrackBuilder.SLEEPER_SIZE.y + 0.004 - TrackBuilder.RAIL_TOP) / WAGON_SCALE
	_models.contact_shadow(car, Vector3(0.0, height, 0.0), Vector2(WagonModels.WIDTH + 0.7, length + 0.5), 0.5)


func _place(node: Node3D, lane: int, distance: float, size: float, bogie: float) -> void:
	var route := _routes[lane]
	var front := route.point_at(distance + bogie)
	var back := route.point_at(distance - bogie)
	var chord := front - back
	var forward := route.direction_at(distance) if chord.length_squared() < 0.0001 else chord.normalized()
	var facing := Basis.looking_at(forward, Vector3.UP) * Basis.from_scale(Vector3.ONE * size)
	node.transform = Transform3D(facing, (front + back) * 0.5 + Vector3.UP * TrackBuilder.RAIL_TOP)
