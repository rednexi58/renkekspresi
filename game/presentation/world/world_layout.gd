class_name WorldLayout
extends RefCounted
## World-space placement of the station and the collector yard for one level.
##
## Kept separate from the views so the camera fit, input picking and every view agree on
## exactly the same geometry. The route (rails) lies at negative Z, the station at Z=0 and
## the yard towards the camera at positive Z, so one continuous diorama is framed by a
## single camera with the interactive yard nearest (largest) on screen.

const BERTH_SPACING := 2.75
const BERTH_SIZE := Vector3(2.45, 0.22, 2.0)
const STATION_Z := 0.4
const YARD_TOP_Z := 4.0
const CELL_X := 4.3
const CELL_Z := 2.75
const COLLECTOR_SCALE := 1.18
## Height of the picking plane: roughly the roof of a parked collector.
const PICK_HEIGHT := 1.6

var rows: int
var cols: int


func _init(level: LevelDefinition) -> void:
	rows = level.rows
	cols = level.cols


func cell_position(row: int, col: int) -> Vector3:
	return Vector3((col - (cols - 1) * 0.5) * CELL_X, 0.0, YARD_TOP_Z + row * CELL_Z)


func berth_position(index: int) -> Vector3:
	return Vector3((index - 2) * BERTH_SPACING, 0.0, STATION_Z)


## Unit vector a collector's arrow points to in world space.
static func arrow_direction(definition: CollectorDefinition) -> Vector3:
	var direction := Vector3(definition.dx, 0.0, definition.dz)
	return Vector3.FORWARD if direction.length_squared() == 0.0 else direction.normalized()


## Yard rectangle on the ground (XZ) including a margin for the paving border.
func yard_rect() -> Rect2:
	var half_width := cols * CELL_X * 0.5 + 0.6
	var top := YARD_TOP_Z - CELL_Z * 0.5 - 0.5
	var bottom := YARD_TOP_Z + (rows - 1) * CELL_Z + CELL_Z * 0.5 + 0.5
	return Rect2(Vector2(-half_width, top), Vector2(half_width * 2.0, bottom - top))


## Cell (row, col) under a ground-plane point, or Vector2i(-1, -1) if outside.
func cell_at(point: Vector3) -> Vector2i:
	var col := roundi(point.x / CELL_X + (cols - 1) * 0.5)
	var row := roundi((point.z - YARD_TOP_Z) / CELL_Z)
	if row < 0 or row >= rows or col < 0 or col >= cols:
		return Vector2i(-1, -1)
	var centre := cell_position(row, col)
	if absf(point.x - centre.x) > CELL_X * 0.5 or absf(point.z - centre.z) > CELL_Z * 0.5:
		return Vector2i(-1, -1)
	return Vector2i(row, col)
