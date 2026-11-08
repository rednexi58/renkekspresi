class_name GameHud
extends Control
## In-level heads-up display: level title, train progress, rescued counter, hint line,
## three boosters and short toasts. Passive: it renders PuzzleEngine state and emits
## intent signals; the game flow decides what happens.

signal pause_requested
signal booster_requested(kind: int)

const ICONS: Array[Texture2D] = [
	preload("res://assets/icons/freeze.png"),
	preload("res://assets/icons/blast.png"),
	preload("res://assets/icons/recall.png"),
]
const BOOSTER_KEYS := ["BOOSTER_FREEZE", "BOOSTER_BLAST", "BOOSTER_RECALL"]
const TOP_HEIGHT := 330.0
const BOTTOM_HEIGHT := 270.0
const TOAST_SECONDS := 2.2
const FINAL_STRETCH := 0.85

var _safe := Rect2()
var _top: Control
var _bottom: Control
var _title: Label
var _region: Label
var _counter: Label
var _hint: Label
var _progress: ProgressTrack
var _boosters: Array[BoosterButton] = []
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiStyle.theme()
	_build_top()
	_build_bottom()
	_build_toast()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _build_top() -> void:
	_top = Control.new()
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top)
	var pause := Button.new()
	pause.text = "II"
	pause.focus_mode = Control.FOCUS_NONE
	pause.custom_minimum_size = Vector2(128, 128)
	pause.position = Vector2(36, 18)
	pause.size = Vector2(128, 128)
	UiStyle.tint_button(pause, Palette.BUTTON_BLUE, Palette.BUTTON_BLUE_EDGE)
	pause.pressed.connect(func() -> void: pause_requested.emit())
	_top.add_child(pause)
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UiStyle.pill(Palette.WHITE, Palette.PANEL_EDGE))
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.position = Vector2(196, 14)
	pill.size = Vector2(500, 136)
	_top.add_child(pill)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -8)
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	pill.add_child(titles)
	_title = UiStyle.heading("", 54, Palette.INK, Color(0, 0, 0, 0))
	titles.add_child(_title)
	_region = UiStyle.body("", 28)
	titles.add_child(_region)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiStyle.pill(Palette.WHITE, Palette.PANEL_EDGE))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.position = Vector2(724, 14)
	chip.size = Vector2(320, 136)
	_top.add_child(chip)
	var counter_box := VBoxContainer.new()
	counter_box.add_theme_constant_override("separation", -8)
	counter_box.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.add_child(counter_box)
	_counter = UiStyle.heading("", 50, Palette.SUCCESS.darkened(0.2), Color(0, 0, 0, 0))
	counter_box.add_child(_counter)
	var caption := UiStyle.body(tr("RESCUED"), 26)
	counter_box.add_child(caption)
	_progress = ProgressTrack.new()
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.position = Vector2(30, 170)
	_progress.size = Vector2(1020, 80)
	_top.add_child(_progress)
	_hint = UiStyle.heading("", 34, Palette.WHITE, Palette.INK)
	_hint.position = Vector2(0, 252)
	_hint.size = Vector2(1080, 60)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(_hint)


func _build_bottom() -> void:
	_bottom = Control.new()
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bottom)
	for kind in 3:
		var button := BoosterButton.new()
		_bottom.add_child(button)
		button.setup(ICONS[kind])
		button.position = Vector2(120 + kind * 300, 20)
		button.pressed.connect(func() -> void: booster_requested.emit(kind))
		_boosters.append(button)


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", UiStyle.pill(Palette.INK, Palette.INK.darkened(0.4)))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	add_child(_toast)
	_toast_label = UiStyle.body("", 34, Palette.WHITE)
	_toast_label.custom_minimum_size = Vector2(860, 0)
	_toast.add_child(_toast_label)


## Lays out against the device safe area (notch, home indicator). The design width is
## 1080; on wider screens the bars stay centred at design width.
func _layout() -> void:
	_safe = _safe_rect()
	var x := _safe.position.x + (_safe.size.x - 1080.0) * 0.5
	_top.position = Vector2(x, _safe.position.y)
	_bottom.position = Vector2(x, _safe.end.y - BOTTOM_HEIGHT)
	_toast.position = Vector2(x + 90.0, _safe.position.y + TOP_HEIGHT + 10.0)


## Screen area left free for the 3D diorama, in viewport coordinates.
func play_area() -> Rect2:
	var top := _safe.position.y + TOP_HEIGHT
	var bottom := _safe.end.y - BOTTOM_HEIGHT
	return Rect2(Vector2(_safe.position.x, top), Vector2(_safe.size.x, bottom - top))


func _safe_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	var window_size := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if window_size.x <= 0.0 or safe.size.x <= 0.0 or OS.has_feature("editor") or not OS.has_feature("mobile"):
		return Rect2(Vector2.ZERO, viewport_size)
	var ratio := viewport_size / window_size
	return Rect2(safe.position * ratio, safe.size * ratio)


func show_level(level: LevelDefinition) -> void:
	_title.text = tr("LEVEL_N") % level.id
	_region.text = level.region_en if TranslationServer.get_locale().begins_with("en") else level.region_tr


func refresh(engine: PuzzleEngine, boosters_enabled: bool) -> void:
	_counter.text = "%d/%d" % [engine.rescued_count(), engine.total_wagons]
	_progress.danger = engine.danger()
	if engine.freeze_left > 0.0:
		_hint.text = tr("HINT_FROZEN") % ("%.1f" % engine.freeze_left)
	elif engine.danger() > FINAL_STRETCH:
		_hint.text = tr("HINT_FINAL")
	else:
		_hint.text = tr("HINT_PLAY")
	for kind in 3:
		_boosters[kind].show_state(tr(BOOSTER_KEYS[kind]), engine.booster_stock[kind], boosters_enabled)


func toast(message: String) -> void:
	_toast_label.text = message
	if _toast_tween != null:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_SECONDS)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.3)
