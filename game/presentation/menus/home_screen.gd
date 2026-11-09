class_name HomeScreen
extends Control
## The start screen: title, a hero picture of the player's locomotive, the big Play
## button for the next level, the coin balance and entry points to levels, shop,
## garage, daily gift and settings. Emits intents only.

signal play_pressed
signal menu_pressed(menu: String)


var _coins: Label
var _play: Button
var _daily_dot: Panel
var _status: Label
var _hero: TrainPreview


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.theme()
	_add_winter_backdrop()
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 26)
	add_child(column)
	var title := UiStyle.heading(tr("APP_TITLE"), 116, Palette.WHITE, Palette.INK)
	column.add_child(title)
	var hero_box := CenterContainer.new()
	column.add_child(hero_box)
	_hero = TrainPreview.new(Vector2(900, 620), true)
	hero_box.add_child(_hero)
	var play_box := CenterContainer.new()
	column.add_child(play_box)
	_play = Button.new()
	_play.custom_minimum_size = Vector2(720, 170)
	_play.focus_mode = Control.FOCUS_NONE
	_play.add_theme_font_size_override("font_size", 58)
	UiStyle.tint_button(_play, Palette.BUTTON_GREEN, Palette.BUTTON_GREEN_EDGE)
	_play.pressed.connect(func() -> void: play_pressed.emit())
	play_box.add_child(_play)
	_status = UiStyle.heading("", 38, Palette.WHITE, Palette.INK)
	column.add_child(_status)
	var grid_box := CenterContainer.new()
	column.add_child(grid_box)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	grid_box.add_child(grid)
	for entry in [["levels", "MENU_LEVELS", Palette.BUTTON_BLUE], ["shop", "MENU_SHOP", Palette.BUTTON_PRIMARY],
			["garage", "MENU_GARAGE", Color("9b4dff")], ["daily", "MENU_DAILY", Color("ff6f91")],
			["records", "MENU_RECORDS", Color("16b8a6")], ["settings", "MENU_SETTINGS", Palette.INK_SOFT]]:
		var button := Button.new()
		button.text = tr(entry[1])
		button.custom_minimum_size = Vector2(310, 124)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 38)
		UiStyle.tint_button(button, entry[2], (entry[2] as Color).darkened(0.3))
		var menu: String = entry[0]
		button.pressed.connect(func() -> void: menu_pressed.emit(menu))
		grid.add_child(button)
		if menu == "daily":
			_daily_dot = Panel.new()
			_daily_dot.add_theme_stylebox_override("panel", UiStyle.pill(Palette.DANGER, Palette.DANGER.darkened(0.3)))
			_daily_dot.size = Vector2(44, 44)
			_daily_dot.position = Vector2(280, -14)
			_daily_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(_daily_dot)
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 36
	top.offset_right = -36
	top.offset_top = 60
	add_child(top)
	var coin_pill := PanelContainer.new()
	coin_pill.add_theme_stylebox_override("panel", UiStyle.pill(Palette.PANEL, Palette.PANEL_EDGE))
	top.add_child(coin_pill)
	_coins = UiStyle.heading("", 46, Palette.GOLD_DARK, Color(0, 0, 0, 0))
	coin_pill.add_child(_coins)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var settings := Button.new()
	settings.text = "⚙"
	settings.custom_minimum_size = Vector2(124, 124)
	settings.focus_mode = Control.FOCUS_NONE
	settings.add_theme_stylebox_override("normal", UiStyle.round_gold(false))
	settings.add_theme_stylebox_override("hover", UiStyle.round_gold(false))
	settings.add_theme_stylebox_override("pressed", UiStyle.round_gold(true))
	settings.add_theme_font_size_override("font_size", 60)
	settings.pressed.connect(func() -> void: menu_pressed.emit("settings"))
	top.add_child(settings)


## Winter sky fading into snow, with flakes drifting over the whole screen.
func _add_winter_backdrop() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color("9fc9ee"), Color("dcecf9"), Color("f7fbff")])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 8
	texture.height = 256
	var sky := TextureRect.new()
	sky.texture = texture
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	var snow := CPUParticles2D.new()
	snow.amount = 70
	snow.lifetime = 9.0
	snow.preprocess = 9.0
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.emission_rect_extents = Vector2(700, 10)
	snow.position = Vector2(540, -20)
	snow.direction = Vector2(0.15, 1.0)
	snow.spread = 10.0
	snow.gravity = Vector2.ZERO
	snow.initial_velocity_min = 110.0
	snow.initial_velocity_max = 190.0
	snow.scale_amount_min = 5.0
	snow.scale_amount_max = 11.0
	snow.color = Color(1.0, 1.0, 1.0, 0.85)
	add_child(snow)


func refresh(progress: PlayerProgress, daily_available: bool) -> void:
	_coins.text = "● %d" % progress.coins
	_play.text = tr("PLAY_LEVEL") % (progress.current_level + 1)
	_hero.show_skin(progress.skin_selected)
	var city := WorldTour.city(progress.current_level, TranslationServer.get_locale().substr(0, 2))
	_status.text = tr("HOME_STATUS") % [city, progress.win_streak, progress.chest_stars, StarChest.STARS_TO_OPEN]
	_daily_dot.visible = daily_available
