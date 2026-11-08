class_name BoosterButton
extends Button
## A booster: icon inside a golden frame, outlined name underneath and a count bubble in
## the corner. The look is drawn by child nodes; the Button itself provides press
## handling, the pressed "squash" and disabled state.

const FRAME_SIZE := 176.0

var _frame: Panel
var _icon: TextureRect
var _name: Label
var _count: Label
var _bubble: PanelContainer


func setup(texture: Texture2D) -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(FRAME_SIZE + 20.0, FRAME_SIZE + 64.0)
	_frame = Panel.new()
	_frame.add_theme_stylebox_override("panel", UiStyle.gold_frame())
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.position = Vector2(10, 0)
	_frame.size = Vector2(FRAME_SIZE, FRAME_SIZE)
	add_child(_frame)
	_icon = TextureRect.new()
	_icon.texture = texture
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.position = Vector2(10 + 18, 14)
	_icon.size = Vector2(FRAME_SIZE - 36, FRAME_SIZE - 36)
	add_child(_icon)
	_name = UiStyle.heading("", 34, Palette.WHITE, Palette.INK)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.position = Vector2(-10, FRAME_SIZE - 4)
	_name.size = Vector2(FRAME_SIZE + 40, 60)
	add_child(_name)
	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", UiStyle.pill(Palette.SUCCESS, Palette.SUCCESS.darkened(0.3)))
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.position = Vector2(FRAME_SIZE - 34, -18)
	add_child(_bubble)
	_count = UiStyle.heading("", 30, Palette.WHITE, Color(0, 0, 0, 0))
	_bubble.add_child(_count)
	pivot_offset = custom_minimum_size * 0.5
	button_down.connect(func() -> void: scale = Vector2.ONE * 0.92)
	button_up.connect(func() -> void: scale = Vector2.ONE)


func show_state(title: String, uses: int, enabled: bool) -> void:
	_name.text = title
	_count.text = str(uses)
	_bubble.visible = uses > 0
	_icon.modulate = Color.WHITE if uses > 0 else Color(1, 1, 1, 0.5)
	disabled = not enabled
