class_name ProgressTrack
extends Control
## How close the train is to the final stop: a rounded track that fills from green to
## red, a little locomotive riding along it and a red flag at the end.

const TRACK_HEIGHT := 26.0
const ENGINE_SIZE := Vector2(58.0, 40.0)

var danger := 0.0:
	set(value):
		danger = clampf(value, 0.0, 1.0)
		queue_redraw()


func _draw() -> void:
	var y := size.y * 0.5
	var left := 30.0
	var right := size.x - 54.0
	var track := Rect2(left, y - TRACK_HEIGHT * 0.5, right - left, TRACK_HEIGHT)
	draw_style_box(_box(Color(0.11, 0.17, 0.31, 0.25), TRACK_HEIGHT * 0.5), track.grow(4.0))
	draw_style_box(_box(Color("eef4ff"), TRACK_HEIGHT * 0.5), track)
	var fill_color := Palette.SUCCESS.lerp(Palette.GOLD, clampf(danger * 1.6, 0.0, 1.0)).lerp(Palette.DANGER, clampf((danger - 0.6) * 2.5, 0.0, 1.0))
	var fill := Rect2(track.position, Vector2(maxf(TRACK_HEIGHT, track.size.x * danger), TRACK_HEIGHT))
	draw_style_box(_box(fill_color, TRACK_HEIGHT * 0.5), fill)
	_draw_flag(Vector2(right + 18.0, y))
	_draw_engine(Vector2(track.position.x + track.size.x * danger, y))


func _draw_engine(centre: Vector2) -> void:
	var body := Rect2(centre - ENGINE_SIZE * 0.5 + Vector2(0, -6), ENGINE_SIZE)
	draw_style_box(_box(Palette.INK, 12.0), body.grow(4.0))
	draw_style_box(_box(Palette.ENGINE_BODY, 10.0), body)
	draw_rect(Rect2(body.position + Vector2(body.size.x - 22.0, -14.0), Vector2(16.0, 16.0)), Palette.INK)
	for x in [body.position.x + 14.0, body.end.x - 14.0]:
		draw_circle(Vector2(x, body.end.y + 2.0), 9.0, Palette.INK)
		draw_circle(Vector2(x, body.end.y + 2.0), 4.0, Palette.GOLD)


func _draw_flag(base: Vector2) -> void:
	draw_line(base + Vector2(0, 26), base + Vector2(0, -30), Palette.INK, 6.0, true)
	draw_colored_polygon(PackedVector2Array([base + Vector2(2, -30), base + Vector2(36, -19), base + Vector2(2, -8)]), Palette.DANGER)


static func _box(color: Color, radius: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	box.anti_aliasing = true
	return box
