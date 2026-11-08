class_name ModelLibrary
extends RefCounted
## Creates every 3D visual from shared meshes and cached materials.
##
## One instance is created per level world and passed to each builder (dependency
## injection instead of a global), so builders never construct materials themselves and
## identical materials are shared, which keeps batching effective. Surface textures
## (grass, gravel, wood, concrete) are generated from noise at runtime: no image assets
## to license or ship, and every theme can recolour them.

const TEXTURE_SIZE := 512

var _materials := {}
var _primitive_meshes := {}


## Lit painted material, cached by colour and finish.
func material(color: Color, roughness: float = 0.6, metallic: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [color.to_html(), roughness, metallic, emission]
	if _materials.has(key):
		return _materials[key]
	var made := StandardMaterial3D.new()
	made.albedo_color = color
	made.roughness = roughness
	made.metallic = metallic
	made.metallic_specular = 0.5
	if emission > 0.0:
		made.emission_enabled = true
		made.emission = color
		made.emission_energy_multiplier = emission
	_materials[key] = made
	return made


## Unshaded material for markers (arrows, highlights) that must read the same in any light.
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


## Noise-textured surface projected in world space (triplanar), so large and small
## objects share a consistent texel density without UVs.
## `colors` are the gradient stops from dark to light; `frequency` controls grain.
func textured(name: String, colors: PackedColorArray, frequency: float, scale: float, roughness: float = 0.95, cellular: bool = false) -> StandardMaterial3D:
	var key := "tex|%s|%s|%.3f|%.2f" % [name, colors, frequency, scale]
	if _materials.has(key):
		return _materials[key]
	var noise := FastNoiseLite.new()
	noise.seed = hash(name)
	noise.frequency = frequency
	noise.fractal_octaves = 4
	if cellular:
		noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	else:
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var ramp := Gradient.new()
	var offsets := PackedFloat32Array()
	for i in colors.size():
		offsets.append(float(i) / maxf(1.0, colors.size() - 1))
	ramp.offsets = offsets
	ramp.colors = colors
	var texture := NoiseTexture2D.new()
	texture.width = TEXTURE_SIZE
	texture.height = TEXTURE_SIZE
	texture.seamless = true
	texture.noise = noise
	texture.color_ramp = ramp
	var made := StandardMaterial3D.new()
	made.albedo_texture = texture
	made.uv1_triplanar = true
	made.uv1_world_triplanar = true
	made.uv1_scale = Vector3.ONE * scale
	made.roughness = roughness
	made.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials[key] = made
	return made


## Large flat backgrounds (grass, board floor, path) are unshaded so they show exactly
## their palette colour on every device; contact shadows still darken them locally.
func ground(base: Color) -> StandardMaterial3D:
	var made := textured("ground", PackedColorArray([base.darkened(0.05), base, base.lightened(0.04), base]), 0.05, 0.08, 1.0)
	made.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return made


## Painted wooden panels: the colour is given, the plank grooves come from a generated
## normal map so the surface catches light like a real painted wagon.
func painted(color: Color, roughness: float = 0.5) -> StandardMaterial3D:
	var key := "painted|%s|%.2f" % [color.to_html(), roughness]
	if _materials.has(key):
		return _materials[key]
	var made := StandardMaterial3D.new()
	made.albedo_color = color
	made.roughness = roughness
	made.metallic_specular = 0.55
	made.normal_enabled = true
	made.normal_texture = _plank_normals()
	made.normal_scale = 0.35
	made.uv1_triplanar = true
	made.uv1_scale = Vector3.ONE * 1.4
	_materials[key] = made
	return made


func _plank_normals() -> Texture2D:
	if _materials.has("plank_normals"):
		return _materials["plank_normals"]
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.08
	for y in size:
		for x in size:
			var groove := 1.0
			var local := x % 32
			if local < 2:
				groove = 0.15 + local * 0.2
			var grain := noise.get_noise_2d(x * 0.3, y * 4.0) * 0.08
			var v := clampf(groove * 0.85 + grain + 0.1, 0.0, 1.0)
			image.set_pixel(x, y, Color(v, v, v))
	image.bump_map_to_normal_map(3.0)
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_materials["plank_normals"] = texture
	return texture


func _role_material(role: String, paint: Color) -> Material:
	match role:
		"paint":
			return painted(paint, 0.45)
		"roof":
			return painted(paint.lightened(0.16), 0.5)
		"trim":
			return material(paint.darkened(0.22), 0.5)
		"chassis":
			return material(Palette.CHASSIS, 0.65)
		"wheel":
			return material(Palette.WHEEL, 0.5, 0.2)
		"hub":
			return material(Palette.HUB, 0.3, 0.6)
		"engine":
			return material(Palette.ENGINE_BODY, 0.4)
		"cab":
			return material(Palette.ENGINE_CAB, 0.45)
		"brass":
			return material(Palette.BRASS, 0.3, 0.6)
		"lamp":
			return material(Palette.LAMP, 0.3, 0.0, 0.9)
	return material(paint)


func _dress(mesh: ArrayMesh, paint: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	for i in mesh.get_surface_count():
		instance.set_surface_override_material(i, _role_material(mesh.surface_get_name(i), paint))
	return instance


func make_wagon(color_id: int) -> MeshInstance3D:
	var wagon := _dress(WagonModels.wagon(), Palette.wagon(color_id))
	wagon.name = "Wagon"
	return wagon


## Locomotive in the given garage livery (see Palette.LOCOMOTIVE_SKINS).
func make_locomotive(skin_id: String = "classic") -> MeshInstance3D:
	var livery := Palette.skin(skin_id)
	var mesh := WagonModels.locomotive()
	var engine := MeshInstance3D.new()
	engine.mesh = mesh
	engine.name = "Locomotive"
	for i in mesh.get_surface_count():
		var role := mesh.surface_get_name(i)
		var mat: Material
		match role:
			"engine":
				mat = material(livery["body"], 0.4)
			"cab":
				mat = material(livery["cab"], 0.45)
			"brass":
				mat = material(livery["trim"], 0.3, 0.6)
			_:
				mat = _role_material(role, livery["body"])
		engine.set_surface_override_material(i, mat)
	return engine


## Soft round contact shadow laid on the ground. Directional shadows alone leave objects
## looking pasted on; this darkening where they touch the ground grounds them.
func contact_shadow(parent: Node3D, position: Vector3, size: Vector2, strength: float = 0.4) -> MeshInstance3D:
	var key := "contact|%.2f" % strength
	if not _materials.has(key):
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		gradient.colors = PackedColorArray([Color(0, 0, 0, strength), Color(0, 0, 0, strength * 0.45), Color(0, 0, 0, 0)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 64
		texture.height = 64
		var made := StandardMaterial3D.new()
		made.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		made.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		made.albedo_texture = texture
		made.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_materials[key] = made
	if not _primitive_meshes.has("ground_quad"):
		var quad := PlaneMesh.new()
		quad.size = Vector2.ONE
		_primitive_meshes["ground_quad"] = quad
	var shadow := MeshInstance3D.new()
	shadow.mesh = _primitive_meshes["ground_quad"]
	shadow.material_override = _materials[key]
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.position = position
	shadow.scale = Vector3(size.x, 1.0, size.y)
	parent.add_child(shadow)
	return shadow


## Shared primitive meshes (unit sized) so scenery instances reuse geometry.
func primitive(kind: String) -> Mesh:
	if _primitive_meshes.has(kind):
		return _primitive_meshes[kind]
	var mesh: Mesh
	match kind:
		"box":
			mesh = BoxMesh.new()
		"rounded_box":
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			MeshKit.rounded_box(tool, Vector3.ONE, 0.08, Transform3D.IDENTITY, 2)
			mesh = tool.commit()
		"sphere":
			var sphere := SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 1.0
			sphere.radial_segments = 14
			sphere.rings = 7
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
			cylinder.radial_segments = 12
			mesh = cylinder
		"cone":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.5
			cone.height = 1.0
			cone.radial_segments = 9
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


## A primitive placed under `parent` with a given material.
func shape_with(parent: Node3D, kind: String, position: Vector3, size: Vector3, mat: Material, cast_shadow: bool = true) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = primitive(kind)
	instance.material_override = mat
	instance.position = position
	instance.scale = size
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


## A coloured primitive placed under `parent`.
func shape(parent: Node3D, kind: String, position: Vector3, size: Vector3, color: Color, cast_shadow: bool = true) -> MeshInstance3D:
	return shape_with(parent, kind, position, size, material(color), cast_shadow)
