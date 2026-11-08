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


# --- Levels --------------------------------------------------------------------------

func _levels() -> void:
	var content := _card.open(_t("LEVELS_TITLE"))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	content.add_child(grid)
	var progress := _context.progress
	for i in _context.campaign.count():
		var button := Button.new()
		button.text = str(i + 1)
		button.custom_minimum_size = Vector2(150, 150)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 46)
		var unlocked := i < progress.unlocked
		button.disabled = not unlocked
		if i == progress.current_level:
			UiStyle.tint_button(button, Palette.BUTTON_GREEN, Palette.BUTTON_GREEN_EDGE)
		elif unlocked and progress.best_seconds[i] > 0:
			UiStyle.tint_button(button, Palette.BUTTON_BLUE, Palette.BUTTON_BLUE_EDGE)
		var index := i
		button.pressed.connect(func() -> void:
			_card.close_card()
			level_chosen.emit(index))
		grid.add_child(button)


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
		content.add_child(MenuCard.row(_t("RESTORE"), "", _t("RESTORE"), _restore, Palette.INK_SOFT))


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
	for id: String in Palette.SKIN_ORDER:
		var livery := Palette.skin(id)
		var row: PanelContainer
		if progress.skin_selected == id:
			row = MenuCard.row(_t(livery["key"]), "", _t("SELECTED"), func() -> void: pass, Palette.INK_SOFT, false)
		elif progress.owns_skin(id):
			row = MenuCard.row(_t(livery["key"]), "", _t("SELECT"), _select_skin.bind(id), Palette.BUTTON_BLUE)
		elif int(livery["price"]) > 0:
			row = MenuCard.row(_t(livery["key"]), "", "● %d" % livery["price"], _buy_skin.bind(id), Palette.BUTTON_PRIMARY)
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
		content.add_child(MenuCard.row(_t("RESTORE"), "", _t("RESTORE"), _restore, Palette.INK_SOFT))
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
