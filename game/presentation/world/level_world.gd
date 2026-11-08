class_name LevelWorld
extends Node3D
## Composes the 3D diorama of one level (environment, scenery, rails, station, yard,
## train, camera) and exposes the few operations the game flow needs. It owns no rules:
## everything it shows is read from the PuzzleEngine passed to sync().

const CONFETTI_COLORS_COUNT := 5

var camera: CameraRig
var _models := ModelLibrary.new()
var _layout: WorldLayout
var _routes: Array[RailRoute] = []
var _zones: Array[MeshInstance3D] = []
var _train: TrainView
var _station: StationView
var _yard: YardView
var _zone_pulse := 0.0


func build(level: LevelDefinition, routes: Array[RailRoute], engine: PuzzleEngine) -> void:
	_routes = routes
	_layout = WorldLayout.new(level)
	var colors := Palette.theme(level.theme)
	_add_environment(colors["clear"])
	var scenery := Node3D.new()
	scenery.name = "Scenery"
	add_child(scenery)
	SceneryBuilder.new(_models).build(scenery, level, routes, _layout)
	var track := Node3D.new()
	track.name = "Track"
	add_child(track)
	_zones = TrackBuilder.new(_models).build(track, routes, engine, colors["bed"])
	_station = StationView.new()
	_station.name = "Station"
	add_child(_station)
	_station.setup(_models, _layout)
	_yard = YardView.new()
	_yard.name = "Yard"
	add_child(_yard)
	_yard.setup(_models, _layout, engine)
	_train = TrainView.new()
	_train.name = "Train"
	add_child(_train)
	_train.setup(_models, routes, engine)
	camera = CameraRig.new()
	camera.name = "Camera"
	add_child(camera)
	camera.set_subject(_subject_points())
	camera.make_current()
	sync(engine)


func _add_environment(clear_color: Color) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = clear_color
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("cfe0ff")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("fff4e0")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.7
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 80.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.rotation_degrees = Vector3(-58.0, -28.0, 0.0)
	add_child(sun)


## Key points that must always be on screen: rail ends and bends, station, yard corners.
func _subject_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	for route in _routes:
		var step := maxi(1, route.points.size() / 24)
		for i in range(0, route.points.size(), step):
			points.append(route.points[i])
			points.append(route.points[i] + Vector3.UP * 2.6)
		points.append(route.points[route.points.size() - 1])
	var yard := _layout.yard_rect()
	for corner in [yard.position, Vector2(yard.end.x, yard.position.y), yard.end, Vector2(yard.position.x, yard.end.y)]:
		points.append(Vector3(corner.x, 0.0, corner.y))
		points.append(Vector3(corner.x, 2.4, corner.y))
	for i in [0, StationView.BERTH_COUNT - 1]:
		points.append(_layout.berth_position(i) + Vector3(0.0, 2.4, 0.0))
	return points


func frame(target: Rect2) -> void:
	camera.frame(target)


func sync(engine: PuzzleEngine) -> void:
	_train.sync(engine)
	_station.sync(engine)
	_yard.refresh(engine)
	for lane in _zones.size():
		_zones[lane].visible = engine.opened[lane] and engine.has_lane(lane)


func set_visible_berths(count: int) -> void:
	_station.set_visible_berths(count)


func pick(screen_position: Vector2, engine: PuzzleEngine) -> int:
	return _yard.pick(camera, screen_position, engine)


func collector_position(collector_id: int) -> Vector3:
	return _yard.piece_position(collector_id)


func launch_collector(collector_id: int, slot_index: int, color_id: int) -> void:
	_station.mark_arriving(slot_index)
	_yard.launch(collector_id, color_id, _station.berth_position(slot_index), _station.arrived.bind(slot_index))


func reject_collector(collector_id: int, blockers: PackedInt32Array) -> void:
	_yard.nudge(collector_id)
	_yard.flash(blockers)


func play_match(event: MatchEvent) -> void:
	_station.play_match(_train.wagon_position(event.lane, event.distance), event.slot, event.color)
	_train.remove_wagon(event.wagon)


func play_win() -> void:
	var confetti := CPUParticles3D.new()
	confetti.name = "Confetti"
	confetti.amount = 160
	confetti.lifetime = 2.4
	confetti.one_shot = true
	confetti.explosiveness = 0.9
	confetti.direction = Vector3.UP
	confetti.spread = 60.0
	confetti.initial_velocity_min = 9.0
	confetti.initial_velocity_max = 15.0
	confetti.gravity = Vector3(0.0, -14.0, 0.0)
	confetti.scale_amount_min = 0.18
	confetti.scale_amount_max = 0.32
	var piece := BoxMesh.new()
	piece.size = Vector3(1.0, 0.15, 0.6)
	var paper := StandardMaterial3D.new()
	paper.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paper.vertex_color_use_as_albedo = true
	piece.material = paper
	confetti.mesh = piece
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	ramp.colors = PackedColorArray(Palette.WAGONS)
	confetti.color_initial_ramp = ramp
	confetti.position = Vector3(0.0, 1.0, WorldLayout.STATION_Z)
	add_child(confetti)
	confetti.emitting = true


func play_loss() -> void:
	camera.shake(0.45)


func _process(delta: float) -> void:
	_zone_pulse += delta
	var alpha := 0.38 + 0.22 * sin(_zone_pulse * 5.0)
	for zone in _zones:
		if zone.visible:
			(zone.material_override as StandardMaterial3D).albedo_color.a = alpha
