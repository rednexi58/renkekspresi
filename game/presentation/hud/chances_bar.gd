class_name ChancesBar
extends Control
## Row of hearts showing the chances left in the level (PuzzleEngine.chances_left out of
## the level's total). Hearts are drawn as vector shapes so they stay crisp at any scale
## and need no font glyph; a lost heart turns grey and briefly pops.

const HEART_SIZE := 54.0
const GAP := 12.0
const FULL := Color("ff4d6d")
const FULL_EDGE := Color("a3123a")
const EMPTY := Color(1.0, 1.0, 1.0, 0.35)
const EMPTY_EDGE := Color(0.25, 0.2, 0.2, 0.45)

var _total := 3
var _left := 3
var _pop := -1
var _pop_time := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_chances(left: int, total: int) -> void:
	total = maxi(total, left)
	if left == _left and total == _total:
		return
	_left = left
	_total = total
	custom_minimum_size = Vector2(total * HEART_SIZE + (total - 1) * GAP, HEART_SIZE)
	size = custom_minimum_size
	queue_redraw()


## Animates the heart that was just lost.
func break_heart() -> void:
	_pop = clampi(_left, 0, _total - 1)
	_pop_time = 0.45


func _process(delta: float) -> void:
	if _pop_time > 0.0:
		_pop_time = maxf(0.0, _pop_time - delta)
		queue_redraw()


func _draw() -> void:
	for i in _total:
		var centre := Vector2(i * (HEART_SIZE + GAP) + HEART_SIZE * 0.5, HEART_SIZE * 0.5)
		var scale := 1.0
		if i == _pop and _pop_time > 0.0:
			scale = 1.0 + sin(_pop_time / 0.45 * PI) * 0.45
		var full := i < _left
		_draw_heart(centre, HEART_SIZE * 0.5 * scale, FULL if full else EMPTY, FULL_EDGE if full else EMPTY_EDGE)


func _draw_heart(centre: Vector2, radius: float, fill: Color, edge: Color) -> void:
	var points := PackedVector2Array()
	for k in 48:
		var t := TAU * k / 48.0
		# Classic heart curve, normalised to about [-1, 1].
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		points.append(centre + Vector2(x, y + 2.0) / 17.0 * radius)
	draw_colored_polygon(points, fill)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, edge, 4.0, true)
	if fill == FULL:
		draw_circle(centre + Vector2(-0.38, -0.32) * radius, radius * 0.16, Color(1, 1, 1, 0.55))
