class_name ModelLibrary
extends RefCounted
## Creates every 3D visual from shared meshes and cached materials.
##
## One instance is created per level world and passed to each builder (dependency
## injection instead of a global), so builders never construct materials themselves and
## identical colours share one material, which keeps draw-call batching effective.

const WAGON_MESH := preload("res://assets/models/wagon.res")
const LOCOMOTIVE_MESH := preload("res://assets/models/locomotive.res")

var _materials := {}
var _primitive_meshes := {}


## Lit, slightly glossy toy-plastic material, cached by colour and finish.
func material(color: Color, roughness: float = 0.55, metallic: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [color.to_html(), roughness, metallic, emission]
	if _materials.has(key):
		return _materials[key]
	var made := StandardMaterial3D.new()
	made.albedo_color = color
	made.roughness = roughness
	made.metallic = metallic
	made.metallic_specular = 0.45
	if emission > 0.0:
		made.emission_enabled = true
		made.emission = color
		made.emission_energy_multiplier = emission
	_materials[key] = made
	return made


## Unshaded material for UI-like world markers (arrows, highlights) that must read
## identically regardless of lighting.
func flat_material(color: Color, transparent: bool = false) -> StandardMaterial3D:
	var key := "flat|%s|%s" % [color.to_html(), transparent]
	if _materials.has(key):
		return _materials[key]
	var made := StandardMaterial3D.new()
	made.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	made.albedo_color = color
	made.cull_mode = BaseMaterial3D.CULL_DISABLED
	if transparent:
		made.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materials[key] = made
	return made


func _role_material(role: String, paint: Color) -> Material:
	match role:
		"paint":
			# A touch of self-illumination keeps the five puzzle colours vivid on the
			# shaded side too; colour identity matters more than physical accuracy here.
			return material(paint, 0.38, 0.0, 0.12)
		"chassis":
			return material(Palette.CHASSIS, 0.6)
		"steel":
			return material(Palette.STEEL, 0.35, 0.35)
		"brass":
			return material(Palette.BRASS, 0.3, 0.4)
		"glass":
			return material(Palette.GLASS, 0.15)
		"lamp":
			return material(Palette.LAMP, 0.3, 0.0, 0.6)
		"cream":
			return material(Palette.TRAIN_CREAM, 0.5)
		"accent":
			return material(Palette.ENGINE_ACCENT, 0.4)
	return material(paint)


func _dress(mesh: ArrayMesh, paint: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	for i in mesh.get_surface_count():
		instance.set_surface_override_material(i, _role_material(mesh.surface_get_name(i), paint))
	return instance


func make_wagon(color_id: int) -> MeshInstance3D:
	var wagon := _dress(WAGON_MESH, Palette.wagon(color_id))
	wagon.name = "Wagon"
	return wagon


func make_locomotive() -> MeshInstance3D:
	var engine := _dress(LOCOMOTIVE_MESH, Palette.ENGINE_BODY)
	engine.name = "Locomotive"
	# The source engine body is the dark "chassis" role; repaint it in the brand red so
	# the locomotive reads as the hero piece, keeping wheels and frame dark via steel.
	for i in LOCOMOTIVE_MESH.get_surface_count():
		if LOCOMOTIVE_MESH.surface_get_name(i) == "chassis":
			engine.set_surface_override_material(i, material(Palette.ENGINE_BODY, 0.38))
	return engine


## Shared primitive meshes (unit sized) so scenery instances reuse geometry.
func primitive(kind: String) -> Mesh:
	if _primitive_meshes.has(kind):
		return _primitive_meshes[kind]
	var mesh: Mesh
	match kind:
		"box":
			mesh = BoxMesh.new()
		"sphere":
			var sphere := SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 1.0
			sphere.radial_segments = 16
			sphere.rings = 8
			mesh = sphere
		"low_sphere":
			var rock := SphereMesh.new()
			rock.radius = 0.5
			rock.height = 1.0
			rock.radial_segments = 7
			rock.rings = 4
			mesh = rock
		"cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.5
			cylinder.bottom_radius = 0.5
			cylinder.height = 1.0
			cylinder.radial_segments = 14
			mesh = cylinder
		"cone":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.5
			cone.height = 1.0
			cone.radial_segments = 12
			mesh = cone
		"prism":
			mesh = PrismMesh.new()
		"capsule":
			var capsule := CapsuleMesh.new()
			capsule.radius = 0.5
			capsule.height = 1.0
			mesh = capsule
		_:
			push_error("Unknown primitive: " + kind)
			mesh = BoxMesh.new()
	_primitive_meshes[kind] = mesh
	return mesh


## A coloured primitive placed under `parent`. Shadows are cast unless disabled.
func shape(parent: Node3D, kind: String, position: Vector3, size: Vector3, color: Color, cast_shadow: bool = true) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = primitive(kind)
	instance.material_override = material(color)
	instance.position = position
	instance.scale = size
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance
