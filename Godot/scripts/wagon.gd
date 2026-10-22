class_name Wagon
extends Node3D
var color_id: int = 0
var wagon_id: int = -1
var distance: float = 0.0
var wheels: Array = []

func setup(id: int) -> void:
	color_id = id
	var names = ["WagonRed","WagonBlue","WagonYellow","WagonGreen","WagonPurple"]
	var path = "res://scenes/models/"+names[id]+".tscn"
	add_child(MeshFactory.rail_model(id))
	_collect_wheels(self)

func _collect_wheels(node: Node) -> void:
	for child in node.get_children():
		if child.is_in_group("train_wheels"):
			wheels.append(child)
		_collect_wheels(child)

func roll(delta_distance: float) -> void:
	for wheel in wheels:
		wheel.rotate_object_local(Vector3.UP,delta_distance/.19)

