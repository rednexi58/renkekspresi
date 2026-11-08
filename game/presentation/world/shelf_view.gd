class_name ShelfView
extends Node3D
## The station shelf: eight positions in two rows. Positions 0-2 are always open,
## position 3 is the VIP slot and positions 4-7 open one at a time with rewarded ads.
## A collector waits in its slot lying across the shelf, with its remaining capacity
## printed underneath. Locked positions show an unlock button (gold "VIP" or green
## "watch +1") only when the matching offer is genuinely available; otherwise they are
## hidden, so no dead button is ever drawn.

enum Look { HIDDEN, OPEN, VIP_OFFER, AD_OFFER }

const FLIGHT_SECONDS := 0.34
const BUMP_SECONDS := 0.16
const PAD_SIZE := Vector3(1.95, 0.12, 1.12)
const PICK_HEIGHT := 0.45
const AD_GREEN := Color("39c96b")
const AD_GREEN_EDGE := Color("1f9a4c")

var _models: ModelLibrary
var _layout: WorldLayout
var _pads: Array[MeshInstance3D] = []
var _offers: Array[Node3D] = []
var _looks: Array[Look] = []
var _tokens: Array[Node3D] = []
var _counts: Array[Label3D] = []
var _token_colors := PackedInt32Array()
## Engine slot index -> shelf position, rebuilt from the engine's slot kinds.
var _positions := PackedInt32Array()
## Shelf positions whose token is still in flight from the board.
var _arriving := {}


func setup(models: ModelLibrary, layout: WorldLayout) -> void:
	_models = models
	_layout = layout
	var centre := Vector3(0.0, 0.0, layout.shelf_centre_z())
	var width := layout.shelf_width()
	models.contact_shadow(self, centre + Vector3(0.0, 0.01, 0.3), Vector2(width + 1.4, WorldLayout.SHELF_DEPTH + 1.2), 0.3)
	models.shape_with(self, "rounded_box", centre + Vector3(0.0, 0.14, 0.06), Vector3(width + 0.1, 0.3, WorldLayout.SHELF_DEPTH + 0.12), models.painted(Palette.SHELF_EDGE, 0.7), false)
	models.shape_with(self, "rounded_box", centre + Vector3(0.0, 0.22, 0.0), Vector3(width, 0.3, WorldLayout.SHELF_DEPTH), models.painted(Palette.SHELF, 0.7), false)
	for i in WorldLayout.SLOT_COUNT:
		var at := layout.slot_position(i)
		var pad := models.shape(self, "rounded_box", at + Vector3(0.0, 0.33, 0.0), PAD_SIZE, Palette.SHELF_SLOT, false)
		_pads.append(pad)
		_offers.append(_build_offer(i, at))
		_looks.append(Look.HIDDEN)
		_tokens.append(null)
		var count := WorldLabels.painted_text("", 110, Palette.INK)
		count.position = at + Vector3(0.0, 0.4, 0.78)
		add_child(count)
		_counts.append(count)
		_token_colors.append(-1)


## Unlock button drawn on a locked position: gold VIP plate or green watch-ad plate.
func _build_offer(position_index: int, at: Vector3) -> Node3D:
	var offer := Node3D.new()
	offer.position = at + Vector3.UP * 0.4
	offer.visible = false
	add_child(offer)
	if position_index == WorldLayout.VIP_POSITION:
		_models.shape(offer, "rounded_box", Vector3(0.0, 0.0, 0.03), Vector3(1.85, 0.16, 1.0), Palette.GOLD_DARK, false)
		_models.shape(offer, "rounded_box", Vector3(0.0, 0.05, 0.0), Vector3(1.8, 0.16, 0.94), Palette.GOLD, false)
		var crown := WorldLabels.painted_text("VIP", 150, Palette.INK)
		crown.position = Vector3(0.0, 0.14, 0.02)
		offer.add_child(crown)
	elif position_index >= WorldLayout.FIRST_REWARD_POSITION:
		_models.shape(offer, "rounded_box", Vector3(0.0, 0.0, 0.03), Vector3(1.85, 0.16, 1.0), AD_GREEN_EDGE, false)
		_models.shape(offer, "rounded_box", Vector3(0.0, 0.05, 0.0), Vector3(1.8, 0.16, 0.94), AD_GREEN, false)
		var play := MeshInstance3D.new()
		play.mesh = WorldLabels.play_mesh(0.36)
		play.material_override = _models.flat_material(Palette.WHITE)
		play.position = Vector3(-0.42, 0.14, 0.0)
		offer.add_child(play)
		var plus := WorldLabels.painted_text("+1", 140, Palette.WHITE)
		plus.position = Vector3(0.3, 0.14, 0.02)
		offer.add_child(plus)
	return offer


## Mirrors the engine slots and which unlock offers are available right now.
func sync(engine: PuzzleEngine, vip_offer: bool, ad_offer: bool) -> void:
	_positions = _map_positions(engine)
	var occupied_color := {}
	for slot_index in engine.slots.size():
		var position_index := _positions[slot_index]
		var slot := engine.slots[slot_index]
		if slot.is_occupied():
			occupied_color[position_index] = slot_index
	var open_positions := {}
	for p in _positions:
		open_positions[p] = true
	for i in WorldLayout.SLOT_COUNT:
		var look := Look.OPEN if open_positions.has(i) else _locked_look(i, engine, vip_offer, ad_offer)
		_apply_look(i, look)
		var color := -1
		var remaining := -1
		if occupied_color.has(i):
			var slot := engine.slots[occupied_color[i]]
			color = slot.color
			remaining = engine.yard.at(slot.collector).remaining
		if color != _token_colors[i]:
			_replace_token(i, color)
		var shown := color >= 0 and not _arriving.has(i)
		if _tokens[i] != null:
			_tokens[i].visible = shown
		_counts[i].text = str(remaining) if shown else ""


func _locked_look(position_index: int, engine: PuzzleEngine, vip_offer: bool, ad_offer: bool) -> Look:
	if position_index == WorldLayout.VIP_POSITION:
		return Look.VIP_OFFER if vip_offer and not engine.vip else Look.HIDDEN
	if position_index >= WorldLayout.FIRST_REWARD_POSITION:
		return Look.AD_OFFER if ad_offer and engine.can_grant_reward_slot() else Look.HIDDEN
	return Look.HIDDEN


func _apply_look(position_index: int, look: Look) -> void:
	if _looks[position_index] == look:
		return
	_looks[position_index] = look
	_pads[position_index].visible = look == Look.OPEN
	_offers[position_index].visible = look == Look.VIP_OFFER or look == Look.AD_OFFER


## Base slots fill positions 0-2, the VIP slot position 3 and reward slots 4-7 in the
## order they were unlocked, whatever order the engine created them in.
static func _map_positions(engine: PuzzleEngine) -> PackedInt32Array:
	var result := PackedInt32Array()
	var base := 0
	var reward := 0
	for kind in engine.slot_kinds:
		match kind:
			PuzzleEngine.SlotKind.BASE:
				result.append(base)
				base += 1
			PuzzleEngine.SlotKind.VIP:
				result.append(WorldLayout.VIP_POSITION)
			PuzzleEngine.SlotKind.REWARD:
				result.append(WorldLayout.FIRST_REWARD_POSITION + reward)
				reward += 1
	return result


## Look of the position under a screen point, with its index: [index, Look] or [-1, HIDDEN].
func pick(camera: Camera3D, screen_position: Vector2) -> Array:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var hit: Variant = Plane(Vector3.UP, PICK_HEIGHT).intersects_ray(origin, direction)
	if hit == null:
		return [-1, Look.HIDDEN]
	var index := _layout.slot_at(to_local(hit))
	return [index, Look.HIDDEN if index < 0 else _looks[index]]


## Global position of the shelf position that engine slot `slot_index` occupies.
func slot_position(slot_index: int) -> Vector3:
	return to_global(_layout.slot_position(_position_of(slot_index)) + Vector3.UP * 0.4)


func _position_of(slot_index: int) -> int:
	return _positions[slot_index] if slot_index < _positions.size() else slot_index


func mark_arriving(slot_index: int) -> void:
	_arriving[_position_of(slot_index)] = true


func arrived(slot_index: int) -> void:
	var position_index := _position_of(slot_index)
	_arriving.erase(position_index)
	if _tokens[position_index] != null:
		_tokens[position_index].visible = true
		_bump(_tokens[position_index])


func _replace_token(position_index: int, color: int) -> void:
	if _tokens[position_index] != null:
		_tokens[position_index].queue_free()
		_tokens[position_index] = null
	_token_colors[position_index] = color
	if color < 0:
		return
	var token := Node3D.new()
	token.position = _layout.slot_position(position_index) + Vector3.UP * 0.4
	add_child(token)
	var wagon := _models.make_wagon(color)
	wagon.basis = Basis.looking_at(Vector3.LEFT, Vector3.UP).scaled(Vector3.ONE * WorldLayout.TOKEN_SCALE)
	token.add_child(wagon)
	_tokens[position_index] = token


## A parcel of the wagon's colour flies into the slot, which then bounces.
func play_match(from: Vector3, slot_index: int, color: int) -> void:
	var position_index := _position_of(slot_index)
	var parcel := _models.shape_with(get_parent(), "rounded_box", from, Vector3.ONE * 0.5, _models.painted(Palette.wagon(color)), false)
	var target := to_global(_layout.slot_position(position_index) + Vector3.UP * 1.2)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		parcel.global_position = from.lerp(target, t) + Vector3.UP * sin(t * PI) * 2.0
		parcel.rotation = Vector3(t * 3.0, t * 5.0, 0.0)
		parcel.scale = Vector3.ONE * lerpf(0.55, 0.3, t), 0.0, 1.0, FLIGHT_SECONDS).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(parcel.queue_free)
	tween.tween_callback(func() -> void:
		if _tokens[position_index] != null:
			_bump(_tokens[position_index]))


func _bump(node: Node3D) -> void:
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector3(1.12, 1.12, 1.12), BUMP_SECONDS * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector3.ONE, BUMP_SECONDS * 0.6)
