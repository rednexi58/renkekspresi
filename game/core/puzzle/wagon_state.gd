class_name WagonState
extends RefCounted
## One wagon travelling on a lane. `distance` is measured along the lane's rail.

var id: int
var color: int
var lane: int
var distance: float


func _init(wagon_id: int, wagon_color: int, wagon_lane: int, start_distance: float) -> void:
	id = wagon_id
	color = wagon_color
	lane = wagon_lane
	distance = start_distance
