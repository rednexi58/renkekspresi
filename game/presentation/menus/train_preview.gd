class_name TrainPreview
extends SubViewportContainer
## A live 3D turntable of a locomotive with two wagons, used by the garage so players
## see the livery they buy, and (as a snowy diorama with pines and falling snow) as the
## home screen's hero. Own World3D so it never shares lights or cameras with a
## level that may exist behind the menu.

const SPIN_SPEED := 0.45

var _turntable: Node3D
var _models := ModelLibrary.new()
var _skin := ""
var _car_scale := 1.0


func _init(preview_size: Vector2 = Vector2(900, 420), diorama: bool = false) -> void:
	custom_minimum_size = preview_size
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("fff8f0")
	environment.ambient_light_energy = 0.45
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	viewport.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.4
	camera.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 6.0, 8.0)).looking_at(Vector3(0.0, 0.4, 0.0))
	viewport.add_child(camera)
	_turntable = Node3D.new()
	viewport.add_child(_turntable)
	var plate := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 3.0
	disc.bottom_radius = 3.15
	disc.height = 0.25
	plate.mesh = disc
	plate.material_override = _models.material(Palette.SNOW if diorama else Palette.PANEL_EDGE)
	plate.position.y = -0.14
	_turntable.add_child(plate)
	if diorama:
		_add_diorama(viewport)


## Snowy pines around the rim, a ring of track under the train, and gentle snowfall.
func _add_diorama(viewport: SubViewport) -> void:
	for i in 7:
		var angle := TAU * i / 7.0 + 0.3
		var pine := Node3D.new()
		pine.position = Vector3(cos(angle) * 2.6, 0.0, sin(angle) * 2.6)
		pine.scale = Vector3.ONE * (0.55 + 0.1 * (i % 3))
		_turntable.add_child(pine)
		_models.shape(pine, "cylinder", Vector3(0.0, 0.25, 0.0), Vector3(0.18, 0.5, 0.18), Color("8a5a3c"))
		for layer in 3:
			var width := 1.3 - layer * 0.33
			_models.shape(pine, "cone", Vector3(0.0, 0.65 + layer * 0.42, 0.0), Vector3(width, 0.8, width), Color("3f9e5a").lightened(layer * 0.07))
			_models.shape(pine, "cone", Vector3(0.0, 0.86 + layer * 0.42, 0.0), Vector3(width * 0.6, 0.36, width * 0.6), Palette.SNOW, false)
	var snow := CPUParticles3D.new()
	snow.amount = 90
	snow.lifetime = 5.0
	snow.preprocess = 5.0
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(4.5, 0.2, 4.5)
	snow.position = Vector3(0.0, 5.0, 0.0)
	snow.direction = Vector3(0.2, -1.0, 0.0)
	snow.gravity = Vector3.ZERO
	snow.initial_velocity_min = 0.8
	snow.initial_velocity_max = 1.3
	snow.scale_amount_min = 0.05
	snow.scale_amount_max = 0.1
	var flake := SphereMesh.new()
	flake.radial_segments = 6
	flake.rings = 3
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flake.material = white
	snow.mesh = flake
	viewport.add_child(snow)


func show_skin(skin_id: String) -> void:
	if skin_id == _skin:
		return
	_skin = skin_id
	for child in _turntable.get_children():
		if child.name.begins_with("Car"):
			child.queue_free()
	var cars: Array[MeshInstance3D] = [_models.make_locomotive(skin_id), _models.make_wagon(0), _models.make_wagon(3)]
	for i in cars.size():
		var car := cars[i]
		car.name = "Car%d" % i
		car.position = Vector3(0.0, 0.0, (i - 1) * (WagonModels.LENGTH + 0.12))
		car.scale = Vector3.ONE * _car_scale
		_turntable.add_child(car)


func _process(delta: float) -> void:
	_turntable.rotate_y(delta * SPIN_SPEED)
