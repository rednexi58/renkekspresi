class_name Main
extends Node
## Composition root: loads the campaign, wires the level world, the session that runs the
## rules, the HUD and dialogs, and translates input into session actions. Nothing else
## creates long-lived objects, so dependencies stay visible in one place.

const TOAST_KEYS := {
	PuzzleEngine.ChooseResult.FULL: "TOAST_FULL",
	PuzzleEngine.ChooseResult.LOCKED: "TOAST_LOCKED",
	PuzzleEngine.ChooseResult.BLOCKED: "TOAST_BLOCKED",
}
const BOOSTER_TOAST_KEYS := {
	PuzzleEngine.BoosterResult.NO_TARGET: "TOAST_NO_TARGET",
	PuzzleEngine.BoosterResult.EMPTY: "TOAST_EMPTY",
	PuzzleEngine.BoosterResult.ACTIVE: "TOAST_ACTIVE",
	PuzzleEngine.BoosterResult.NO_STOCK: "TOAST_USED_UP",
}

const REWARDED_SLOT_PLACEMENT := "extra_slot"

var campaign: Campaign
var commerce: CommerceService
var level_index := 0
var _reward_guard := RewardGuard.new()
var world: LevelWorld
var session: LevelSession
var hud: GameHud
var dialog: DialogOverlay
var _ui_layer: CanvasLayer


func _ready() -> void:
	campaign = Campaign.load_from()
	if campaign == null:
		push_error("Campaign could not be loaded")
		return
	TranslationServer.set_locale(LanguagePolicy.resolve("", OS.get_locale()))
	commerce = _create_commerce()
	commerce.entitlements_changed.connect(_on_entitlements_changed)
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)
	hud = GameHud.new()
	_ui_layer.add_child(hud)
	hud.pause_requested.connect(_on_pause)
	hud.booster_requested.connect(_on_booster)
	dialog = DialogOverlay.new()
	_ui_layer.add_child(dialog)
	get_viewport().size_changed.connect(_frame_camera)
	start_level(_requested_level())


## Development builds get an instant test provider so the VIP and rewarded-slot flows
## can be played before StoreKit and the ad SDK are integrated; release exports never
## do, and until real providers exist they see no paid or rewarded entry points at all.
func _create_commerce() -> CommerceService:
	if OS.is_debug_build():
		return DebugCommerce.new()
	return UnavailableCommerce.new()


## Optional `-- --level=N` command-line argument (development and screenshot tooling).
func _requested_level() -> int:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--level="):
			return clampi(int(argument.get_slice("=", 1)) - 1, 0, campaign.count() - 1)
	return 0


func start_level(index: int) -> void:
	level_index = clampi(index, 0, campaign.count() - 1)
	var level := campaign.level_at(level_index)
	if session != null:
		session.queue_free()
	if world != null:
		world.queue_free()
	session = LevelSession.new()
	session.name = "Session"
	add_child(session)
	session.begin(level, commerce.has_vip())
	_reward_guard.cancel()
	world = LevelWorld.new()
	world.name = "World"
	add_child(world)
	world.build(level, RailRoute.load_level(level.id), session.engine)
	world.set_offers(commerce.can_purchase_vip(), commerce.can_show_rewarded())
	session.collector_sent.connect(world.launch_collector)
	session.choice_rejected.connect(_on_choice_rejected)
	session.booster_refused.connect(_on_booster_refused)
	session.matched.connect(world.play_match)
	session.ticked.connect(_on_ticked)
	session.finished.connect(_on_finished)
	session.slots_changed.connect(_sync)
	hud.show_level(level)
	hud.refresh(session.engine, true)
	_frame_camera.call_deferred()


func _frame_camera() -> void:
	if world != null and world.camera != null:
		world.frame(hud.play_area())


func _unhandled_input(event: InputEvent) -> void:
	if session == null or not session.is_active():
		return
	# Touches arrive as emulated mouse presses (Godot's default), which also drives the
	# GUI buttons, so one code path serves phone and desktop without double taps.
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var shelf: Array = world.pick_shelf(event.position)
	match shelf[1]:
		ShelfView.Look.VIP_OFFER:
			_offer_vip()
			return
		ShelfView.Look.AD_OFFER:
			_offer_reward_slot()
			return
	session.choose(world.pick(event.position, session.engine))
	_sync()


## VIP: one permanent extra slot in every level. The purchase result comes only from the
## store; the slot opens only after a verified purchase.
func _offer_vip() -> void:
	session.paused = true
	var token := _reward_guard.begin()
	commerce.purchase_vip(func(ok: bool) -> void:
		if _reward_guard.accept(token, ok) and commerce.has_vip():
			session.unlock_vip_slot()
		_resume_after_offer())


## Rewarded ad: one more slot for this level, granted only if the ad was watched.
func _offer_reward_slot() -> void:
	if not session.engine.can_grant_reward_slot():
		return
	session.paused = true
	var token := _reward_guard.begin()
	commerce.show_rewarded(REWARDED_SLOT_PLACEMENT, func(earned: bool) -> void:
		if _reward_guard.accept(token, earned):
			session.unlock_reward_slot()
		_resume_after_offer())


func _resume_after_offer() -> void:
	if session != null and session.engine.is_playing() and not dialog.visible:
		session.paused = false
	_sync()


func _on_entitlements_changed() -> void:
	if world != null:
		world.set_offers(commerce.can_purchase_vip(), commerce.can_show_rewarded())
		_sync()


func _on_ticked() -> void:
	_sync()


func _sync() -> void:
	world.sync(session.engine)
	hud.refresh(session.engine, session.is_active())


func _on_choice_rejected(collector_id: int, result: PuzzleEngine.ChooseResult, blockers: PackedInt32Array) -> void:
	world.reject_collector(collector_id, blockers)
	if TOAST_KEYS.has(result):
		hud.toast(tr(TOAST_KEYS[result]))


func _on_booster(kind: int) -> void:
	session.use_booster(kind)
	_sync()


func _on_booster_refused(_kind: int, result: PuzzleEngine.BoosterResult) -> void:
	if BOOSTER_TOAST_KEYS.has(result):
		hud.toast(tr(BOOSTER_TOAST_KEYS[result]))


func _on_pause() -> void:
	if session == null or not session.is_active():
		return
	session.paused = true
	_sync()
	dialog.present(tr("PAUSE_TITLE"), "", [
		[tr("BTN_RESUME"), DialogOverlay.Tone.GREEN, _resume],
		[tr("BTN_RESTART"), DialogOverlay.Tone.BLUE, func() -> void: start_level(level_index)],
	])


func _resume() -> void:
	session.paused = false


func _on_finished(won: bool) -> void:
	_sync()
	var engine := session.engine
	if won:
		world.play_win()
		var seconds := int(engine.elapsed)
		var body := tr("WIN_BODY") % ["%02d:%02d" % [seconds / 60, seconds % 60], engine.taps]
		var last := level_index >= campaign.count() - 1
		var next_label := tr("ALL_DONE") if last else tr("BTN_NEXT")
		var next_index := 0 if last else level_index + 1
		dialog.present(tr("WIN_TITLE"), body, [
			[next_label, DialogOverlay.Tone.GREEN, func() -> void: start_level(next_index)],
			[tr("BTN_RETRY"), DialogOverlay.Tone.BLUE, func() -> void: start_level(level_index)],
		], Palette.GOLD)
	else:
		world.play_loss()
		dialog.present(tr("LOSE_TITLE"), tr("LOSE_BODY"), [
			[tr("BTN_RETRY"), DialogOverlay.Tone.PRIMARY, func() -> void: start_level(level_index)],
		], Palette.DANGER)


func _notification(what: int) -> void:
	# Going to the background (call, home button) pauses play instead of letting the
	# train run while the player is away.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if session != null and session.is_active():
			_on_pause()
