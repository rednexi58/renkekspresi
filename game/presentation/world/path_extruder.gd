class_name PathExtruder
extends RefCounted
## Sweeps a 2D cross-section along a rail to build track meshes (bed, rails, highlights).
##
## The profile is an open polyline of (lateral offset, height) pairs, listed from left to
## right as seen when travelling along the path. Normals are generated per face so edges
## stay crisp, which suits the toy look.

const SAMPLE_STEP := 0.25


## Samples `route` between two distances at even spacing (both ends included).
static func sample(route: RailRoute, from_distance: float, to_distance: float) -> PackedVector3Array:
	var result := PackedVector3Array()
	var start := clampf(from_distance, 0.0, route.length)
	var finish := clampf(to_distance, 0.0, route.length)
	if finish <= start:
		return result
	var steps := maxi(1, ceili((finish - start) / SAMPLE_STEP))
	for i in steps + 1:
		result.append(route.point_at(lerpf(start, finish, float(i) / steps)))
	return result


static func extrude(path: PackedVector3Array, profile: PackedVector2Array, lift: float = 0.0) -> ArrayMesh:
	if path.size() < 2 or profile.size() < 2:
		return null
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for i in path.size():
		var forward := _tangent(path, i)
		var side := forward.cross(Vector3.UP).normalized()
		var ring := PackedVector3Array()
		for p in profile:
			ring.append(path[i] + side * p.x + Vector3.UP * (p.y + lift))
		rings.append(ring)
	for i in path.size() - 1:
		var a := rings[i]
		var b := rings[i + 1]
		for j in profile.size() - 1:
			# Two triangles per quad, clockwise seen from outside (Godot's front face).
			tool.add_vertex(a[j])
			tool.add_vertex(b[j])
			tool.add_vertex(b[j + 1])
			tool.add_vertex(a[j])
			tool.add_vertex(b[j + 1])
			tool.add_vertex(a[j + 1])
	tool.generate_normals()
	return tool.commit()


static func _tangent(path: PackedVector3Array, i: int) -> Vector3:
	var before := path[maxi(0, i - 1)]
	var after := path[mini(path.size() - 1, i + 1)]
	var delta := after - before
	delta.y = 0.0
	return Vector3.FORWARD if delta.length_squared() < 0.000001 else delta.normalized()
