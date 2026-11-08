class_name GameHud
extends Control
## In-level heads-up display: pause button with the level number, train progress,
## rescued counter, three boosters and short toasts. Passive: it renders PuzzleEngine
## state and emits intent signals; the game flow decides what happens.

signal pause_requested
signal booster_requested(kind: int)

const ICONS: Array[Texture2D] = [
	preload("res://assets/icons/freeze.png"),
	preload("res://assets/icons/blast.png"),
	preload("res://assets/icons/recall.png"),
]
const BOOSTER_KEYS := ["BOOSTER_FREEZE", "BOOSTER_BLAST", "BOOSTER_RECALL"]
const TOP_HEIGHT := 220.0
const BOTTOM_HEIGHT := 262.0
const TOAST_SECONDS := 2.2

var _safe := Rect2()
var _top: Control
var _bottom: Control
var _title: Label
var _counter: Label
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
	pause.position = Vector2(40, 20)
	pause.size = Vector2(124, 124)
	pause.add_theme_stylebox_override("normal", UiStyle.round_gold(false))
	pause.add_theme_stylebox_override("hover", UiStyle.round_gold(false))
	pause.add_theme_stylebox_override("pressed", UiStyle.round_gold(true))
	pause.add_theme_font_size_override("font_size", 46)
	pause.pressed.connect(func() -> void: pause_requested.emit())
	_top.add_child(pause)
	_title = UiStyle.heading("", 36, Palette.WHITE, Palette.INK)
	_title.position = Vector2(12, 146)
	_title.size = Vector2(180, 52)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(_title)
	_progress = ProgressTrack.new()
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.position = Vector2(200, 42)
	_progress.size = Vector2(560, 80)
	_top.add_child(_progress)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiStyle.pill(Palette.PANEL, Palette.PANEL_EDGE))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.position = Vector2(790, 36)
	chip.size = Vector2(250, 96)
	_top.add_child(chip)
	_counter = UiStyle.heading("", 44, Palette.INK, Color(0, 0, 0, 0))
	chip.add_child(_counter)


func _build_bottom() -> void:
	_bottom = Control.new()
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bottom)
	for kind in 3:
		var button := BoosterButton.new()
		_bottom.add_child(button)
		button.setup(ICONS[kind])
		button.position = Vector2(120 + kind * 300, 10)
		button.pressed.connect(func() -> void: booster_requested.emit(kind))
		_boosters.append(button)


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", UiStyle.glass_pill())
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


## Screen area left free for the 3D view, in viewport coordinates.
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


func refresh(engine: PuzzleEngine, boosters_enabled: bool) -> void:
	_counter.text = "%d/%d" % [engine.rescued_count(), engine.total_wagons]
	_progress.danger = engine.danger()
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
