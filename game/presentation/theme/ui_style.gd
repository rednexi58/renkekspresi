class_name UiStyle
extends RefCounted
## Builds every Control style: chunky "candy" buttons with a darker bottom lip that dips
## when pressed, rounded white cards, outlined headings. Centralised so all screens share
## one look and a restyle happens in one file.

const FONT_BOLD := preload("res://assets/fonts/Poppins-Bold.ttf")
const FONT_MEDIUM := preload("res://assets/fonts/Poppins-Medium.ttf")
const RADIUS := 34
const LIP := 12


static func theme() -> Theme:
	var made := Theme.new()
	made.default_font = FONT_BOLD
	made.default_font_size = 40
	made.set_color("font_color", "Label", Palette.INK)
	made.set_color("font_outline_color", "Label", Palette.INK)
	_apply_button(made, "Button", Palette.BUTTON_PRIMARY, Palette.BUTTON_PRIMARY_EDGE)
	made.set_stylebox("panel", "PanelContainer", card())
	return made


static func _apply_button(target: Theme, type_name: String, face: Color, edge: Color) -> void:
	target.set_stylebox("normal", type_name, button_box(face, edge, false))
	target.set_stylebox("hover", type_name, button_box(face.lightened(0.06), edge, false))
	target.set_stylebox("pressed", type_name, button_box(face.darkened(0.04), edge, true))
	target.set_stylebox("disabled", type_name, button_box(face.lerp(Color("c9cfdb"), 0.75), edge.lerp(Color("9aa3b5"), 0.75), false))
	target.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	target.set_color("font_color", type_name, Palette.WHITE)
	target.set_color("font_hover_color", type_name, Palette.WHITE)
	target.set_color("font_pressed_color", type_name, Palette.WHITE)
	target.set_color("font_disabled_color", type_name, Color(1, 1, 1, 0.7))
	target.set_color("font_outline_color", type_name, edge.darkened(0.25))
	target.set_constant("outline_size", type_name, 10)
	target.set_font_size("font_size", type_name, 44)


## Candy button face. The bottom border is the "lip"; pressing removes the lip and
## shifts the content down, which reads as the button physically going in.
static func button_box(face: Color, edge: Color, pressed: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = face
	box.border_color = edge
	box.set_corner_radius_all(RADIUS)
	box.border_width_bottom = 4 if pressed else LIP
	box.border_width_top = 0
	box.border_width_left = 0
	box.border_width_right = 0
	box.content_margin_left = 28
	box.content_margin_right = 28
	box.content_margin_top = 18 + (LIP - 4 if pressed else 0)
	box.content_margin_bottom = 18
	box.shadow_color = Color(0, 0, 0, 0.18)
	box.shadow_size = 0 if pressed else 6
	box.shadow_offset = Vector2(0, 6)
	box.anti_aliasing = true
	return box


static func card(fill: Color = Palette.PANEL, border: Color = Palette.PANEL_EDGE) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(0)
	box.border_width_bottom = 10
	box.set_corner_radius_all(RADIUS + 6)
	box.content_margin_left = 36
	box.content_margin_right = 36
	box.content_margin_top = 28
	box.content_margin_bottom = 32
	box.shadow_color = Color(0.05, 0.12, 0.3, 0.22)
	box.shadow_size = 18
	box.shadow_offset = Vector2(0, 10)
	box.anti_aliasing = true
	return box


## Dark translucent pill for short status text drawn over the 3D scene.
static func glass_pill() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.11, 0.2, 0.55)
	box.set_corner_radius_all(999)
	box.content_margin_left = 28
	box.content_margin_right = 28
	box.content_margin_top = 8
	box.content_margin_bottom = 10
	box.anti_aliasing = true
	return box


static func pill(fill: Color, border: Color) -> StyleBoxFlat:
	var box := card(fill, border)
	box.set_corner_radius_all(999)
	box.content_margin_left = 30
	box.content_margin_right = 30
	box.content_margin_top = 10
	box.content_margin_bottom = 14
	box.border_width_bottom = 6
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, 5)
	return box


## Applies a coloured candy style to one button (e.g. blue secondary, green confirm).
static func tint_button(button: Button, face: Color, edge: Color) -> void:
	button.add_theme_stylebox_override("normal", button_box(face, edge, false))
	button.add_theme_stylebox_override("hover", button_box(face.lightened(0.06), edge, false))
	button.add_theme_stylebox_override("pressed", button_box(face.darkened(0.04), edge, true))
	button.add_theme_color_override("font_outline_color", edge.darkened(0.25))


static func heading(text: String, size: int, color: Color = Palette.WHITE, outline: Color = Palette.INK) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT_BOLD)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline)
	label.add_theme_constant_override("outline_size", maxi(0, int(size * 0.22)) if outline.a > 0.0 else 0)
	return label


static func body(text: String, size: int, color: Color = Palette.INK_SOFT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", FONT_MEDIUM)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
