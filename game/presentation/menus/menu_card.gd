class_name MenuCard
extends Control
## Modal card used by every menu (shop, levels, garage, daily gift, settings): dimmed
## backdrop, title, close button and a scrollable content column. Menus fill the column;
## this class owns only presentation, opening and closing.

signal closed

const CARD_WIDTH := 940.0
const MAX_HEIGHT_SHARE := 0.82

var content: VBoxContainer
var _card: PanelContainer
var _title: Label
var _scroll: ScrollContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiStyle.theme()
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.06, 0.02, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_card = PanelContainer.new()
	centre.add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	_card.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_title = UiStyle.heading("", 64, Palette.GOLD, Palette.INK)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close := Button.new()
	close.text = "✕"
	close.custom_minimum_size = Vector2(100, 100)
	close.focus_mode = Control.FOCUS_NONE
	UiStyle.tint_button(close, Palette.DANGER, Palette.DANGER.darkened(0.3))
	close.pressed.connect(close_card)
	header.add_child(close)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(content)


## Clears the card, sets the title and shows it. Returns the content column to fill.
func open(title: String) -> VBoxContainer:
	for child in content.get_children():
		child.queue_free()
	_title.text = title
	var height := get_viewport_rect().size.y * MAX_HEIGHT_SHARE - 220.0
	_scroll.custom_minimum_size = Vector2(CARD_WIDTH - 80.0, height)
	_card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)
	return content


func close_card() -> void:
	visible = false
	closed.emit()


## A rounded row with a title, description and an action button on the right.
static func row(title: String, description: String, action_text: String, action: Callable, tone: Color = Palette.BUTTON_GREEN, enabled: bool = true) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.card(Palette.CREAM, Palette.PANEL_EDGE))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 20)
	panel.add_child(line)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	line.add_child(texts)
	var heading := UiStyle.heading(title, 42, Palette.INK, Color(0, 0, 0, 0))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(heading)
	if not description.is_empty():
		var body := UiStyle.body(description, 28)
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		body.custom_minimum_size = Vector2(480, 0)
		texts.add_child(body)
	var button := Button.new()
	button.text = action_text
	button.custom_minimum_size = Vector2(250, 110)
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not enabled
	button.add_theme_font_size_override("font_size", 34)
	UiStyle.tint_button(button, tone, tone.darkened(0.3))
	button.pressed.connect(action)
	line.add_child(button)
	return panel
