class_name CameraRig
extends Camera3D
## Orthographic camera looking down at a fixed pitch, as top casual puzzlers do: no
## perspective distortion, so pieces read as clean shapes and stay the same size wherever
## they are on the board.
##
## frame() fits the board and shelf into the lower screen area, then returns where the
## train scene must be placed (and how much it must be scaled) to fill the upper area.
## The board therefore always gets the same generous size, however large a level's route
## is, and the layout adapts to every aspect ratio and safe area.

const PITCH_DEGREES := 60.0
const DISTANCE := 60.0
const BOARD_FILL := 0.94
const SCENE_FILL := 0.94

var _shake := 0.0
var _base_position := Vector3.ZERO
var _pixels_per_unit := 1.0


func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	keep_aspect = Camera3D.KEEP_WIDTH
	near = 1.0
	far = 200.0


## Fits `board` (ground rectangle; heights up to `board_height`) into `board_target`,
## and returns the transform that maps the scene's local `scene_bounds` (ground
## rectangle, heights up to `scene_height`) into `scene_target`. Targets are in
## viewport pixels.
func frame(board: Rect2, board_height: float, board_target: Rect2, scene_bounds: Rect2, scene_height: float, scene_target: Rect2) -> Transform3D:
	var viewport_size := get_viewport().get_visible_rect().size
	var pitch := deg_to_rad(PITCH_DEGREES)
	var sin_p := sin(pitch)
	var cos_p := cos(pitch)
	_pixels_per_unit = minf(board_target.size.x * BOARD_FILL / board.size.x,
		board_target.size.y * BOARD_FILL / (board.size.y * sin_p + board_height * cos_p))
	size = viewport_size.x / _pixels_per_unit
	# Ground point that sits at the centre of the screen.
	var board_centre := board.get_center()
	var target_centre := board_target.get_center()
	var centre_x := board_centre.x - (target_centre.x - viewport_size.x * 0.5) / _pixels_per_unit
	var lift := board_height * 0.5 * cos_p
	var centre_z := board_centre.y - (target_centre.y - viewport_size.y * 0.5) / (sin_p * _pixels_per_unit) - lift / sin_p
	var view := Basis.from_euler(Vector3(-pitch, 0.0, 0.0))
	_base_position = Vector3(centre_x, 0.0, centre_z) - (-view.z) * DISTANCE
	transform = Transform3D(view, _base_position)
	# Scene placement: uniform scale into the free area above the shelf.
	var width_units := scene_target.size.x * SCENE_FILL / _pixels_per_unit
	var depth_units := scene_target.size.y * SCENE_FILL / (sin_p * _pixels_per_unit)
	var factor := minf(width_units / scene_bounds.size.x, depth_units / (scene_bounds.size.y + scene_height * cos_p / sin_p))
	var scene_centre := scene_target.get_center()
	var ground_x := centre_x + (scene_centre.x - viewport_size.x * 0.5) / _pixels_per_unit
	var ground_z := centre_z + (scene_centre.y - viewport_size.y * 0.5) / (sin_p * _pixels_per_unit) + scene_height * 0.5 * factor * cos_p / sin_p
	var local_centre := scene_bounds.get_center()
	return Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * factor), Vector3(ground_x - local_centre.x * factor, 0.0, ground_z - local_centre.y * factor))


## Ground-plane Z that appears at screen row `y` (used to size background planes).
func ground_z_at_screen_y(y: float) -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	var pitch := deg_to_rad(PITCH_DEGREES)
	var centre := _base_position + (-transform.basis.z) * DISTANCE
	return centre.z + (y - viewport_size.y * 0.5) / (sin(pitch) * _pixels_per_unit)


func shake(strength: float = 0.35) -> void:
	_shake = strength


func _process(delta: float) -> void:
	if _shake <= 0.0:
		return
	_shake = maxf(0.0, _shake - delta * 1.2)
	position = _base_position + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake * 0.3
	if _shake == 0.0:
		position = _base_position
