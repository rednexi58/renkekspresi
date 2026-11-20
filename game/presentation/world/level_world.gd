class_name LevelWorld
extends Node3D
## One level's view in two parts: the train scene in its own viewport at the top
## (SceneStage, with a following camera) and, below it, the station shelf and the
## collector board in this 3D world, framed by an orthographic camera. Cross-screen
## effects go through FxLayer. Owns no rules: everything shown is read from the
## PuzzleEngine passed to sync().

## Share of the play area the train map may take: it asks for what its shape needs to be
## shown full width, within these limits so the board always stays playable.
const SCENE_SHARE_MIN := 0.42
const SCENE_SHARE_MAX := 0.6
const BAND_OVERLAP := 6.0
## The shelf is drawn as wide as this share of the visible width, so its slots and the
## VIP / "+1" buttons are large enough to read and tap on every screen. The board fit
## alone would leave eight slots in a narrow strip, because the board is usually
## limited by height and the screen has spare width on both sides.
const SHELF_SCREEN_FILL := 0.94
## Upper bound, so the slots never dwarf the board's pieces on very wide screens.
const SHELF_SCALE_MAX := 2.2
## Framing passes: the shelf's scale changes the framed region a little, which changes
## the visible width; two passes settle it to well under a percent.
const SHELF_FIT_PASSES := 2

var camera: CameraRig
var current_level: LevelDefinition
var fx: FxLayer
var _models := ModelLibrary.new()
var _layout: WorldLayout
var _stage: SceneStage
var _shelf: ShelfView
var _board: BoardView
var _floor: MeshInstance3D
var _band: MeshInstance3D
var _vip_offer := false
var _ad_offer := false


func build(level: LevelDefinition, routes: Array[RailRoute], engine: PuzzleEngine, skin_id: String = "classic") -> void:
	current_level = level
	_layout = WorldLayout.new(level)
	var winter := Season.is_winter(level.id - 1)
	_add_environment(winter)
	_floor = _models.shape_with(self, "box", Vector3(0.0, -0.1, 0.0), Vector3(400.0, 0.2, 400.0), _models.ground(Palette.WINTER_BOARD if winter else Palette.BOARD), false)
	_floor.name = "Board floor"
	_band = _models.shape_with(self, "box", Vector3.ZERO, Vector3.ONE, _models.ground(Palette.WINTER_SHELF_BAND if winter else Palette.SHELF_BAND), false)
	_band.name = "Shelf band"
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
	var stage_layer := CanvasLayer.new()
	stage_layer.layer = 0
	add_child(stage_layer)
	_stage = SceneStage.new()
	_stage.name = "Scene stage"
	stage_layer.add_child(_stage)
	_stage.setup(_models, level, routes, engine, skin_id)
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 2
	add_child(fx_layer)
	fx = FxLayer.new()
	fx_layer.add_child(fx)
	sync(engine)


func _add_environment(winter: bool) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Palette.WINTER_BOARD if winter else Palette.BOARD
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
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


## Lays the scene and the board out inside `play_area` (viewport pixels).
func frame(play_area: Rect2) -> void:
	var screen_width := get_viewport().get_visible_rect().size.x
	var wanted := _stage.preferred_height(screen_width)
	var scene_height := roundf(clampf(wanted, play_area.size.y * SCENE_SHARE_MIN, play_area.size.y * SCENE_SHARE_MAX))
	_stage.place(Rect2(Vector2.ZERO, Vector2(screen_width, play_area.position.y + scene_height)), play_area.position.y)
	var board_target := Rect2(play_area.position + Vector2(0.0, scene_height), Vector2(play_area.size.x, play_area.size.y - scene_height))
	var shelf_scale := 1.0
	for i in SHELF_FIT_PASSES:
		camera.frame(_framing_region(shelf_scale), 1.1, board_target)
		# Orthographic camera keeping width: `size` is the visible world width.
		shelf_scale = clampf(camera.size * SHELF_SCREEN_FILL / _layout.shelf_width(), 1.0, SHELF_SCALE_MAX)
	camera.frame(_framing_region(shelf_scale), 1.1, board_target)
	_apply_shelf_scale(shelf_scale)


## Ground rectangle the camera must show: the board plus the shelf drawn at `shelf_scale`.
## The shelf's edge next to the board stays put and the shelf grows away from the board,
## so the gap to the first row of pieces never shrinks.
func _framing_region(shelf_scale: float) -> Rect2:
	var board := _layout.board_rect()
	var shelf_top := _shelf_board_edge() - (WorldLayout.SHELF_DEPTH + 0.15) * shelf_scale
	var half_width := maxf(board.size.x, _layout.shelf_width()) * 0.5 + 0.2
	return Rect2(Vector2(-half_width, shelf_top), Vector2(half_width * 2.0, board.end.y + 0.3 - shelf_top))


## Ground Z of the shelf edge facing the board.
func _shelf_board_edge() -> float:
	return _layout.shelf_centre_z() + WorldLayout.SHELF_DEPTH * 0.5


## Scales the shelf about its board-side edge (picking and flights already go through
## the shelf's local transform) and fits the background band under it.
func _apply_shelf_scale(shelf_scale: float) -> void:
	var edge := _shelf_board_edge()
	_shelf.scale = Vector3.ONE * shelf_scale
	_shelf.position = Vector3(0.0, 0.0, edge * (1.0 - shelf_scale))
	var shelf_depth := WorldLayout.SHELF_DEPTH * shelf_scale
	var band_depth := shelf_depth + 0.9
	_band.scale = Vector3(400.0, 0.2, band_depth + BAND_OVERLAP)
	_band.position = Vector3(0.0, -0.05, edge - shelf_depth * 0.5 - BAND_OVERLAP * 0.5 + 0.1)


## Centre of the shelf on the ground, as drawn.
func _shelf_centre() -> Vector3:
	return _shelf.to_global(Vector3(0.0, 0.0, _layout.shelf_centre_z()))


## Which unlock offers the shelf may show (from CommerceService availability).
func set_offers(vip_offer: bool, ad_offer: bool) -> void:
	_vip_offer = vip_offer
	_ad_offer = ad_offer


func sync(engine: PuzzleEngine) -> void:
	_stage.sync(engine)
	_shelf.sync(engine, _vip_offer, _ad_offer)
	_board.refresh(engine)
	fx.set_danger(engine.danger() if engine.is_playing() else 0.0)


func pick(screen_position: Vector2, engine: PuzzleEngine) -> int:
	return _board.pick(camera, screen_position, engine)


## Shelf position under a screen point as [index, ShelfView.Look].
func pick_shelf(screen_position: Vector2) -> Array:
	return _shelf.pick(camera, screen_position)


func collector_position(collector_id: int) -> Vector3:
	return _board.piece_position(collector_id)


func collector_screen_position(collector_id: int) -> Vector2:
	return camera.unproject_position(_board.piece_position(collector_id) + Vector3.UP * WorldLayout.PICK_HEIGHT)


func launch_collector(collector_id: int, slot_index: int, color_id: int) -> void:
	_shelf.mark_arriving(slot_index)
	_board.launch(collector_id, color_id, _shelf.slot_position(slot_index), _shelf.arrived.bind(slot_index))


func reject_collector(collector_id: int, blockers: PackedInt32Array) -> void:
	_board.nudge(collector_id)
	_board.flash(blockers)


## Wagon pops in the scene; a parcel of its colour flies to the collector's slot.
func play_match(event: MatchEvent) -> void:
	var from := _stage.wagon_screen_position(event.lane, event.distance)
	var to := camera.unproject_position(_shelf.slot_position(event.slot) + Vector3.UP * 0.5)
	_stage.remove_wagon(event.wagon)
	fx.fly_parcel(from, to, Palette.wagon(event.color), _shelf.bump.bind(event.slot))


func scene_rect() -> Rect2:
	return Rect2(_stage.position, _stage.size)


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
	confetti.position = _shelf_centre() + Vector3.UP
	add_child(confetti)
	confetti.emitting = true


func play_loss() -> void:
	camera.shake(0.45)
	_stage.shake(0.5)
