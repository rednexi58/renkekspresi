class_name SceneStage
extends SubViewportContainer
## The train scene rendered in its own viewport in the upper part of the screen.
##
## A separate viewport gives the scene its own camera (a fixed one showing the whole map)
## without affecting the board, and clips the scene cleanly at its edge, so decoration can
## never spill over the shelf. Positions needed by cross-screen effects are reported in screen
## coordinates.

var _viewport: SubViewport
var _world: Node3D
var _scene: SceneView
var _train: TrainView
var _camera: SceneCamera
var _covered := 0.0
var _engine: PuzzleEngine


func setup(models: ModelLibrary, level: LevelDefinition, routes: Array[RailRoute], engine: PuzzleEngine, skin_id: String) -> void:
	_engine = engine
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	var theme_id := Season.theme_for(level)
	_add_environment(theme_id)
	var ground := models.shape_with(_world, "box", Vector3(0.0, -0.55, 0.0), Vector3(400.0, 1.0, 400.0), models.ground(Palette.scene_ground(theme_id)), false)
	ground.name = "Ground"
	_scene = SceneView.new()
	_scene.name = "Scene"
	_world.add_child(_scene)
	_scene.setup(models, level, routes, engine, theme_id)
	_train = TrainView.new()
	_train.name = "Train"
	_scene.add_child(_train)
	_train.setup(models, routes, engine, skin_id)
	_camera = SceneCamera.new()
	_world.add_child(_camera)
	_camera.make_current()
	_camera.set_bounds(_track_bounds(routes))
	if Season.is_winter(level.id - 1):
		_add_snowfall(_track_bounds(routes).grow(6.0))


## Gentle snowfall over the whole map in winter levels: small white flakes drifting down
## and sideways, unshaded so they read as light against any ground.
func _add_snowfall(area: Rect2) -> void:
	var snow := CPUParticles3D.new()
	snow.name = "Snowfall"
	snow.amount = 260
	snow.lifetime = 7.0
	snow.preprocess = 7.0
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(area.size.x * 0.5, 0.5, area.size.y * 0.5)
	snow.position = Vector3(area.get_center().x, 9.0, area.get_center().y)
	snow.direction = Vector3(0.3, -1.0, 0.1)
	snow.spread = 12.0
	snow.gravity = Vector3.ZERO
	snow.initial_velocity_min = 1.0
	snow.initial_velocity_max = 1.8
	snow.scale_amount_min = 0.08
	snow.scale_amount_max = 0.17
	var flake := SphereMesh.new()
	flake.radius = 1.0
	flake.height = 2.0
	flake.radial_segments = 6
	flake.rings = 3
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
	white.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flake.material = white
	snow.mesh = flake
	_world.add_child(snow)


## Ground area of every track, the part of the map the player must see.
static func _track_bounds(routes: Array[RailRoute]) -> Rect2:
	var bounds := routes[0].bounds()
	for route in routes:
		bounds = bounds.merge(route.bounds())
	return bounds


## Screen height the whole map needs at `width_px` (used to share the screen with the board).
func preferred_height(width_px: float) -> float:
	return _camera.preferred_height(width_px)


func _add_environment(theme_id: int) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Palette.scene_ground(theme_id)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("fff8f0")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_world.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("fff3e0")
	sun.light_energy = 0.62
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.45
	sun.shadow_blur = 2.0
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	# From the right and a little behind the camera: shadows fall to the left of things,
	# where this camera can see them, and the sides facing the player stay lit.
	sun.rotation_degrees = Vector3(-58.0, 62.0, 0.0)
	_world.add_child(sun)


## Places the stage on screen (root canvas coordinates); its top `covered_px` rows are
## under the HUD, so the map is fitted below them.
func place(rect: Rect2, covered_px: float) -> void:
	position = rect.position
	size = rect.size
	_covered = covered_px
	_camera.fit(rect.size, covered_px)


func sync(engine: PuzzleEngine) -> void:
	_train.sync(engine)
	var zones := _scene.loading_zones()
	for lane in zones.size():
		zones[lane].visible = (engine.opened[lane] or engine.tuning.collect_before_open) and engine.has_lane(lane)


func _process(delta: float) -> void:
	if _scene != null:
		_scene.pulse_zones(delta)


## Screen position (root canvas coordinates) of a wagon about to be collected.
func wagon_screen_position(lane: int, distance: float) -> Vector2:
	var world_point := _train.wagon_position(lane, distance)
	var local := _camera.unproject_position(world_point)
	return position + local * (size / Vector2(_viewport.size))


func remove_wagon(wagon_id: int) -> void:
	_train.remove_wagon(wagon_id)


func shake(strength: float) -> void:
	_camera.shake(strength)
