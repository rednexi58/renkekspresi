class_name SceneCamera
extends Camera3D
## Fixed orthographic camera that shows the whole train map at once, as in Wool Crush:
## the player always sees every track, the loading zones and the final stops, so they can
## plan instead of reacting to a moving view. The map's own proportions decide how much
## screen height it asks for (see preferred_height), so long maps get a taller band and
## wide maps a shorter one, and the map is always as large as the screen allows.

const PITCH_DEGREES := 56.0
const DISTANCE := 60.0
const MARGIN := 1.2

var _bounds := Rect2()
var _centre := Vector3.ZERO
var _shake := 0.0


func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	keep_aspect = Camera3D.KEEP_WIDTH
	near = 1.0
	far = 200.0


## Ground rectangle (x, z) that must be fully visible.
func set_bounds(bounds: Rect2) -> void:
	_bounds = bounds.grow(MARGIN)
	_centre = Vector3(_bounds.get_center().x, 0.0, _bounds.get_center().y)


## Screen height (pixels) the map needs to be shown at `width_px` without shrinking.
func preferred_height(width_px: float) -> float:
	return width_px * _bounds.size.y * sin(deg_to_rad(PITCH_DEGREES)) / maxf(1.0, _bounds.size.x)


## Fits the map into a `view_size` viewport whose top `covered_px` rows are under the HUD:
## the map is fitted into the uncovered part and centred in it.
func fit(view_size: Vector2, covered_px: float) -> void:
	if view_size.x <= 0.0 or view_size.y <= covered_px:
		return
	var visible_height := view_size.y - covered_px
	var sin_p := sin(deg_to_rad(PITCH_DEGREES))
	size = maxf(_bounds.size.x, _bounds.size.y * sin_p * view_size.x / visible_height)
	var units_per_px := size / view_size.x
	v_offset = covered_px * 0.5 * units_per_px
	_place(Vector3.ZERO)


func shake(strength: float = 0.4) -> void:
	_shake = strength


func _process(delta: float) -> void:
	if _shake <= 0.0:
		return
	_shake = maxf(0.0, _shake - delta * 1.2)
	_place(Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * _shake * 0.5)


func _place(offset: Vector3) -> void:
	var view := Basis.from_euler(Vector3(deg_to_rad(-PITCH_DEGREES), 0.0, 0.0))
	transform = Transform3D(view, _centre + offset + view.z * DISTANCE)
