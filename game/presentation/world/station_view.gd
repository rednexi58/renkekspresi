class_name StationView
extends Node3D
## Station berths along the platform. Each berth shows the collector waiting there with
## its remaining capacity, receives the flying wagon effect on every match, and berths
## that are neither usable nor unlockable are hidden so no dead slot is drawn.

const TOKEN_SCALE := 0.95
const FLIGHT_SECONDS := 0.32
const BUMP_SECONDS := 0.16
const BERTH_COUNT := 5
const EMPTY_BERTH := Palette.BERTH_EMPTY

var _models: ModelLibrary
var _layout: WorldLayout
var _berths: Array[MeshInstance3D] = []
var _tokens: Array[Node3D] = []
var _counts: Array[Label3D] = []
var _token_colors := PackedInt32Array()
## Berths whose token is still in flight from the yard; revealed on arrival.
var _arriving := {}


func setup(models: ModelLibrary, layout: WorldLayout) -> void:
	_models = models
	_layout = layout
	for i in BERTH_COUNT:
		var berth := models.shape(self, "box", layout.berth_position(i) + Vector3.UP * 0.3, WorldLayout.BERTH_SIZE, EMPTY_BERTH, false)
		berth.name = "Berth %d" % i
		_berths.append(berth)
		_tokens.append(null)
		var count := WorldLabels.label("", 84, Palette.WHITE)
		count.position = layout.berth_position(i) + Vector3(0.0, 2.3, 0.4)
		add_child(count)
		_counts.append(count)
		_token_colors.append(-1)


func set_visible_berths(count: int) -> void:
	for i in BERTH_COUNT:
		_berths[i].visible = i < count


func berth_position(index: int) -> Vector3:
	return _layout.berth_position(index) + Vector3.UP * 0.42


func mark_arriving(slot_index: int) -> void:
	_arriving[slot_index] = true


func arrived(slot_index: int) -> void:
	_arriving.erase(slot_index)
	if _tokens[slot_index] != null:
		_tokens[slot_index].visible = true
		_bump(_tokens[slot_index])


func sync(engine: PuzzleEngine) -> void:
	for i in BERTH_COUNT:
		var occupied := i < engine.slots.size() and engine.slots[i].is_occupied()
		var color := engine.slots[i].color if occupied else -1
		if color != _token_colors[i]:
			_replace_token(i, color)
		var berth_color := Palette.wagon(color).lerp(Palette.WHITE, 0.35) if occupied else EMPTY_BERTH
		_berths[i].material_override = _models.material(berth_color, 0.7)
		var visible_token := occupied and not _arriving.has(i)
		if _tokens[i] != null:
			_tokens[i].visible = visible_token
		_counts[i].visible = visible_token
		if visible_token:
			_counts[i].text = str(engine.yard.at(engine.slots[i].collector).remaining)


func _replace_token(index: int, color: int) -> void:
	if _tokens[index] != null:
		_tokens[index].queue_free()
		_tokens[index] = null
	_token_colors[index] = color
	if color < 0:
		return
	var token := _models.make_wagon(color)
	token.scale = Vector3.ONE * TOKEN_SCALE
	token.position = berth_position(index)
	# Facing the rails: the collector waits nose-first toward the incoming train.
	token.basis = Basis.looking_at(Vector3.FORWARD, Vector3.UP).scaled(Vector3.ONE * TOKEN_SCALE)
	add_child(token)
	_tokens[index] = token


## A coloured ball flies from the collected wagon into the berth, which then bounces.
func play_match(from: Vector3, slot_index: int, color: int) -> void:
	var ball := _models.shape(self, "sphere", from, Vector3.ONE * 0.75, Palette.wagon(color), false)
	var target := berth_position(slot_index) + Vector3.UP * 0.8
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		ball.position = from.lerp(target, t) + Vector3.UP * sin(t * PI) * 3.0
		ball.scale = Vector3.ONE * lerpf(0.75, 0.35, t), 0.0, 1.0, FLIGHT_SECONDS).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(ball.queue_free)
	tween.tween_callback(func() -> void:
		if _tokens[slot_index] != null:
			_bump(_tokens[slot_index]))


func _bump(node: Node3D) -> void:
	var base := Vector3.ONE * TOKEN_SCALE
	var tween := create_tween()
	tween.tween_property(node, "scale", base * 1.18, BUMP_SECONDS * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", base, BUMP_SECONDS * 0.6)
