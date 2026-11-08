class_name WorldLayout
extends RefCounted
## World-space geometry of the board (collector grid) and the station shelf for one
## level. Kept separate from the views so the camera fit, input picking and every view
## agree on exactly the same positions.
##
## The board lies on the ground plane around the origin, rows growing toward the camera
## (+Z). The shelf runs across the screen just above the board (-Z side). The scene with
## the train is a separate, independently scaled group placed above the shelf by
## LevelWorld, so the board size never depends on how large a level's route is.

## Cells are wider than deep: the board then fills the screen width on tall phones
## instead of leaving empty margins, while vertical pieces still fit between rows.
const CELL_X := 3.3
const CELL_Z := 2.75
const PIECE_SCALE := 1.18
const SLOT_SPACING := 1.32
const SLOT_COLUMNS := 8
## Shelf positions in one row: 0-2 always open, 3 the VIP slot, 4-7 the rewarded slots.
const SLOT_COUNT := 8
const VIP_POSITION := 3
const FIRST_REWARD_POSITION := 4
const SHELF_DEPTH := 2.5
const SHELF_GAP := 0.7
const TOKEN_SCALE := 0.6
## Height of the picking plane: the roof of a piece on the board.
const PICK_HEIGHT := 1.09

var rows: int
var cols: int


func _init(level: LevelDefinition) -> void:
	rows = level.rows
	cols = level.cols


func cell_position(row: int, col: int) -> Vector3:
	return Vector3((col - (cols - 1) * 0.5) * CELL_X, 0.0, (row - (rows - 1) * 0.5) * CELL_Z)


## Board rectangle on the ground (XZ), including a margin for piece overhang.
func board_rect() -> Rect2:
	var half_width := cols * CELL_X * 0.5
	var half_depth := rows * CELL_Z * 0.5
	return Rect2(Vector2(-half_width, -half_depth), Vector2(half_width * 2.0, half_depth * 2.0))


func shelf_centre_z() -> float:
	return board_rect().position.y - SHELF_GAP - SHELF_DEPTH * 0.5


func shelf_width() -> float:
	return SLOT_SPACING * SLOT_COLUMNS + 0.5


## Centre of a shelf position (one row of eight).
func slot_position(position_index: int) -> Vector3:
	return Vector3((position_index - (SLOT_COLUMNS - 1) * 0.5) * SLOT_SPACING, 0.0, shelf_centre_z() - 0.3)


## Shelf position at a ground point, or -1.
func slot_at(point: Vector3) -> int:
	for i in SLOT_COUNT:
		var centre := slot_position(i)
		if absf(point.x - centre.x) <= SLOT_SPACING * 0.5 and absf(point.z - centre.z) <= SHELF_DEPTH * 0.5:
			return i
	return -1


## Unit vector a collector's arrow points to in world space.
static func arrow_direction(definition: CollectorDefinition) -> Vector3:
	var direction := Vector3(definition.dx, 0.0, definition.dz)
	return Vector3.FORWARD if direction.length_squared() == 0.0 else direction.normalized()


## Cell (row, col) under a ground-plane point, or Vector2i(-1, -1) if outside.
func cell_at(point: Vector3) -> Vector2i:
	var col := roundi(point.x / CELL_X + (cols - 1) * 0.5)
	var row := roundi(point.z / CELL_Z + (rows - 1) * 0.5)
	if row < 0 or row >= rows or col < 0 or col >= cols:
		return Vector2i(-1, -1)
	var centre := cell_position(row, col)
	if absf(point.x - centre.x) > CELL_X * 0.5 or absf(point.z - centre.z) > CELL_Z * 0.5:
		return Vector2i(-1, -1)
	return Vector2i(row, col)
