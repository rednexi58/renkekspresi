class_name DialogOverlay
extends Control
## Reusable modal card: dimmed backdrop, title, message and a column of candy buttons.
## Used for pause, win and loss now and for every menu later, so all dialogs share one
## look, one entrance animation and one input-blocking behaviour.

signal closed

enum Tone { PRIMARY, BLUE, GREEN }

const CARD_WIDTH := 860.0
const ENTER_SECONDS := 0.22

var _card: PanelContainer
var _content: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiStyle.theme()
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.1, 0.25, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	centre.add_child(_card)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 26)
	_card.add_child(_content)


## Shows the dialog. `buttons` is a list of [text, Tone, Callable]; the callable runs
## after the dialog closes.
func present(title: String, message: String, buttons: Array, title_color: Color = Palette.GOLD) -> void:
	for child in _content.get_children():
		child.queue_free()
	_content.add_child(UiStyle.heading(title, 74, title_color, Palette.INK))
	if not message.is_empty():
		var body := UiStyle.body(message, 38)
		body.custom_minimum_size = Vector2(CARD_WIDTH - 90.0, 0)
		_content.add_child(body)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	_content.add_child(spacer)
	for entry: Array in buttons:
		_content.add_child(_make_button(entry[0], entry[1], entry[2]))
	visible = true
	_card.pivot_offset = Vector2(CARD_WIDTH * 0.5, 300.0)
	_card.scale = Vector2.ONE * 0.85
	modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, ENTER_SECONDS)
	tween.tween_property(_card, "scale", Vector2.ONE, ENTER_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func dismiss() -> void:
	visible = false
	closed.emit()


func _make_button(text: String, tone: Tone, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 140)
	match tone:
		Tone.BLUE:
			UiStyle.tint_button(button, Palette.BUTTON_BLUE, Palette.BUTTON_BLUE_EDGE)
		Tone.GREEN:
			UiStyle.tint_button(button, Palette.BUTTON_GREEN, Palette.BUTTON_GREEN_EDGE)
	button.pressed.connect(func() -> void:
		dismiss()
		action.call())
	return button
