class_name RailRoute
extends RefCounted
## A lane's rail as a polyline sampled at even spacing, with arc-length lookup.
##
## Source files use the earlier left-handed axes (+Z away from the viewer); they are
## mirrored to Godot's right-handed axes on load (-Z away), matching the train meshes.
## Rule distances (PuzzleEngine) map onto this curve one-to-one.

const ROUTES_PATH := "res://data/routes/route_%03d.json"

var points: PackedVector3Array = PackedVector3Array()
var length: float = 0.0


## All lanes of a level, or an empty array if the file is missing or invalid.
static func load_level(level_id: int) -> Array[RailRoute]:
	var result: Array[RailRoute] = []
	var path := ROUTES_PATH % level_id
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Route file missing or invalid: " + path)
		return result
	for entry: Dictionary in (parsed as Dictionary)["routes"]:
		var route := RailRoute.new()
		route.length = float(entry["length"])
		for p: Dictionary in entry["points"]:
			route.points.append(Vector3(float(p["x"]), float(p["y"]), -float(p["z"])))
		if route.points.size() >= 2 and route.length > 0.0:
			result.append(route)
	return result


## Position at `distance` along the rail, clamped to its ends.
func point_at(distance: float) -> Vector3:
	var f := clampf(distance / length, 0.0, 1.0) * (points.size() - 1)
	var i := mini(points.size() - 2, int(floor(f)))
	return points[i].lerp(points[i + 1], f - i)


## Unit travel direction at `distance` (forward when no direction can be measured).
func direction_at(distance: float) -> Vector3:
	var delta := point_at(distance + 0.05) - point_at(distance - 0.05)
	return Vector3.FORWARD if delta.length_squared() < 0.0001 else delta.normalized()


## Bounding box of the rail in the XZ plane, as (min_x, min_z, max_x, max_z).
func bounds() -> Rect2:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for p in points:
		low = Vector2(minf(low.x, p.x), minf(low.y, p.z))
		high = Vector2(maxf(high.x, p.x), maxf(high.y, p.z))
	return Rect2(low, high - low)
