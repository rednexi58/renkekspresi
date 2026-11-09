class_name Menus
extends RefCounted
## Builds the content of every menu card (levels, shop, garage, daily gift, settings)
## from the shared GameContext, and performs the menu actions through it. One class per
## concern would be finer-grained, but each menu is a short, declarative list of rows
## sharing the same card and context, so they live together for readability.

signal level_chosen(index: int)
signal toast(message: String)

var _context: GameContext
var _card: MenuCard


func _init(context: GameContext, card: MenuCard) -> void:
	_context = context
	_card = card


func open(menu: String) -> void:
	match menu:
		"levels":
			_levels()
		"shop":
			_shop()
		"garage":
			_garage()
		"daily":
			_daily()
		"settings":
			_settings()
		"records":
			_records()


# --- Levels --------------------------------------------------------------------------

## The world tour: legs of ten cities, each stop showing its number, city, country,
## best stars and a HARD tag. Locked stops are greyed; the current stop is green.
func _levels() -> void:
	var content := _card.open(_t("LEVELS_TITLE"))
	var progress := _context.progress
	var language := _context.language()
	var current_row: Control
	for i in _context.campaign.count():
		if i % WorldTour.STOPS_PER_LEG == 0:
			var leg := WorldTour.leg_of(i)
			var header := UiStyle.heading(_t(WorldTour.leg_key(leg)), 44, Palette.WHITE, Palette.INK)
			header.custom_minimum_size = Vector2(0, 90)
			content.add_child(header)
		var stop := WorldTour.stop(i, language)
		var unlocked := i < progress.unlocked
		var hard := LevelTags.is_hard(_context.campaign, i)
		var stars := "★".repeat(progress.stars[i]) + "☆".repeat(3 - progress.stars[i]) if progress.best_seconds[i] > 0 else ""
		var detail := stop[1]
		if hard:
			detail += "  ·  " + _t("HARD_BADGE")
		if stars != "":
			detail += "  ·  " + stars
		var tone := Palette.BUTTON_GREEN if i == progress.current_level else (Palette.DANGER if hard else Palette.BUTTON_BLUE)
		var index := i
		var row := MenuCard.row("%d · %s" % [i + 1, stop[0]], detail, _t("PLAY") if unlocked else "", func() -> void:
			_card.close_card()
			level_chosen.emit(index), tone if unlocked else Palette.INK_SOFT, unlocked)
		content.add_child(row)
		if i == progress.current_level:
			current_row = row
	if current_row != null:
		_card.scroll_to.call_deferred(current_row)


# --- Records -------------------------------------------------------------------------

## Personal records (furthest stop, total stars, best time per level) and, when Game
## Center is signed in, the global rankings for the same two boards.
func _records() -> void:
	var content := _card.open(_t("RECORDS_TITLE"))
	var progress := _context.progress
	var boards := _context.leaderboards
	var global := boards != null and boards.is_available()
	content.add_child(MenuCard.row(_t("RECORD_FURTHEST"), _t("RECORD_FURTHEST_DESC") % [progress.furthest_level(), WorldTour.city(maxi(0, progress.furthest_level() - 1), _context.language())],
		_t("RANKING") if global else "", func() -> void: boards.show_board(LeaderboardService.FURTHEST_BOARD), Color("16b8a6"), global))
	content.add_child(MenuCard.row(_t("RECORD_STARS"), "%d / %d ★" % [progress.total_stars(), _context.campaign.count() * 3], "", func() -> void: pass, Palette.INK_SOFT, false))
	if not global:
		content.add_child(UiStyle.body(_t("RECORDS_OFFLINE"), 30))
	for i in _context.campaign.count():
		var seconds := progress.best_seconds[i]
		if seconds <= 0:
			continue
		var level_id := _context.campaign.level_at(i).id
		content.add_child(MenuCard.row("%d · %s" % [i + 1, WorldTour.city(i, _context.language())], _t("BEST_TIME") % ("%02d:%02d" % [seconds / 60, seconds % 60]),
			_t("RANKING") if global else "", func() -> void: boards.show_board(LeaderboardService.level_board(level_id)), Palette.BUTTON_BLUE, global))


# --- Shop ----------------------------------------------------------------------------

func _shop() -> void:
	var content := _card.open(_t("SHOP_TITLE"))
	var commerce := _context.commerce
	var progress := _context.progress
	if not progress.owns_starter:
		_product_row(content, ProductCatalog.STARTER, _t("SHOP_STARTER"), _t("SHOP_STARTER_DESC"), Color("ff6f91"))
	_product_row(content, ProductCatalog.VIP, _t("SHOP_VIP"), _t("SHOP_VIP_DESC"), Palette.BUTTON_PRIMARY, progress.owns_vip)
	_product_row(content, ProductCatalog.NO_ADS, _t("SHOP_NOADS"), _t("SHOP_NOADS_DESC"), Palette.BUTTON_BLUE, progress.owns_no_ads)
	for id in [ProductCatalog.COINS_SMALL, ProductCatalog.COINS_MEDIUM, ProductCatalog.COINS_LARGE]:
		_product_row(content, id, _t("SHOP_COINS_N") % _thousands(ProductCatalog.coins_for(id)), "", Palette.BUTTON_GREEN)
	var piggy_ready := progress.piggy_coins >= Economy.PIGGY_MIN_TO_BREAK
	var piggy_text := _t("SHOP_PIGGY_DESC") % progress.piggy_coins if piggy_ready else _t("SHOP_PIGGY_LOCKED") % Economy.PIGGY_MIN_TO_BREAK
	if commerce.can_purchase(ProductCatalog.PIGGY):
		content.add_child(MenuCard.row(_t("SHOP_PIGGY"), piggy_text, commerce.price(ProductCatalog.PIGGY), _buy.bind(ProductCatalog.PIGGY), Color("ff9ec4"), piggy_ready))
	if commerce.can_purchase(ProductCatalog.COINS_SMALL) or commerce.owns(ProductCatalog.VIP):
		content.add_child(MenuCard.row(_t("RESTORE_TITLE"), _t("RESTORE_DESC"), _t("RESTORE_BTN"), _restore, Palette.INK_SOFT))


func _product_row(content: VBoxContainer, product_id: String, title: String, description: String, tone: Color, owned: bool = false) -> void:
	var commerce := _context.commerce
	if owned:
		content.add_child(MenuCard.row(title, description, _t("OWNED"), func() -> void: pass, Palette.INK_SOFT, false))
	elif commerce.can_purchase(product_id):
		content.add_child(MenuCard.row(title, description, commerce.price(product_id), _buy.bind(product_id), tone))


func _buy(product_id: String) -> void:
	_context.buy(product_id, func(coins: int) -> void:
		if coins < 0:
			toast.emit(_t("PURCHASE_FAILED"))
		elif coins > 0:
			toast.emit(_t("PURCHASED") % coins)
		else:
			toast.emit(_t("PURCHASED_PLAIN"))
		if _card.visible:
			_shop())


func _restore() -> void:
	_context.commerce.restore_purchases(func(ok: bool) -> void:
		if ok:
			PurchaseFulfillment.sync_entitlements(_context.commerce, _context.progress)
			_context.save()
		toast.emit(_t("RESTORED") if ok else _t("RESTORE_FAILED")))


# --- Garage --------------------------------------------------------------------------

func _garage() -> void:
	var content := _card.open(_t("GARAGE_TITLE"))
	var progress := _context.progress
	var preview := TrainPreview.new()
	content.add_child(preview)
	preview.show_skin(progress.skin_selected)
	for id: String in Palette.SKIN_ORDER:
		var livery := Palette.skin(id)
		var row: PanelContainer
		if progress.skin_selected == id:
			row = MenuCard.row(_t(livery["key"]), "", _t("SELECTED"), func() -> void: pass, Palette.INK_SOFT, false)
		elif progress.owns_skin(id):
			row = MenuCard.row(_t(livery["key"]), "", _t("SELECT"), _select_skin.bind(id), Palette.BUTTON_BLUE)
		elif int(livery["price"]) > 0:
			row = MenuCard.row(_t(livery["key"]), _t("TAP_TO_PREVIEW"), "● %d" % livery["price"], _buy_skin.bind(id), Palette.BUTTON_PRIMARY)
			row.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed:
					preview.show_skin(id))
		else:
			row = MenuCard.row(_t(livery["key"]), _t("STARTER_ONLY"), _t("MENU_SHOP"), func() -> void: _shop(), Color("ff6f91"))
		var line := row.get_child(0)
		var swatch := _swatch(livery)
		line.add_child(swatch)
		line.move_child(swatch, 0)
		content.add_child(row)


static func _swatch(livery: Dictionary) -> Control:
	var swatch := HBoxContainer.new()
	swatch.add_theme_constant_override("separation", 4)
	for key in ["body", "cab", "trim"]:
		var chip := Panel.new()
		chip.custom_minimum_size = Vector2(36, 90)
		chip.add_theme_stylebox_override("panel", UiStyle.pill(livery[key], (livery[key] as Color).darkened(0.25)))
		swatch.add_child(chip)
	return swatch


func _select_skin(id: String) -> void:
	_context.progress.skin_selected = id
	_context.save()
	_garage()


func _buy_skin(id: String) -> void:
	var price := int(Palette.skin(id)["price"])
	if not _context.progress.spend_coins(price):
		toast.emit(_t("NOT_ENOUGH_COINS"))
		return
	_context.progress.skins_owned.append(id)
	_context.progress.skin_selected = id
	_context.save()
	_garage()


# --- Daily gift ----------------------------------------------------------------------

func _daily() -> void:
	var content := _card.open(_t("DAILY_TITLE"))
	var progress := _context.progress
	var today := DailyReward.today()
	var available := DailyReward.can_claim(progress, today)
	var next_day := DailyReward.next_streak(progress, today) if available else progress.daily_streak
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	content.add_child(grid)
	for day in Economy.DAILY_REWARDS.size():
		var tile := PanelContainer.new()
		var cycle_day := ((next_day - 1) % Economy.DAILY_REWARDS.size()) + 1
		var claimed := (day + 1) < cycle_day or (not available and day + 1 == cycle_day)
		var fill := Palette.BUTTON_GREEN if day + 1 == cycle_day and available else (Palette.PANEL_EDGE if claimed else Palette.CREAM)
		tile.add_theme_stylebox_override("panel", UiStyle.card(fill, fill.darkened(0.2)))
		tile.custom_minimum_size = Vector2(196, 190)
		var texts := VBoxContainer.new()
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		tile.add_child(texts)
		texts.add_child(UiStyle.heading(_t("DAY_N") % (day + 1), 32, Palette.INK, Color(0, 0, 0, 0)))
		texts.add_child(UiStyle.heading("● %d" % Economy.DAILY_REWARDS[day], 40, Palette.GOLD_DARK, Color(0, 0, 0, 0)))
		grid.add_child(tile)
	if available:
		content.add_child(MenuCard.row(_t("DAY_N") % ((next_day - 1) % Economy.DAILY_REWARDS.size() + 1), "", _t("CLAIM"), _claim_daily, Palette.BUTTON_GREEN))
	else:
		content.add_child(UiStyle.body(_t("COME_BACK"), 34))


func _claim_daily() -> void:
	var coins := DailyReward.claim(_context.progress, DailyReward.today())
	if coins > 0:
		_context.save()
		toast.emit(_t("WIN_COINS") % coins)
	_daily()


# --- Settings ------------------------------------------------------------------------

func _settings() -> void:
	var content := _card.open(_t("MENU_SETTINGS"))
	var progress := _context.progress
	content.add_child(_toggle_row(_t("SETTINGS_MUSIC"), progress.music_on, func() -> void: progress.music_on = not progress.music_on))
	content.add_child(_toggle_row(_t("SETTINGS_SOUND"), progress.sound_on, func() -> void: progress.sound_on = not progress.sound_on))
	content.add_child(_toggle_row(_t("SETTINGS_HAPTICS"), progress.haptics_on, func() -> void: progress.haptics_on = not progress.haptics_on))
	var current := TranslationServer.get_locale().substr(0, 2)
	content.add_child(MenuCard.row(_t("SETTINGS_LANGUAGE"), "Türkçe / English", "EN" if current == "tr" else "TR", _switch_language, Palette.BUTTON_BLUE))
	if _context.commerce.can_purchase(ProductCatalog.COINS_SMALL) or _context.commerce.owns(ProductCatalog.VIP):
		content.add_child(MenuCard.row(_t("RESTORE_TITLE"), _t("RESTORE_DESC"), _t("RESTORE_BTN"), _restore, Palette.INK_SOFT))
	content.add_child(MenuCard.row(_t("PRIVACY"), "", "↗", func() -> void: OS.shell_open(GameContext.PRIVACY_URL), Palette.INK_SOFT))
	content.add_child(MenuCard.row(_t("SUPPORT"), "", "↗", func() -> void: OS.shell_open(GameContext.SUPPORT_URL), Palette.INK_SOFT))
	content.add_child(UiStyle.body(_t("VERSION_N") % ProjectSettings.get_setting("application/config/version", "1.0"), 28))


func _toggle_row(title: String, value: bool, flip: Callable) -> PanelContainer:
	return MenuCard.row(title, "", _t("ON") if value else _t("OFF"), func() -> void:
		flip.call()
		_context.save()
		_context.apply_settings()
		_settings(), Palette.BUTTON_GREEN if value else Palette.INK_SOFT)


func _switch_language() -> void:
	var current := TranslationServer.get_locale().substr(0, 2)
	_context.progress.language = LanguagePolicy.ENGLISH if current == "tr" else LanguagePolicy.TURKISH
	_context.save()
	_context.apply_settings()
	_settings()


static func _thousands(value: int) -> String:
	var text := str(value)
	var result := ""
	while text.length() > 3:
		result = "." + text.substr(text.length() - 3) + result
		text = text.substr(0, text.length() - 3)
	return text + result


static func _t(key: String) -> String:
	return TranslationServer.translate(key)
