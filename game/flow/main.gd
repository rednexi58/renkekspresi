class_name Main
extends Node
## Composition root and game flow. Builds the shared GameContext (campaign, progress,
## store, audio), the UI layers (home, HUD, menus, dialogs, toasts) and runs the loop:
## home -> level -> result -> next level or home. Rule changes go through LevelSession;
## money and rewards go through CommerceService; numbers come from Economy.

const TOAST_KEYS := {
	PuzzleEngine.ChooseResult.FULL: "TOAST_FULL",
	PuzzleEngine.ChooseResult.LOCKED: "TOAST_LOCKED",
	PuzzleEngine.ChooseResult.BLOCKED: "TOAST_BLOCKED",
}
const BOOSTER_TOAST_KEYS := {
	PuzzleEngine.BoosterResult.NO_TARGET: "TOAST_NO_TARGET",
	PuzzleEngine.BoosterResult.EMPTY: "TOAST_EMPTY",
	PuzzleEngine.BoosterResult.ACTIVE: "TOAST_ACTIVE",
}
const BOOSTER_KEYS := ["BOOSTER_FREEZE", "BOOSTER_BLAST", "BOOSTER_RECALL"]
const PLACEMENT_SLOT := "extra_slot"
const PLACEMENT_BOOSTER := "booster_refill"
const PLACEMENT_CONTINUE := "continue"
const PLACEMENT_DOUBLE := "double_coins"

var context := GameContext.new()
var level_index := 0
var world: LevelWorld
var session: LevelSession
var hud: GameHud
var home: HomeScreen
var dialog: DialogOverlay
var card: MenuCard
var menus: Menus
var toaster: Toaster
var _reward_guard := RewardGuard.new()
var _last_win_coins := 0


func _ready() -> void:
	context.campaign = Campaign.load_from()
	if context.campaign == null:
		push_error("Campaign could not be loaded")
		return
	context.progress = SaveStore.load_progress()
	context.commerce = _create_commerce()
	context.commerce.entitlements_changed.connect(_on_entitlements_changed)
	context.audio = AudioService.new()
	add_child(context.audio)
	context.apply_settings()
	_build_ui()
	var requested := _requested_level()
	if requested >= 0:
		# Development/screenshot shortcut: jump straight into the requested level.
		context.progress.unlocked = maxi(context.progress.unlocked, requested + 1)
		context.progress.tutorial_done = true
		start_level(requested)
	else:
		show_home()


## Development builds and internal "playtest" TestFlight builds get an instant test
## provider so every paid and rewarded flow can be tried; App Store builds never do,
## and until real providers are attached they show no paid or rewarded entry point.
func _create_commerce() -> CommerceService:
	if OS.is_debug_build() or OS.has_feature("playtest"):
		return DebugCommerce.new()
	return UnavailableCommerce.new()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = GameHud.new()
	layer.add_child(hud)
	hud.pause_requested.connect(_on_pause)
	hud.booster_requested.connect(_on_booster)
	home = HomeScreen.new()
	layer.add_child(home)
	home.play_pressed.connect(func() -> void: start_level(context.progress.current_level))
	home.menu_pressed.connect(_open_menu)
	card = MenuCard.new()
	layer.add_child(card)
	card.closed.connect(_refresh_home)
	menus = Menus.new(context, card)
	menus.level_chosen.connect(start_level)
	dialog = DialogOverlay.new()
	layer.add_child(dialog)
	toaster = Toaster.new()
	layer.add_child(toaster)
	menus.toast.connect(toaster.show_message)
	context.progress_changed.connect(_refresh_home)
	get_viewport().size_changed.connect(_frame_camera)


## Optional `-- --level=N` command-line argument (development and screenshot tooling).
func _requested_level() -> int:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--level="):
			return clampi(int(argument.get_slice("=", 1)) - 1, 0, context.campaign.count() - 1)
	return -1


# --- Home and menus ------------------------------------------------------------------

func show_home() -> void:
	_teardown_level()
	hud.visible = false
	home.visible = true
	_refresh_home()


func _refresh_home() -> void:
	if home != null and home.visible:
		home.refresh(context.progress, DailyReward.can_claim(context.progress, DailyReward.today()))


func _open_menu(menu: String) -> void:
	context.audio.play("tap")
	menus.open(menu)


# --- Level lifecycle -----------------------------------------------------------------

func start_level(index: int) -> void:
	_teardown_level()
	level_index = clampi(index, 0, mini(context.campaign.count(), context.progress.unlocked) - 1)
	var level := context.campaign.level_at(level_index)
	home.visible = false
	hud.visible = true
	session = LevelSession.new()
	session.name = "Session"
	add_child(session)
	session.begin(level, context.has_vip())
	_reward_guard.cancel()
	world = LevelWorld.new()
	world.name = "World"
	add_child(world)
	world.build(level, RailRoute.load_level(level.id), session.engine, context.progress.skin_selected)
	_update_offers()
	session.collector_sent.connect(_on_collector_sent)
	session.choice_rejected.connect(_on_choice_rejected)
	session.booster_refused.connect(_on_booster_refused)
	session.matched.connect(_on_matched)
	session.ticked.connect(_sync)
	session.finished.connect(_on_finished)
	session.slots_changed.connect(_sync)
	hud.show_level(level)
	_sync()
	_frame_camera.call_deferred()
	context.audio.play("whistle")
	if level_index == 0 and not context.progress.tutorial_done:
		_show_tutorial()


func _teardown_level() -> void:
	if session != null:
		session.queue_free()
		session = null
	if world != null:
		world.queue_free()
		world = null


func _show_tutorial() -> void:
	session.paused = true
	dialog.present(tr("APP_TITLE"), tr("TUTORIAL_1"), [[tr("BTN_OK"), DialogOverlay.Tone.GREEN, func() -> void:
		dialog.present(tr("APP_TITLE"), tr("TUTORIAL_2"), [[tr("BTN_OK"), DialogOverlay.Tone.GREEN, func() -> void:
			context.progress.tutorial_done = true
			context.save()
			session.paused = false]])]])


func _update_offers() -> void:
	if world != null:
		world.set_offers(context.commerce.can_purchase_vip() and not context.has_vip(), context.commerce.can_show_rewarded())


func _frame_camera() -> void:
	if world != null and world.camera != null:
		world.frame(hud.play_area())


func _sync() -> void:
	if session == null or world == null:
		return
	world.sync(session.engine)
	hud.refresh(session.engine, session.is_active())


# --- Input ---------------------------------------------------------------------------

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


# --- Session events ------------------------------------------------------------------

func _on_collector_sent(collector_id: int, slot_index: int, color_id: int) -> void:
	world.launch_collector(collector_id, slot_index, color_id)
	context.audio.play("tap")
	context.haptic(12)


func _on_choice_rejected(collector_id: int, result: PuzzleEngine.ChooseResult, blockers: PackedInt32Array) -> void:
	world.reject_collector(collector_id, blockers)
	context.haptic(30)
	if TOAST_KEYS.has(result):
		toaster.show_message(tr(TOAST_KEYS[result]))


func _on_matched(event: MatchEvent) -> void:
	world.play_match(event)
	context.audio.play("match")


func _on_booster(kind: int) -> void:
	if session == null or not session.is_active():
		return
	if session.engine.booster_stock[kind] <= 0:
		_offer_booster(kind)
		return
	session.use_booster(kind)
	context.audio.play("fill")
	_sync()


func _on_booster_refused(_kind: int, result: PuzzleEngine.BoosterResult) -> void:
	if BOOSTER_TOAST_KEYS.has(result):
		toaster.show_message(tr(BOOSTER_TOAST_KEYS[result]))


## Out of a booster: buy one use with coins, or (if available) watch a rewarded ad.
func _offer_booster(kind: int) -> void:
	session.paused = true
	var cost := Economy.booster_cost(kind)
	var buttons := [[tr("BTN_BUY_COINS") % cost, DialogOverlay.Tone.PRIMARY, func() -> void:
		if context.progress.spend_coins(cost):
			context.save()
			session.engine.grant_booster(kind)
		else:
			toaster.show_message(tr("NOT_ENOUGH_COINS"))
		_resume()]]
	if context.commerce.can_show_rewarded():
		buttons.append([tr("BTN_WATCH_AD"), DialogOverlay.Tone.GREEN, func() -> void:
			_rewarded(PLACEMENT_BOOSTER, func() -> void: session.engine.grant_booster(kind))])
	buttons.append([tr("BTN_CLOSE"), DialogOverlay.Tone.BLUE, _resume])
	dialog.present(tr("BOOSTER_OUT_TITLE") % tr(BOOSTER_KEYS[kind]), tr("BOOSTER_OUT_BODY"), buttons)


func _on_pause() -> void:
	if session == null or not session.is_active():
		return
	session.paused = true
	_sync()
	dialog.present(tr("PAUSE_TITLE"), "", [
		[tr("BTN_RESUME"), DialogOverlay.Tone.GREEN, _resume],
		[tr("BTN_RESTART"), DialogOverlay.Tone.BLUE, func() -> void: start_level(level_index)],
		[tr("BTN_HOME"), DialogOverlay.Tone.PRIMARY, show_home],
	])


func _resume() -> void:
	if session != null and session.engine.is_playing() and not dialog.visible:
		session.paused = false
	_sync()


# --- Paid and rewarded offers --------------------------------------------------------

## VIP: one permanent extra slot in every level, opened only after a verified purchase.
func _offer_vip() -> void:
	session.paused = true
	var token := _reward_guard.begin()
	context.buy(ProductCatalog.VIP, func(coins: int) -> void:
		if _reward_guard.accept(token, coins >= 0) and context.has_vip():
			session.unlock_vip_slot()
		_resume())


## Rewarded ad: one more slot for this level, granted only if the ad was watched.
func _offer_reward_slot() -> void:
	if not session.engine.can_grant_reward_slot():
		return
	session.paused = true
	_rewarded(PLACEMENT_SLOT, func() -> void: session.unlock_reward_slot())


## Shows a rewarded ad and runs `grant` only if it was earned and still relevant.
func _rewarded(placement: String, grant: Callable) -> void:
	var token := _reward_guard.begin()
	context.commerce.show_rewarded(placement, func(earned: bool) -> void:
		if _reward_guard.accept(token, earned):
			grant.call()
		_resume())


func _on_entitlements_changed() -> void:
	PurchaseFulfillment.sync_entitlements(context.commerce, context.progress)
	context.save()
	_update_offers()
	_sync()


# --- Results -------------------------------------------------------------------------

func _on_finished(won: bool) -> void:
	_sync()
	if won:
		_on_win()
	else:
		_on_loss()


func _on_win() -> void:
	var engine := session.engine
	var progress := context.progress
	world.play_win()
	context.audio.play("win")
	_last_win_coins = Economy.win_coins(engine.assisted)
	progress.record_win(level_index, int(engine.elapsed))
	progress.add_coins(_last_win_coins)
	progress.piggy_coins = Economy.piggy_after_win(progress.piggy_coins)
	progress.wins_since_interstitial += 1
	context.save()
	var seconds := int(engine.elapsed)
	var body := tr("WIN_BODY") % ["%02d:%02d" % [seconds / 60, seconds % 60], engine.taps] + "\n" + tr("WIN_COINS") % _last_win_coins
	var last := level_index >= context.campaign.count() - 1
	var buttons := [[tr("ALL_DONE") if last else tr("BTN_NEXT"), DialogOverlay.Tone.GREEN, _after_win.bind(0 if last else level_index + 1)]]
	if context.commerce.can_show_rewarded():
		buttons.append([tr("BTN_DOUBLE"), DialogOverlay.Tone.PRIMARY, func() -> void:
			var token := _reward_guard.begin()
			context.commerce.show_rewarded(PLACEMENT_DOUBLE, func(earned: bool) -> void:
				if _reward_guard.accept(token, earned):
					var extra := _last_win_coins * (Economy.DOUBLE_REWARD_FACTOR - 1)
					progress.add_coins(extra)
					context.save()
					toaster.show_message(tr("WIN_COINS") % extra)
				_after_win(0 if last else level_index + 1))])
	buttons.append([tr("BTN_HOME"), DialogOverlay.Tone.BLUE, show_home])
	dialog.present(tr("WIN_TITLE"), body, buttons, Palette.GOLD)


## Interstitials are paced by Economy and never shown to No Ads owners.
func _after_win(next_index: int) -> void:
	var progress := context.progress
	if Economy.interstitial_due(level_index, progress.wins_since_interstitial, progress.owns_no_ads) and context.commerce.can_show_interstitial():
		progress.wins_since_interstitial = 0
		context.save()
		context.commerce.show_interstitial(func() -> void: start_level(next_index))
	else:
		start_level(next_index)


func _on_loss() -> void:
	var engine := session.engine
	world.play_loss()
	context.audio.play("lose")
	context.haptic(60)
	var buttons := []
	if engine.revives < Economy.REVIVE_LIMIT:
		buttons.append([tr("BTN_CONTINUE_COINS") % Economy.REVIVE_COST, DialogOverlay.Tone.PRIMARY, func() -> void:
			if context.progress.spend_coins(Economy.REVIVE_COST):
				context.save()
				_revive()
			else:
				toaster.show_message(tr("NOT_ENOUGH_COINS"))
				_on_loss()])
		if context.commerce.can_show_rewarded():
			buttons.append([tr("BTN_CONTINUE_AD"), DialogOverlay.Tone.GREEN, func() -> void:
				var token := _reward_guard.begin()
				context.commerce.show_rewarded(PLACEMENT_CONTINUE, func(earned: bool) -> void:
					if _reward_guard.accept(token, earned):
						_revive()
					else:
						_on_loss())])
	buttons.append([tr("BTN_RETRY"), DialogOverlay.Tone.BLUE, func() -> void: start_level(level_index)])
	buttons.append([tr("BTN_HOME"), DialogOverlay.Tone.BLUE, show_home])
	dialog.present(tr("LOSE_TITLE"), tr("LOSE_BODY"), buttons, Palette.DANGER)


func _revive() -> void:
	if session.revive():
		_sync()


func _notification(what: int) -> void:
	# Going to the background (call, home button) pauses play and saves.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if context.progress != null:
			context.save()
		if session != null and session.is_active():
			_on_pause()
