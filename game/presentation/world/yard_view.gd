class_name YardView
extends Node3D
## The collector yard: one toy wagon per collector, turned to face its exit arrow, with
## a bold arrow on top, its capacity number and any key/lock badge. Handles picking and
## all yard feedback (blocked shake, blocker highlight, launch to the station).

const ARROW_HEIGHT := 1.98
const BADGE_HEIGHT := 2.6
const LAUNCH_SECONDS := 0.3
const NUDGE_SECONDS := 0.28
const FLASH_SECONDS := 0.7
const LOCK_COLOR := Color("8c97b3")

var _models: ModelLibrary
var _layout: WorldLayout
var _pieces := {}
var _arrow_mesh: ArrayMesh
var _outline_mesh: ArrayMesh


class Piece:
	var root: Node3D
	var body: Node3D
	var arrow: MeshInstance3D
	var count: Label3D
	var badge: Label3D
	var home: Vector3


func setup(models: ModelLibrary, layout: WorldLayout, engine: PuzzleEngine) -> void:
	_models = models
	_layout = layout
	_arrow_mesh = WorldLabels.arrow_mesh(1.5, 1.1)
	_outline_mesh = WorldLabels.arrow_mesh(1.85, 1.45)
	for collector in engine.yard.collectors:
		_pieces[collector.definition.id] = _build_piece(collector.definition)
	refresh(engine)


func _build_piece(definition: CollectorDefinition) -> Piece:
	var piece := Piece.new()
	piece.home = _layout.cell_position(definition.row, definition.col)
	piece.root = Node3D.new()
	piece.root.name = "Collector %d" % definition.id
	piece.root.position = piece.home
	add_child(piece.root)
	var tile := _models.shape(piece.root, "box", Vector3(0.0, 0.22, 0.0), Vector3(WorldLayout.CELL_X - 0.35, 0.06, WorldLayout.CELL_Z - 0.3), Palette.BOARD_CELL, false)
	tile.name = "Tile"
	var facing := WorldLayout.arrow_direction(definition)
	piece.body = Node3D.new()
	piece.body.basis = Basis.looking_at(facing, Vector3.UP)
	piece.root.add_child(piece.body)
	var wagon := _models.make_wagon(definition.color)
	wagon.scale = Vector3.ONE * WorldLayout.COLLECTOR_SCALE
	wagon.position.y = 0.25
	piece.body.add_child(wagon)
	var outline := MeshInstance3D.new()
	outline.mesh = _outline_mesh
	outline.material_override = _models.flat_material(Palette.INK)
	outline.position = Vector3(0.0, ARROW_HEIGHT - 0.01, 0.0)
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece.body.add_child(outline)
	piece.arrow = MeshInstance3D.new()
	piece.arrow.mesh = _arrow_mesh
	piece.arrow.material_override = _models.flat_material(Palette.WHITE)
	piece.arrow.position = Vector3(0.0, ARROW_HEIGHT, 0.0)
	piece.arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece.body.add_child(piece.arrow)
	piece.count = WorldLabels.label(str(definition.capacity), 96, Palette.WHITE)
	piece.count.position = Vector3(1.35, BADGE_HEIGHT - 0.35, 0.75)
	piece.root.add_child(piece.count)
	piece.badge = WorldLabels.label("", 64, Palette.GOLD)
	piece.badge.position = Vector3(-1.35, BADGE_HEIGHT - 0.35, 0.75)
	piece.root.add_child(piece.badge)
	return piece


## Mirrors collector state: only parked collectors are shown; lock/key badges update.
func refresh(engine: PuzzleEngine) -> void:
	for collector in engine.yard.collectors:
		var definition := collector.definition
		var piece: Piece = _pieces[definition.id]
		piece.root.visible = collector.is_parked()
		if not piece.root.visible:
			continue
		piece.count.text = str(collector.remaining)
		if engine.yard.is_locked(definition.id):
			piece.badge.text = "[%s]" % engine.yard.at(definition.requires).definition.key
			piece.badge.modulate = LOCK_COLOR
		elif not definition.key.is_empty():
			piece.badge.text = "+" + definition.key
			piece.badge.modulate = Palette.GOLD
		else:
			piece.badge.text = ""


## Collector under a screen position, or -1. Picks on one plane at roof height so a tall
## piece can never steal a tap meant for the row behind it.
func pick(camera: Camera3D, screen_position: Vector2, engine: PuzzleEngine) -> int:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var hit: Variant = Plane(Vector3.UP, WorldLayout.PICK_HEIGHT).intersects_ray(origin, direction)
	if hit == null:
		return -1
	var cell := _layout.cell_at(hit)
	if cell.x < 0:
		return -1
	for collector in engine.yard.collectors:
		var definition := collector.definition
		if collector.is_parked() and definition.row == cell.x and definition.col == cell.y:
			return definition.id
	return -1


func piece_position(collector_id: int) -> Vector3:
	return (_pieces[collector_id] as Piece).root.position


## Short sideways shake for a rejected tap.
func nudge(collector_id: int) -> void:
	if not _pieces.has(collector_id):
		return
	var piece: Piece = _pieces[collector_id]
	var tween := create_tween()
	for i in 4:
		var offset := 0.18 if i % 2 == 0 else -0.18
		tween.tween_property(piece.root, "position", piece.home + Vector3(offset, 0.0, 0.0), NUDGE_SECONDS / 5.0)
	tween.tween_property(piece.root, "position", piece.home, NUDGE_SECONDS / 5.0)


## Turns the arrows of the given collectors red for a moment ("this one is in the way").
func flash(collector_ids: PackedInt32Array) -> void:
	for id in collector_ids:
		if not _pieces.has(id):
			continue
		var piece: Piece = _pieces[id]
		piece.arrow.material_override = _models.flat_material(Palette.DANGER)
		var tween := create_tween()
		tween.tween_interval(FLASH_SECONDS)
		tween.tween_callback(func() -> void: piece.arrow.material_override = _models.flat_material(Palette.WHITE))


## Flies a copy of the collector from its cell to a station berth along an arc, then
## calls `arrived`. The real piece is hidden at once by refresh(); the copy is cosmetic.
func launch(collector_id: int, color_id: int, target: Vector3, arrived: Callable) -> void:
	var start := piece_position(collector_id)
	var ghost := _models.make_wagon(color_id)
	ghost.scale = Vector3.ONE * WorldLayout.COLLECTOR_SCALE
	add_child(ghost)
	ghost.position = start
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		var eased := t * t * (3.0 - 2.0 * t)
		ghost.position = start.lerp(target, eased) + Vector3.UP * sin(t * PI) * 2.4
		ghost.rotation.y = lerpf(0.0, PI * 2.0, eased), 0.0, 1.0, LAUNCH_SECONDS)
	tween.tween_callback(ghost.queue_free)
	tween.tween_callback(arrived)
