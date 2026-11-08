class_name CameraRig
extends Camera3D
## A fixed perspective camera that frames the whole diorama inside the screen area left
## free by the HUD, on any aspect ratio (iPhone SE to Pro Max, iPad).
##
## The fit is solved numerically: for a fixed pitch and field of view, it searches the
## camera distance and the look-at point so every key point projects inside the target
## rectangle with a margin. Solving instead of hand-tuning per device is what keeps the
## yard fully tappable on every screen.

const PITCH_DEGREES := 58.0
const FIELD_OF_VIEW := 34.0
const MARGIN := 0.02
const ITERATIONS := 40

var _points: PackedVector3Array = PackedVector3Array()
var _shake := 0.0
var _base_position := Vector3.ZERO


func _ready() -> void:
	fov = FIELD_OF_VIEW
	near = 0.5
	far = 220.0
	rotation_degrees = Vector3(-PITCH_DEGREES, 0.0, 0.0)


## Points that must stay visible (rail ends, station corners, yard corners, scenery tops).
func set_subject(points: PackedVector3Array) -> void:
	_points = points


## Frames the subject inside `target` (viewport pixels).
func frame(target: Rect2) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if _points.is_empty() or viewport_size.x <= 0.0 or target.size.x <= 0.0:
		return
	# Target rectangle in normalised device coordinates (-1..1, y up).
	var left := target.position.x / viewport_size.x * 2.0 - 1.0 + MARGIN
	var right := target.end.x / viewport_size.x * 2.0 - 1.0 - MARGIN
	var top := 1.0 - target.position.y / viewport_size.y * 2.0 - MARGIN
	var bottom := 1.0 - target.end.y / viewport_size.y * 2.0 + MARGIN
	var aspect := viewport_size.x / viewport_size.y
	var tan_y := tan(deg_to_rad(fov) * 0.5)
	var tan_x := tan_y * aspect
	var basis_now := Basis.from_euler(Vector3(deg_to_rad(-PITCH_DEGREES), 0.0, 0.0))
	var forward := -basis_now.z
	var centre := _centroid()
	var low := 5.0
	var high := 200.0
	var look := centre
	for i in ITERATIONS:
		var distance := (low + high) * 0.5
		look = _centre_look(look, distance, basis_now, tan_x, tan_y, left, right, top, bottom)
		var extent := _extent(look - forward * distance, basis_now, tan_x, tan_y)
		if extent.position.x >= left and extent.end.x <= right and extent.position.y >= bottom and extent.end.y <= top:
			high = distance
		else:
			low = distance
	var final_distance := high
	look = _centre_look(look, final_distance, basis_now, tan_x, tan_y, left, right, top, bottom)
	_base_position = look - forward * final_distance
	transform = Transform3D(basis_now, _base_position)


## Brief screen shake (e.g. when the train hits the final stop).
func shake(strength: float = 0.35) -> void:
	_shake = strength


func _process(delta: float) -> void:
	if _shake <= 0.0:
		return
	_shake = maxf(0.0, _shake - delta * 1.2)
	position = _base_position + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake * 0.4


func _centroid() -> Vector3:
	var sum := Vector3.ZERO
	for p in _points:
		sum += p
	return sum / _points.size()


## Projected NDC bounds of all subject points for a camera at `origin`.
func _extent(origin: Vector3, view: Basis, tan_x: float, tan_y: float) -> Rect2:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for p in _points:
		var local := view.inverse() * (p - origin)
		var depth := -local.z
		if depth <= 0.01:
			return Rect2(Vector2(-INF, -INF), Vector2(INF, INF))
		var ndc := Vector2(local.x / (depth * tan_x), local.y / (depth * tan_y))
		low = Vector2(minf(low.x, ndc.x), minf(low.y, ndc.y))
		high = Vector2(maxf(high.x, ndc.x), maxf(high.y, ndc.y))
	return Rect2(low, high - low)


## Moves the look-at point (in the ground plane) so the projected subject is centred in
## the target rectangle at the given distance.
func _centre_look(look: Vector3, distance: float, view: Basis, tan_x: float, tan_y: float,
		left: float, right: float, top: float, bottom: float) -> Vector3:
	var forward := -view.z
	var result := look
	for i in 8:
		var extent := _extent(result - forward * distance, view, tan_x, tan_y)
		if not is_finite(extent.size.x):
			return result
		var error := Vector2((left + right) * 0.5, (top + bottom) * 0.5) - extent.get_center()
		# Convert NDC error to world units at the subject's distance.
		result.x -= error.x * distance * tan_x
		result.z += error.y * distance * tan_y / sin(deg_to_rad(PITCH_DEGREES))
	return result
