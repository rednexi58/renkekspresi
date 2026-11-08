class_name YardView
extends Node3D
## The marshalling yard: one boxcar per collector, standing on its own short track that
## runs along its exit arrow. The arrow is painted on the roof and the remaining
## capacity is on a round roof plate, the way Wool Crush prints arrows on its pieces.
## Handles picking and all yard feedback (blocked shake, blocker highlight, launch).

const LAUNCH_SECONDS := 0.32
const NUDGE_SECONDS := 0.28
const FLASH_SECONDS := 0.7
const ARROW_LENGTH := 0.86
const ARROW_WIDTH := 0.52
const ARROW_OFFSET := -0.26
const PLATE_OFFSET := 0.5
const LOCK_COLOR := Color("8c97b3")
## Height of the yard rail tops, where the wheels stand.
const WAGON_LIFT := 0.3

var _models: ModelLibrary
var _layout: WorldLayout
var _tracks: TrackBuilder
var _pieces := {}


class Piece:
	var root: Node3D
	var body: Node3D
	var arrow: MeshInstance3D
	var count: Label3D
	var badge: Label3D
	var home: Vector3


func setup(models: ModelLibrary, layout: WorldLayout, tracks: TrackBuilder, engine: PuzzleEngine) -> void:
	_models = models
	_layout = layout
	_tracks = tracks
	var occupied := {}
	for collector in engine.yard.collectors:
		var definition := collector.definition
		var cell := layout.cell_position(definition.row, definition.col)
		var facing := WorldLayout.arrow_direction(definition)
		tracks.build_stub(self, cell + Vector3.UP * 0.16, facing, _track_length(facing))
		_pieces[definition.id] = _build_piece(definition, cell, facing)
		occupied[Vector2i(definition.row, definition.col)] = true
	# Empty cells still get a yard track, so the board reads as a real marshalling yard.
	for row in layout.rows:
		for col in layout.cols:
			if not occupied.has(Vector2i(row, col)):
				tracks.build_stub(self, layout.cell_position(row, col) + Vector3.UP * 0.16, Vector3.FORWARD, _track_length(Vector3.FORWARD))
	refresh(engine)


static func _track_length(facing: Vector3) -> float:
	if absf(facing.x) > 0.01 and absf(facing.z) > 0.01:
		return 3.3
	return WorldLayout.CELL_Z - 0.25 if absf(facing.z) > absf(facing.x) else WorldLayout.CELL_X - 0.35


func _build_piece(definition: CollectorDefinition, cell: Vector3, facing: Vector3) -> Piece:
	var piece := Piece.new()
	piece.home = cell
	piece.root = Node3D.new()
	piece.root.name = "Collector %d" % definition.id
	piece.root.position = cell
	add_child(piece.root)
	var size := WorldLayout.COLLECTOR_SCALE
	piece.body = Node3D.new()
	piece.body.basis = Basis.looking_at(facing, Vector3.UP)
	piece.root.add_child(piece.body)
	var wagon := _models.make_wagon(definition.color)
	wagon.scale = Vector3.ONE * size
	wagon.position.y = WAGON_LIFT
	piece.body.add_child(wagon)
	_models.contact_shadow(piece.body, Vector3(0.0, 0.24, 0.0), Vector2(RollingStock.WIDTH * size * 1.5, RollingStock.LENGTH * size * 1.15), 0.45)
	var roof := WAGON_LIFT + RollingStock.roof_top() * size + 0.012
	var outline := MeshInstance3D.new()
	outline.mesh = WorldLabels.arrow_mesh(ARROW_LENGTH * size + 0.12, ARROW_WIDTH * size + 0.14)
	outline.material_override = _models.flat_material(Palette.INK)
	outline.position = Vector3(0.0, roof, ARROW_OFFSET * size)
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece.body.add_child(outline)
	piece.arrow = MeshInstance3D.new()
	piece.arrow.mesh = WorldLabels.arrow_mesh(ARROW_LENGTH * size, ARROW_WIDTH * size)
	piece.arrow.material_override = _models.flat_material(Palette.WHITE)
	piece.arrow.position = Vector3(0.0, roof + 0.004, ARROW_OFFSET * size)
	piece.arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece.body.add_child(piece.arrow)
	# The plate sits on the rear half of the roof but is parented to the unrotated root
	# so its number always reads upright.
	var plate_at := facing * -PLATE_OFFSET * size + Vector3.UP * roof
	piece.count = WorldLabels.capacity_plate(piece.root, _models, plate_at, str(definition.capacity))
	piece.badge = WorldLabels.label("", 56, Palette.GOLD)
	piece.badge.position = plate_at + Vector3(0.0, 0.7, 0.0)
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


## Collector under a screen position, or -1. Picks on one plane at roof height so a
## tall piece can never steal a tap meant for the row behind it.
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
		var offset := 0.14 if i % 2 == 0 else -0.14
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


## Rolls a copy of the collector out of the yard and into its station siding along an
## arc, then calls `arrived`. The real piece is hidden at once by refresh().
func launch(collector_id: int, color_id: int, target: Vector3, arrived: Callable) -> void:
	var piece: Piece = _pieces[collector_id]
	var start := piece.root.position + Vector3.UP * WAGON_LIFT
	var start_basis := piece.body.basis
	var end_basis := Basis.looking_at(Vector3.FORWARD, Vector3.UP)
	var ghost := Node3D.new()
	add_child(ghost)
	var wagon := _models.make_wagon(color_id)
	ghost.add_child(wagon)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		var eased := t * t * (3.0 - 2.0 * t)
		var factor := lerpf(WorldLayout.COLLECTOR_SCALE, WorldLayout.TOKEN_SCALE, eased)
		ghost.transform = Transform3D(start_basis.slerp(end_basis, eased).scaled(Vector3.ONE * factor), start.lerp(target, eased) + Vector3.UP * sin(t * PI) * 1.6), 0.0, 1.0, LAUNCH_SECONDS)
	tween.tween_callback(ghost.queue_free)
	tween.tween_callback(arrived)
