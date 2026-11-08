class_name StationView
extends Node3D
## Station sidings beside the platform. A collector sent from the yard waits on its
## siding with its remaining capacity on a roof plate; every match flies a parcel of the
## wagon's colour into it. Sidings that are neither usable nor unlockable are hidden so
## no dead slot is drawn.

const FLIGHT_SECONDS := 0.32
const BUMP_SECONDS := 0.16
const BERTH_COUNT := 5
const SIDING_LENGTH := 2.6

var _models: ModelLibrary
var _layout: WorldLayout
var _sidings: Array[Node3D] = []
var _tokens: Array[Node3D] = []
var _counts: Array[Label3D] = []
var _token_colors := PackedInt32Array()
## Sidings whose token is still in flight from the yard; revealed on arrival.
var _arriving := {}


func setup(models: ModelLibrary, layout: WorldLayout, tracks: TrackBuilder) -> void:
	_models = models
	_layout = layout
	for i in BERTH_COUNT:
		_sidings.append(tracks.build_stub(self, layout.berth_position(i) + Vector3.UP * 0.12, Vector3.FORWARD, SIDING_LENGTH, true))
		_tokens.append(null)
		_counts.append(null)
		_token_colors.append(-1)


func set_visible_berths(count: int) -> void:
	for i in BERTH_COUNT:
		_sidings[i].visible = i < count


func berth_position(index: int) -> Vector3:
	return _layout.berth_position(index) + Vector3.UP * 0.26


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
		if _tokens[i] != null:
			_tokens[i].visible = occupied and not _arriving.has(i)
			if occupied:
				_counts[i].text = str(engine.yard.at(engine.slots[i].collector).remaining)


func _replace_token(index: int, color: int) -> void:
	if _tokens[index] != null:
		_tokens[index].queue_free()
		_tokens[index] = null
		_counts[index] = null
	_token_colors[index] = color
	if color < 0:
		return
	var token := Node3D.new()
	token.position = berth_position(index)
	add_child(token)
	var wagon := _models.make_wagon(color)
	wagon.scale = Vector3.ONE * WorldLayout.TOKEN_SCALE
	token.add_child(wagon)
	_models.contact_shadow(token, Vector3(0.0, 0.03, 0.0), Vector2(RollingStock.WIDTH * WorldLayout.TOKEN_SCALE * 1.5, RollingStock.LENGTH * WorldLayout.TOKEN_SCALE * 1.15), 0.45)
	var roof := RollingStock.roof_top() * WorldLayout.TOKEN_SCALE + 0.012
	_counts[index] = WorldLabels.capacity_plate(token, _models, Vector3(0.0, roof, 0.0), "")
	_tokens[index] = token


## A parcel of the wagon's colour flies from the collected wagon into the siding, which
## then bounces.
func play_match(from: Vector3, slot_index: int, color: int) -> void:
	var parcel := _models.shape(self, "rounded_box", from, Vector3(0.5, 0.36, 0.5), Palette.wagon(color), false)
	var target := berth_position(slot_index) + Vector3.UP * 1.4
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		parcel.position = from.lerp(target, t) + Vector3.UP * sin(t * PI) * 2.6
		parcel.rotation = Vector3(t * 3.0, t * 5.0, 0.0)
		parcel.scale = Vector3(0.5, 0.36, 0.5) * lerpf(1.0, 0.6, t), 0.0, 1.0, FLIGHT_SECONDS).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(parcel.queue_free)
	tween.tween_callback(func() -> void:
		if _tokens[slot_index] != null:
			_bump(_tokens[slot_index]))


func _bump(node: Node3D) -> void:
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector3(1.0, 1.12, 1.0), BUMP_SECONDS * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector3.ONE, BUMP_SECONDS * 0.6)
