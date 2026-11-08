class_name WorldLabels
extends RefCounted
## Factory for text and marker shapes drawn in the 3D world (capacity numbers, key
## badges, direction arrows). Centralised so every in-world label shares one font,
## outline style and draw order.

const FONT := preload("res://assets/fonts/Poppins-Bold.ttf")


## Billboarded number/letter that stays readable over any background and is never
## hidden by the train or scenery (no depth test, high render priority).
static func label(text: String, font_size: int, color: Color, outline: Color = Palette.INK) -> Label3D:
	var made := Label3D.new()
	made.text = text
	made.font = FONT
	made.font_size = font_size
	made.outline_size = maxi(8, int(font_size * 0.28))
	made.modulate = color
	made.outline_modulate = outline
	made.pixel_size = 0.01
	made.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	made.no_depth_test = true
	made.render_priority = 10
	made.outline_render_priority = 9
	made.double_sided = true
	return made


## Flat arrow pointing along local -Z, lying in the XZ plane, `length` long.
static func arrow_mesh(length: float, width: float) -> ArrayMesh:
	var half := width * 0.5
	var head := length * 0.45
	var shaft_half := width * 0.22
	var tip := -length * 0.5
	var back := length * 0.5
	var neck := tip + head
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	# Head (clockwise from above = front face in Godot).
	for v in [Vector3(0.0, 0.0, tip), Vector3(half, 0.0, neck), Vector3(-half, 0.0, neck)]:
		tool.add_vertex(v)
	# Shaft as two triangles.
	for v in [Vector3(-shaft_half, 0.0, neck), Vector3(shaft_half, 0.0, neck), Vector3(shaft_half, 0.0, back),
			Vector3(-shaft_half, 0.0, neck), Vector3(shaft_half, 0.0, back), Vector3(-shaft_half, 0.0, back)]:
		tool.add_vertex(v)
	return tool.commit()
