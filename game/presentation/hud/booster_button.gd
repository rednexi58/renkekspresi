class_name BoosterButton
extends Button
## A booster: big icon, name underneath and a count bubble in the corner. The look is
## drawn by child nodes so the theme's text styling does not apply; the Button itself
## only provides press handling and accessibility focus.

const ICON_SIZE := 150.0

var _icon: TextureRect
var _name: Label
var _count: Label
var _bubble: PanelContainer


func setup(texture: Texture2D) -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(210, 220)
	_icon = TextureRect.new()
	_icon.texture = texture
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.position = Vector2((custom_minimum_size.x - ICON_SIZE) * 0.5, 0.0)
	_icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	add_child(_icon)
	_name = UiStyle.heading("", 36)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.position = Vector2(0, ICON_SIZE + 4.0)
	_name.size = Vector2(210, 52)
	add_child(_name)
	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", UiStyle.pill(Palette.DANGER, Palette.DANGER.darkened(0.3)))
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.position = Vector2(150, -10)
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
	_icon.modulate = Color.WHITE if uses > 0 else Color(1, 1, 1, 0.45)
	disabled = not enabled
