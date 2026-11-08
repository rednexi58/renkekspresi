class_name HomeScreen
extends Control
## The start screen: title, a hero picture of the player's locomotive, the big Play
## button for the next level, the coin balance and entry points to levels, shop,
## garage, daily gift and settings. Emits intents only.

signal play_pressed
signal menu_pressed(menu: String)

const HERO := preload("res://assets/branding/app_icon_1024.png")

var _coins: Label
var _play: Button
var _daily_dot: Panel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.theme()
	var background := ColorRect.new()
	background.color = Palette.BOARD
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var grass := ColorRect.new()
	grass.color = Palette.scene_ground(0)
	grass.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	grass.custom_minimum_size = Vector2(0, 820)
	grass.size = Vector2(get_viewport_rect().size.x, 820)
	add_child(grass)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 26)
	add_child(column)
	var title := UiStyle.heading(tr("APP_TITLE"), 116, Palette.WHITE, Palette.INK)
	column.add_child(title)
	var hero_box := CenterContainer.new()
	column.add_child(hero_box)
	var hero := TextureRect.new()
	hero.texture = HERO
	hero.custom_minimum_size = Vector2(560, 560)
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiStyle.gold_frame())
	frame.add_child(hero)
	hero_box.add_child(frame)
	var play_box := CenterContainer.new()
	column.add_child(play_box)
	_play = Button.new()
	_play.custom_minimum_size = Vector2(720, 170)
	_play.focus_mode = Control.FOCUS_NONE
	_play.add_theme_font_size_override("font_size", 58)
	UiStyle.tint_button(_play, Palette.BUTTON_GREEN, Palette.BUTTON_GREEN_EDGE)
	_play.pressed.connect(func() -> void: play_pressed.emit())
	play_box.add_child(_play)
	var grid_box := CenterContainer.new()
	column.add_child(grid_box)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	grid_box.add_child(grid)
	for entry in [["levels", "MENU_LEVELS", Palette.BUTTON_BLUE], ["shop", "MENU_SHOP", Palette.BUTTON_PRIMARY],
			["garage", "MENU_GARAGE", Color("9b4dff")], ["daily", "MENU_DAILY", Color("ff6f91")]]:
		var button := Button.new()
		button.text = tr(entry[1])
		button.custom_minimum_size = Vector2(348, 130)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 42)
		UiStyle.tint_button(button, entry[2], (entry[2] as Color).darkened(0.3))
		var menu: String = entry[0]
		button.pressed.connect(func() -> void: menu_pressed.emit(menu))
		grid.add_child(button)
		if menu == "daily":
			_daily_dot = Panel.new()
			_daily_dot.add_theme_stylebox_override("panel", UiStyle.pill(Palette.DANGER, Palette.DANGER.darkened(0.3)))
			_daily_dot.size = Vector2(44, 44)
			_daily_dot.position = Vector2(318, -14)
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


func refresh(progress: PlayerProgress, daily_available: bool) -> void:
	_coins.text = "● %d" % progress.coins
	_play.text = tr("PLAY_LEVEL") % (progress.current_level + 1)
	_daily_dot.visible = daily_available
