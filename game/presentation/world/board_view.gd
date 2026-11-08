class_name BoardView
extends Node3D
## The collector board: chunky wagon pieces on a calm cream surface, each turned toward
## its exit arrow. The arrow is printed on the roof (white with a soft shadow) and the
## remaining capacity sits on a round plate at the tail. Handles picking and board
## feedback: blocked shake, blocker highlight and the hop to the station shelf.

const LAUNCH_SECONDS := 0.34
const NUDGE_SECONDS := 0.26
const FLASH_SECONDS := 0.7
const ARROW_LENGTH := 1.25
const ARROW_WIDTH := 0.72
const ARROW_OFFSET := -0.22
const PLATE_OFFSET := 0.66
const LOCK_COLOR := Color("8f7f70")
const ARROW_SHADOW := Color(0.24, 0.14, 0.05, 0.28)

var _models: ModelLibrary
var _layout: WorldLayout
var _pieces := {}


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
	for collector in engine.yard.collectors:
		var definition := collector.definition
		_pieces[definition.id] = _build_piece(definition)
	refresh(engine)


func _build_piece(definition: CollectorDefinition) -> Piece:
	var piece := Piece.new()
	var facing := WorldLayout.arrow_direction(definition)
	var size := WorldLayout.PIECE_SCALE
	piece.home = _layout.cell_position(definition.row, definition.col)
	piece.root = Node3D.new()
	piece.root.name = "Collector %d" % definition.id
	piece.root.position = piece.home
	add_child(piece.root)
	piece.body = Node3D.new()
	piece.body.basis = Basis.looking_at(facing, Vector3.UP)
	piece.root.add_child(piece.body)
	var wagon := _models.make_wagon(definition.color)
	wagon.scale = Vector3.ONE * size
	piece.body.add_child(wagon)
	_models.contact_shadow(piece.body, Vector3(0.0, 0.01, 0.0), Vector2(WagonModels.WIDTH * size * 1.55, WagonModels.LENGTH * size * 1.2), 0.42)
	var roof := WagonModels.roof_top() * size + 0.01
	var shadow := MeshInstance3D.new()
	shadow.mesh = WorldLabels.arrow_mesh(ARROW_LENGTH, ARROW_WIDTH)
	shadow.material_override = _models.flat_material(ARROW_SHADOW, true)
	shadow.position = Vector3(0.04, roof, ARROW_OFFSET + 0.06)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece.body.add_child(shadow)
	piece.arrow = MeshInstance3D.new()
	piece.arrow.mesh = WorldLabels.arrow_mesh(ARROW_LENGTH, ARROW_WIDTH)
	piece.arrow.material_override = _models.flat_material(Palette.WHITE)
	piece.arrow.position = Vector3(0.0, roof + 0.006, ARROW_OFFSET)
	piece.arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece.body.add_child(piece.arrow)
	# The plate is parented to the unrotated root so its number always reads upright.
	var plate_at := facing * -PLATE_OFFSET + Vector3.UP * roof
	piece.count = WorldLabels.capacity_plate(piece.root, _models, plate_at, str(definition.capacity))
	piece.badge = WorldLabels.label("", 52, Palette.GOLD, Palette.INK)
	piece.badge.position = plate_at + Vector3(0.0, 0.55, -0.2)
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


## Collector under a screen position, or -1. Picks on one plane at roof height so the
## result matches what the player sees on top of the pieces.
func pick(camera: Camera3D, screen_position: Vector2, engine: PuzzleEngine) -> int:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var hit: Variant = Plane(Vector3.UP, WorldLayout.PICK_HEIGHT).intersects_ray(origin, direction)
	if hit == null:
		return -1
	var local: Vector3 = to_local(hit)
	var cell := _layout.cell_at(local)
	if cell.x < 0:
		return -1
	for collector in engine.yard.collectors:
		var definition := collector.definition
		if collector.is_parked() and definition.row == cell.x and definition.col == cell.y:
			return definition.id
	return -1


func piece_position(collector_id: int) -> Vector3:
	return to_global((_pieces[collector_id] as Piece).root.position)


func nudge(collector_id: int) -> void:
	if not _pieces.has(collector_id):
		return
	var piece: Piece = _pieces[collector_id]
	var tween := create_tween()
	for i in 4:
		var offset := 0.12 if i % 2 == 0 else -0.12
		tween.tween_property(piece.root, "position", piece.home + Vector3(offset, 0.0, 0.0), NUDGE_SECONDS / 5.0)
	tween.tween_property(piece.root, "position", piece.home, NUDGE_SECONDS / 5.0)


func flash(collector_ids: PackedInt32Array) -> void:
	for id in collector_ids:
		if not _pieces.has(id):
			continue
		var piece: Piece = _pieces[id]
		piece.arrow.material_override = _models.flat_material(Palette.DANGER)
		var tween := create_tween()
		tween.tween_interval(FLASH_SECONDS)
		tween.tween_callback(func() -> void: piece.arrow.material_override = _models.flat_material(Palette.WHITE))


## Hops a copy of the piece onto its shelf slot along an arc, turning it to lie across
## the shelf, then calls `arrived`. The real piece is hidden at once by refresh().
func launch(collector_id: int, color_id: int, target: Vector3, arrived: Callable) -> void:
	var piece: Piece = _pieces[collector_id]
	var start := to_global(piece.root.position)
	var start_basis := piece.body.global_basis.orthonormalized()
	var end_basis := Basis.IDENTITY
	var ghost := _models.make_wagon(color_id)
	get_parent().add_child(ghost)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		var eased := t * t * (3.0 - 2.0 * t)
		var factor := lerpf(WorldLayout.PIECE_SCALE, WorldLayout.TOKEN_SCALE, eased)
		ghost.global_transform = Transform3D(start_basis.slerp(end_basis, eased).scaled(Vector3.ONE * factor), start.lerp(target, eased) + Vector3.UP * sin(t * PI) * 2.2), 0.0, 1.0, LAUNCH_SECONDS)
	tween.tween_callback(ghost.queue_free)
	tween.tween_callback(arrived)
