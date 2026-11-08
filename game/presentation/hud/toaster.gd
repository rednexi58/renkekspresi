class_name Toaster
extends Control
## Short messages ("+30 coins", "Not enough coins") shown above every screen.

const SECONDS := 2.2

var _pill: PanelContainer
var _label: Label
var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill = PanelContainer.new()
	_pill.add_theme_stylebox_override("panel", UiStyle.glass_pill())
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.modulate.a = 0.0
	add_child(_pill)
	_label = UiStyle.body("", 36, Palette.WHITE)
	_label.custom_minimum_size = Vector2(860, 0)
	_pill.add_child(_label)


func show_message(message: String) -> void:
	_label.text = message
	_pill.reset_size()
	var viewport := get_viewport_rect().size
	_pill.position = Vector2((viewport.x - 920.0) * 0.5, viewport.y * 0.16)
	if _tween != null:
		_tween.kill()
	_pill.modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(SECONDS)
	_tween.tween_property(_pill, "modulate:a", 0.0, 0.3)
