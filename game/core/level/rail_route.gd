class_name RailRoute
extends RefCounted
## A lane's rail as a polyline sampled at even spacing, with arc-length lookup.
##
## Source files use the earlier left-handed axes (+Z away from the viewer); they are
## mirrored to Godot's right-handed axes on load (-Z away), matching the train meshes.
## Rule distances (PuzzleEngine) map onto this curve one-to-one.

const ROUTES_PATH := "res://data/routes/route_%03d.json"
## Corner rounding applied on load: each point becomes the average of its neighbours
## within this many points, twice. Some authored routes turn by tens of degrees at a
## single point; a train (and its sleepers) folding over such a kink looks broken, so
## kinks are eased into short curves. Gentle curves are practically unchanged.
const SMOOTH_RADIUS := 9
const SMOOTH_PASSES := 2

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
			route.points = _evenly_spaced(_smoothed(route.points))
			result.append(route)
	return result


## Moving average over each point's neighbourhood; the two ends stay where they are (the
## window shrinks towards them) so the tunnel and the final stop do not move.
static func _smoothed(source: PackedVector3Array) -> PackedVector3Array:
	var current := source
	for pass_index in SMOOTH_PASSES:
		var next := PackedVector3Array()
		next.resize(current.size())
		for i in current.size():
			var reach := mini(SMOOTH_RADIUS, mini(i, current.size() - 1 - i))
			var sum := Vector3.ZERO
			for k in range(i - reach, i + reach + 1):
				sum += current[k]
			next[i] = sum / float(reach * 2 + 1)
		current = next
	return current


## The same polyline with the same number of points at equal arc-length spacing, so a
## rule distance still maps linearly onto it (point_at) after smoothing bunched points up.
static func _evenly_spaced(source: PackedVector3Array) -> PackedVector3Array:
	var cumulative := PackedFloat64Array([0.0])
	for i in range(1, source.size()):
		cumulative.append(cumulative[i - 1] + source[i - 1].distance_to(source[i]))
	var total := cumulative[cumulative.size() - 1]
	if total <= 0.0:
		return source
	var result := PackedVector3Array()
	var segment := 0
	for i in source.size():
		var wanted := total * i / float(source.size() - 1)
		while segment < source.size() - 2 and cumulative[segment + 1] < wanted:
			segment += 1
		var span := cumulative[segment + 1] - cumulative[segment]
		var t := 0.0 if span <= 0.0 else clampf((wanted - cumulative[segment]) / span, 0.0, 1.0)
		result.append(source[segment].lerp(source[segment + 1], t))
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
