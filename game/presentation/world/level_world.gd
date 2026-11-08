class_name LevelWorld
extends Node3D
## Composes one level's 3D view in three bands, top to bottom: the train scene, the
## station shelf and the collector board, framed by one orthographic camera. Owns no
## rules: everything shown is read from the PuzzleEngine passed to sync().

const SCENE_SHARE := 0.36
const BAND_GAP := 24.0

var camera: CameraRig
var current_level: LevelDefinition
var _models := ModelLibrary.new()
var _layout: WorldLayout
var _scene: SceneView
var _train: TrainView
var _shelf: ShelfView
var _board: BoardView
var _zones: Array[MeshInstance3D] = []
var _grass: MeshInstance3D
var _floor: MeshInstance3D
var _band: MeshInstance3D
var _band_shadow: MeshInstance3D
var _zone_pulse := 0.0
var _vip_offer := false
var _ad_offer := false


func build(level: LevelDefinition, routes: Array[RailRoute], engine: PuzzleEngine, skin_id: String = "classic") -> void:
	current_level = level
	_layout = WorldLayout.new(level)
	_add_environment()
	_grass = _models.shape_with(self, "box", Vector3(0.0, -0.55, 0.0), Vector3(400.0, 1.0, 400.0), _models.ground(Palette.scene_ground(level.theme)), false)
	_grass.name = "Grass"
	_floor = _models.shape_with(self, "box", Vector3.ZERO, Vector3.ONE, _models.ground(Palette.BOARD), false)
	_floor.name = "Board floor"
	# A wooden band spanning the full width separates the scene from the board, as the
	# shelf does in the reference games; the shelf plank sits on top of it.
	_band = _models.shape_with(self, "box", Vector3.ZERO, Vector3.ONE, _models.ground(Palette.SHELF_BAND), false)
	_band.name = "Shelf band"
	_band_shadow = _models.contact_shadow(self, Vector3.ZERO, Vector2.ONE, 0.22)
	_scene = SceneView.new()
	_scene.name = "Scene"
	add_child(_scene)
	_scene.setup(_models, level, routes, engine)
	_zones = _scene.loading_zones()
	_train = TrainView.new()
	_train.name = "Train"
	_scene.add_child(_train)
	_train.setup(_models, routes, engine, skin_id)
	_shelf = ShelfView.new()
	_shelf.name = "Shelf"
	add_child(_shelf)
	_shelf.setup(_models, _layout)
	_board = BoardView.new()
	_board.name = "Board"
	add_child(_board)
	_board.setup(_models, _layout, engine)
	camera = CameraRig.new()
	camera.name = "Camera"
	add_child(camera)
	camera.make_current()
	sync(engine)


func _add_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Palette.BOARD
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Calibrated so a lit upward face renders at almost exactly its palette colour
	# (ambient + sun * cos(sun angle) ~= 1.0): colours stay true and saturated, while
	# side faces fall into soft shade that gives the pieces volume.
	environment.ambient_light_color = Color("fff8f0")
	environment.ambient_light_energy = 0.4
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("fff3e0")
	sun.light_energy = 0.58
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.42
	sun.shadow_blur = 2.5
	sun.directional_shadow_max_distance = 120.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.rotation_degrees = Vector3(-62.0, 28.0, 0.0)
	add_child(sun)


## Lays the three bands out inside `play_area` (viewport pixels).
func frame(play_area: Rect2) -> void:
	var scene_height := play_area.size.y * SCENE_SHARE
	var scene_target := Rect2(play_area.position, Vector2(play_area.size.x, scene_height - BAND_GAP))
	var board_target := Rect2(play_area.position + Vector2(0.0, scene_height), Vector2(play_area.size.x, play_area.size.y - scene_height))
	var board := _layout.board_rect()
	var shelf_top := _layout.shelf_centre_z() - WorldLayout.SHELF_DEPTH * 0.5 - 0.2
	var half_width := maxf(board.size.x, _layout.shelf_width()) * 0.5 + 0.3
	var region := Rect2(Vector2(-half_width, shelf_top), Vector2(half_width * 2.0, board.end.y + 0.4 - shelf_top))
	var scene_transform := camera.frame(region, 1.2, board_target, _scene.bounds(), 1.4, scene_target)
	_scene.transform = scene_transform
	# The cream board floor starts just above the shelf; grass shows above it.
	var floor_top := shelf_top - 0.6
	_floor.scale = Vector3(400.0, 0.2, 200.0)
	_floor.position = Vector3(0.0, -0.1, floor_top + 100.0)
	var band_depth := WorldLayout.SHELF_DEPTH + 1.3
	_band.scale = Vector3(400.0, 0.2, band_depth)
	_band.position = Vector3(0.0, -0.05, _layout.shelf_centre_z())
	_band_shadow.scale = Vector3(400.0, 1.0, 1.6)
	_band_shadow.position = Vector3(0.0, 0.06, _layout.shelf_centre_z() + band_depth * 0.5 + 0.3)
	_scene.clip_decoration(_layout.shelf_centre_z() - band_depth * 0.5)


## Which unlock offers the shelf may show (from CommerceService availability).
func set_offers(vip_offer: bool, ad_offer: bool) -> void:
	_vip_offer = vip_offer
	_ad_offer = ad_offer


func sync(engine: PuzzleEngine) -> void:
	_train.sync(engine)
	_shelf.sync(engine, _vip_offer, _ad_offer)
	_board.refresh(engine)
	for lane in _zones.size():
		_zones[lane].visible = engine.opened[lane] and engine.has_lane(lane)


func pick(screen_position: Vector2, engine: PuzzleEngine) -> int:
	return _board.pick(camera, screen_position, engine)


## Shelf position under a screen point as [index, ShelfView.Look].
func pick_shelf(screen_position: Vector2) -> Array:
	return _shelf.pick(camera, screen_position)


func collector_position(collector_id: int) -> Vector3:
	return _board.piece_position(collector_id)


func launch_collector(collector_id: int, slot_index: int, color_id: int) -> void:
	_shelf.mark_arriving(slot_index)
	_board.launch(collector_id, color_id, _shelf.slot_position(slot_index), _shelf.arrived.bind(slot_index))


func reject_collector(collector_id: int, blockers: PackedInt32Array) -> void:
	_board.nudge(collector_id)
	_board.flash(blockers)


func play_match(event: MatchEvent) -> void:
	_shelf.play_match(_train.wagon_position(event.lane, event.distance), event.slot, event.color)
	_train.remove_wagon(event.wagon)


func play_win() -> void:
	var confetti := CPUParticles3D.new()
	confetti.name = "Confetti"
	confetti.amount = 180
	confetti.lifetime = 2.4
	confetti.one_shot = true
	confetti.explosiveness = 0.9
	confetti.direction = Vector3.UP
	confetti.spread = 70.0
	confetti.initial_velocity_min = 8.0
	confetti.initial_velocity_max = 14.0
	confetti.gravity = Vector3(0.0, -12.0, 0.0)
	confetti.scale_amount_min = 0.16
	confetti.scale_amount_max = 0.3
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
	confetti.position = Vector3(0.0, 1.0, _layout.shelf_centre_z())
	add_child(confetti)
	confetti.emitting = true


func play_loss() -> void:
	camera.shake(0.45)


func _process(delta: float) -> void:
	_zone_pulse += delta
	var alpha := 0.35 + 0.25 * sin(_zone_pulse * 5.0)
	for zone in _zones:
		if zone.visible:
			(zone.material_override as StandardMaterial3D).albedo_color.a = alpha
