extends SceneTree
## Renders the App Store icon (1024x1024, opaque) from the game's own models, so the icon
## always matches the in-game look:
##   xvfb-run godot --path game --rendering-driver opengl3 --resolution 1024x1024 \
##     --script res://tools/render_icon.gd

const OUT := "res://assets/branding/app_icon_1024.png"
const BACKGROUND := Color("8fd66a")

var _frames := 0
var _viewport: SubViewport


func _initialize() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1024, 1024)
	_viewport.msaa_3d = Viewport.MSAA_8X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var models := ModelLibrary.new()
	var world := Node3D.new()
	_viewport.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("fff8f0")
	environment.ambient_light_energy = 0.45
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.35
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	world.add_child(sun)
	models.shape_with(world, "box", Vector3(0.0, -0.5, 0.0), Vector3(60.0, 1.0, 60.0), models.flat_material(BACKGROUND), false)
	# A soft path under the train.
	models.shape_with(world, "box", Vector3(0.0, 0.01, 0.0), Vector3(2.2, 0.02, 30.0), models.flat_material(Palette.PATH), false).rotation.y = deg_to_rad(140.0)
	var train := Node3D.new()
	train.rotation.y = deg_to_rad(140.0)
	world.add_child(train)
	var engine := models.make_locomotive()
	engine.position = Vector3(0.0, 0.0, -1.6)
	train.add_child(engine)
	var colors := [0, 2, 1]
	for i in colors.size():
		var wagon := models.make_wagon(colors[i])
		wagon.position = Vector3(0.0, 0.0, 1.0 + i * 2.25)
		train.add_child(wagon)
	var camera := Camera3D.new()
	camera.fov = 38.0
	world.add_child(camera)
	camera.look_at_from_position(Vector3(4.2, 7.4, 4.6), Vector3(0.3, 0.2, -0.4), Vector3.UP)
	camera.current = true


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 30:
		return false
	var image := _viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	image.save_png(ProjectSettings.globalize_path(OUT))
	print("Saved ", OUT)
	return true
