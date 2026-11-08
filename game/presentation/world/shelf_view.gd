class_name ShelfView
extends Node3D
## The station shelf between the scene and the board: a wooden plank with recessed
## slots. A collector sent from the board waits in its slot, lying across the shelf, with
## its remaining capacity printed underneath; every match flies a parcel of the wagon's
## colour into it. Slots beyond the usable count are hidden so no dead slot is drawn.

const FLIGHT_SECONDS := 0.34
const BUMP_SECONDS := 0.16
const SLOT_SIZE := Vector3(1.65, 0.12, 1.15)

var _models: ModelLibrary
var _layout: WorldLayout
var _slots: Array[Node3D] = []
var _tokens: Array[Node3D] = []
var _counts: Array[Label3D] = []
var _token_colors := PackedInt32Array()
## Slots whose token is still in flight from the board; revealed on arrival.
var _arriving := {}


func setup(models: ModelLibrary, layout: WorldLayout) -> void:
	_models = models
	_layout = layout
	var centre := Vector3(0.0, 0.0, layout.shelf_centre_z())
	var width := layout.shelf_width()
	models.contact_shadow(self, centre + Vector3(0.0, 0.01, 0.25), Vector2(width + 1.4, WorldLayout.SHELF_DEPTH + 1.2), 0.3)
	models.shape_with(self, "rounded_box", centre + Vector3(0.0, 0.14, 0.06), Vector3(width + 0.1, 0.3, WorldLayout.SHELF_DEPTH + 0.12), models.painted(Palette.SHELF_EDGE, 0.7), false)
	models.shape_with(self, "rounded_box", centre + Vector3(0.0, 0.22, 0.0), Vector3(width, 0.3, WorldLayout.SHELF_DEPTH), models.painted(Palette.SHELF, 0.7), false)
	for i in WorldLayout.SLOT_COUNT:
		var slot := Node3D.new()
		slot.position = layout.slot_position(i)
		add_child(slot)
		models.shape(slot, "rounded_box", Vector3(0.0, 0.33, 0.0), SLOT_SIZE, Palette.SHELF_SLOT, false)
		_slots.append(slot)
		_tokens.append(null)
		var count := WorldLabels.painted_text("", 120, Palette.INK)
		count.position = layout.slot_position(i) + Vector3(0.0, 0.4, 0.86)
		add_child(count)
		_counts.append(count)
		_token_colors.append(-1)


func set_visible_slots(count: int) -> void:
	for i in WorldLayout.SLOT_COUNT:
		_slots[i].visible = i < count


func slot_position(index: int) -> Vector3:
	return to_global(_layout.slot_position(index) + Vector3.UP * 0.4)


func mark_arriving(slot_index: int) -> void:
	_arriving[slot_index] = true


func arrived(slot_index: int) -> void:
	_arriving.erase(slot_index)
	if _tokens[slot_index] != null:
		_tokens[slot_index].visible = true
		_bump(_tokens[slot_index])


func sync(engine: PuzzleEngine) -> void:
	for i in WorldLayout.SLOT_COUNT:
		var occupied := i < engine.slots.size() and engine.slots[i].is_occupied()
		var color := engine.slots[i].color if occupied else -1
		if color != _token_colors[i]:
			_replace_token(i, color)
		var shown := occupied and not _arriving.has(i)
		if _tokens[i] != null:
			_tokens[i].visible = shown
		_counts[i].text = str(engine.yard.at(engine.slots[i].collector).remaining) if shown else ""


func _replace_token(index: int, color: int) -> void:
	if _tokens[index] != null:
		_tokens[index].queue_free()
		_tokens[index] = null
	_token_colors[index] = color
	if color < 0:
		return
	var token := Node3D.new()
	token.position = _layout.slot_position(index) + Vector3.UP * 0.4
	add_child(token)
	var wagon := _models.make_wagon(color)
	wagon.basis = Basis.looking_at(Vector3.LEFT, Vector3.UP).scaled(Vector3.ONE * WorldLayout.TOKEN_SCALE)
	token.add_child(wagon)
	_tokens[index] = token


## A parcel of the wagon's colour flies into the slot, which then bounces.
func play_match(from: Vector3, slot_index: int, color: int) -> void:
	var parcel := _models.shape_with(get_parent(), "rounded_box", from, Vector3.ONE * 0.5, _models.painted(Palette.wagon(color)), false)
	var target := slot_position(slot_index) + Vector3.UP * 0.8
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		parcel.global_position = from.lerp(target, t) + Vector3.UP * sin(t * PI) * 2.0
		parcel.rotation = Vector3(t * 3.0, t * 5.0, 0.0)
		parcel.scale = Vector3.ONE * lerpf(0.55, 0.3, t), 0.0, 1.0, FLIGHT_SECONDS).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(parcel.queue_free)
	tween.tween_callback(func() -> void:
		if _tokens[slot_index] != null:
			_bump(_tokens[slot_index]))


func _bump(node: Node3D) -> void:
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector3(1.12, 1.12, 1.12), BUMP_SECONDS * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector3.ONE, BUMP_SECONDS * 0.6)
