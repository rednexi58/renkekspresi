class_name WorldLabels
extends RefCounted
## Factory for markings drawn in the 3D world: arrows painted on wagon roofs, round
## capacity plates and floating key badges. Centralised so every marking shares one
## font, outline style and draw order.

const FONT := preload("res://assets/fonts/Poppins-Bold.ttf")
const PLATE_RADIUS := 0.31

static var _arrow_meshes := {}
static var _disc_meshes := {}


## Billboarded text that stays readable over any background (used for key badges).
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


## Text lying flat on a surface, upright when seen from the camera (which looks toward
## -Z), like lettering painted on a roof.
static func painted_text(text: String, font_size: int, color: Color) -> Label3D:
	var made := Label3D.new()
	made.text = text
	made.font = FONT
	made.font_size = font_size
	made.outline_size = 0
	made.modulate = color
	made.pixel_size = 0.004
	made.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	made.double_sided = false
	made.render_priority = 3
	return made


## Round white plate with a dark rim and a number, lying flat. Returns the label so the
## caller can update the number.
static func capacity_plate(parent: Node3D, models: ModelLibrary, position: Vector3, text: String) -> Label3D:
	var rim := MeshInstance3D.new()
	rim.mesh = _disc(PLATE_RADIUS)
	rim.material_override = models.flat_material(Palette.INK)
	rim.position = position
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(rim)
	var face := MeshInstance3D.new()
	face.mesh = _disc(PLATE_RADIUS * 0.84)
	face.material_override = models.flat_material(Palette.WHITE)
	face.position = position + Vector3.UP * 0.004
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(face)
	var number := painted_text(text, 96, Palette.INK)
	number.position = position + Vector3.UP * 0.008
	parent.add_child(number)
	return number


## Flat arrow pointing along local -Z in the XZ plane, `length` long, cached by size.
static func arrow_mesh(length: float, width: float) -> ArrayMesh:
	var key := "%.3f|%.3f" % [length, width]
	if _arrow_meshes.has(key):
		return _arrow_meshes[key]
	var half := width * 0.5
	var head := length * 0.48
	var shaft_half := width * 0.2
	var tip := -length * 0.5
	var back := length * 0.5
	var neck := tip + head
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	for v in [Vector3(0.0, 0.0, tip), Vector3(half, 0.0, neck), Vector3(-half, 0.0, neck),
			Vector3(-shaft_half, 0.0, neck), Vector3(shaft_half, 0.0, neck), Vector3(shaft_half, 0.0, back),
			Vector3(-shaft_half, 0.0, neck), Vector3(shaft_half, 0.0, back), Vector3(-shaft_half, 0.0, back)]:
		tool.add_vertex(v)
	var mesh := tool.commit()
	_arrow_meshes[key] = mesh
	return mesh


static func _disc(radius: float) -> ArrayMesh:
	var key := "%.3f" % radius
	if _disc_meshes.has(key):
		return _disc_meshes[key]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	var sides := 28
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		tool.add_vertex(Vector3.ZERO)
		tool.add_vertex(Vector3(cos(a1), 0.0, sin(a1)) * radius)
		tool.add_vertex(Vector3(cos(a0), 0.0, sin(a0)) * radius)
	var mesh := tool.commit()
	_disc_meshes[key] = mesh
	return mesh
