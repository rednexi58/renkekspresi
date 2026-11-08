class_name TrainPreview
extends SubViewportContainer
## A live 3D turntable of a locomotive with two wagons, used by the garage so players
## see the livery they buy. Own World3D so it never shares lights or cameras with a
## level that may exist behind the menu.

const SPIN_SPEED := 0.45

var _turntable: Node3D
var _models := ModelLibrary.new()
var _skin := ""


func _init(preview_size: Vector2 = Vector2(900, 420)) -> void:
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
	plate.material_override = _models.material(Palette.PANEL_EDGE)
	plate.position.y = -0.14
	_turntable.add_child(plate)


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
		_turntable.add_child(car)


func _process(delta: float) -> void:
	_turntable.rotate_y(delta * SPIN_SPEED)
