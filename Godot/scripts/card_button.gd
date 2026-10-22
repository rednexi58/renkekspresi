class_name WagonCard
extends Button
var color_id: int = -1
var card_index: int = 0
static var thumbnails: Array = []

func _ready() -> void:
	custom_minimum_size = Vector2(0,150)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	resized.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	if thumbnails.is_empty():
		for i in range(5):
			thumbnails.append(load("res://assets/cards/wagon_%d.png" % i))

func set_color(id: int) -> void:
	color_id = id
	disabled = id < 0
	tooltip_text = "" if id < 0 else "%s vagonu gönder · %d" % [TrainPalette.NAMES[id],card_index+1]
	queue_redraw()

func _draw() -> void:
	var color = Color("d5dfd9") if color_id < 0 else TrainPalette.color(color_id)
	var panel = StyleBoxFlat.new()
	panel.bg_color = Color("fcfdf8") if color_id >= 0 else Color("e9eee7")
	panel.set_corner_radius_all(22)
	panel.set_border_width_all(2)
	panel.border_color = color.lightened(.55)
	panel.shadow_color = Color(.1,.18,.16,.12)
	panel.shadow_size = 5
	panel.shadow_offset = Vector2(0,5)
	var rise = -3.0 if is_hovered() and not disabled else 0.0
	draw_style_box(panel,Rect2(Vector2(3,3+rise),size-Vector2(6,11)))
	if color_id < 0:
		var font = get_theme_font("font")
		var text = "TAMAMLANDI"
		var width = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
		draw_string(font,Vector2((size.x-width)/2,size.y/2),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,TrainPalette.MUTED)
		return
	var inset = StyleBoxFlat.new()
	inset.bg_color = color.lightened(.9)
	inset.set_corner_radius_all(16)
	draw_style_box(inset,Rect2(Vector2(11,11+rise),Vector2(size.x-22,94)))
	# The thumbnail is an orthographic render of the same editable 3D wagon used on the track.
	draw_set_transform(Vector2(size.x/2,85+rise),0,Vector2(1,.17))
	draw_circle(Vector2.ZERO,size.x*.29,Color(.14,.23,.23,.13))
	draw_set_transform(Vector2.ZERO)
	if color_id < thumbnails.size() and thumbnails[color_id]:
		draw_texture_rect(thumbnails[color_id],Rect2(Vector2(10,3+rise),Vector2(size.x-20,110)),false)
	var font = get_theme_font("font")
	var text = TrainPalette.NAMES[color_id]
	var width = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x
	draw_circle(Vector2((size.x-width)/2-15,126+rise),4.5,color)
	draw_string(font,Vector2((size.x-width)/2-3,133+rise),text,HORIZONTAL_ALIGNMENT_LEFT,-1,20,TrainPalette.INK)
	if has_focus():
		var focus = StyleBoxFlat.new()
		focus.bg_color = Color.TRANSPARENT
		focus.set_corner_radius_all(22)
		focus.set_border_width_all(3)
		focus.border_color = TrainPalette.DARK
		draw_style_box(focus,Rect2(3,3,size.x-6,size.y-11))
