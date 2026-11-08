class_name FollowCamera
extends Camera3D
## Orthographic camera for the train scene that keeps the action large on screen.
##
## Each frame it frames the "action box": every running engine and its final stop. When
## the train is far from the station the box is large and the camera zooms out; as the
## train closes in, the box shrinks and the camera zooms in, so the climax is the biggest
## thing on screen. The view never shows ground beyond the decorated area, and motion is
## smoothed so the camera never jumps.

const PITCH_DEGREES := 56.0
const DISTANCE := 60.0
const MIN_WIDTH := 11.0
const MARGIN := 3.2
const SMOOTHING := 2.6

var _bounds := Rect2()
var _focus := Vector3.ZERO
var _width := MIN_WIDTH
var _snap := true
var _shake := 0.0


func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	keep_aspect = Camera3D.KEEP_WIDTH
	near = 1.0
	far = 200.0
	rotation_degrees = Vector3(-PITCH_DEGREES, 0.0, 0.0)


## Ground area the camera may show (route plus decorated margin).
func set_bounds(bounds: Rect2) -> void:
	_bounds = bounds
	_snap = true


## Points that must stay in view this frame (engine heads, final stops, loading zones).
func follow(points: PackedVector3Array, delta: float) -> void:
	if points.is_empty():
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for p in points:
		low = Vector2(minf(low.x, p.x), minf(low.y, p.z))
		high = Vector2(maxf(high.x, p.x), maxf(high.y, p.z))
	var sin_p := sin(deg_to_rad(PITCH_DEGREES))
	var aspect := viewport_size.x / viewport_size.y
	# Width needed to fit the box horizontally, and to fit its depth vertically.
	var needed := maxf(high.x - low.x + MARGIN * 2.0, (high.y - low.y + MARGIN * 2.0) * sin_p * aspect)
	var full := maxf(_bounds.size.x, _bounds.size.y * sin_p * aspect)
	var target_width := clampf(needed, minf(MIN_WIDTH, full), full)
	var target_focus := Vector3((low.x + high.x) * 0.5, 0.0, (low.y + high.y) * 0.5)
	target_focus = _clamp_focus(target_focus, target_width, aspect, sin_p)
	if _snap:
		_focus = target_focus
		_width = target_width
		_snap = false
	else:
		var weight := 1.0 - exp(-SMOOTHING * delta)
		_focus = _focus.lerp(target_focus, weight)
		_width = lerpf(_width, target_width, weight)
	size = _width
	var view := Basis.from_euler(Vector3(deg_to_rad(-PITCH_DEGREES), 0.0, 0.0))
	var shake_offset := Vector3.ZERO
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 1.2)
		shake_offset = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * _shake * 0.5
	transform = Transform3D(view, _focus + shake_offset - (-view.z) * DISTANCE)


func shake(strength: float = 0.4) -> void:
	_shake = strength


## Keeps the visible ground rectangle inside the decorated bounds when possible.
func _clamp_focus(focus: Vector3, width: float, aspect: float, sin_p: float) -> Vector3:
	var half_w := width * 0.5
	var half_d := width / aspect / sin_p * 0.5
	var result := focus
	if _bounds.size.x > half_w * 2.0:
		result.x = clampf(result.x, _bounds.position.x + half_w, _bounds.end.x - half_w)
	else:
		result.x = _bounds.get_center().x
	if _bounds.size.y > half_d * 2.0:
		result.z = clampf(result.z, _bounds.position.y + half_d, _bounds.end.y - half_d)
	else:
		result.z = _bounds.get_center().y
	return result
