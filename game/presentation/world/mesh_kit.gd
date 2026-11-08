class_name MeshKit
extends RefCounted
## Procedural geometry with soft, bevelled edges. Hard-edged primitives are what make
## generated models look "toy"; rounding every edge slightly catches highlights the way
## real painted metal does.
##
## Pieces are appended into a SurfaceTool with a transform so a whole model (dozens of
## parts) collapses into one mesh with a handful of material surfaces, keeping draw
## calls low on phones.


## Appends a box with rounded edges (radius r) centred at the origin of `xform`.
static func rounded_box(tool: SurfaceTool, size: Vector3, radius: float, xform: Transform3D, segments: int = 3) -> void:
	var half := size * 0.5
	var r := minf(radius, minf(half.x, minf(half.y, half.z)))
	var inner := half - Vector3.ONE * r
	var steps := maxi(2, segments * 2)
	# Six faces of a subdivided cube; every grid vertex is pushed onto the rounded
	# surface: clamp into the inner box, then offset by r along the corner normal.
	var faces := [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]
	for face: Array in faces:
		var normal: Vector3 = face[0]
		var up: Vector3 = face[1]
		var side: Vector3 = face[2]
		var grid: Array[PackedVector3Array] = []
		var normals: Array[PackedVector3Array] = []
		for i in steps + 1:
			var row := PackedVector3Array()
			var row_normals := PackedVector3Array()
			for j in steps + 1:
				var u := float(j) / steps * 2.0 - 1.0
				var v := float(i) / steps * 2.0 - 1.0
				var cube := normal + side * u + up * v
				var point := cube * half
				var clamped := point.clamp(-inner, inner)
				var n := (point - clamped)
				n = normal if n.length_squared() < 0.0000001 else n.normalized()
				row.append(clamped + n * r)
				row_normals.append(n)
			grid.append(row)
			normals.append(row_normals)
		for i in steps:
			for j in steps:
				_quad(tool, xform,
					[grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]],
					[normals[i][j], normals[i][j + 1], normals[i + 1][j + 1], normals[i + 1][j]])


## Appends a cylinder along local X (an axle direction) with `sides` segments and caps.
static func cylinder_x(tool: SurfaceTool, radius: float, width: float, xform: Transform3D, sides: int = 14) -> void:
	var half := width * 0.5
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var p0 := Vector3(0.0, cos(a0), sin(a0)) * radius
		var p1 := Vector3(0.0, cos(a1), sin(a1)) * radius
		var n0 := Vector3(0.0, cos(a0), sin(a0))
		var n1 := Vector3(0.0, cos(a1), sin(a1))
		_quad(tool, xform,
			[p0 + Vector3(-half, 0, 0), p1 + Vector3(-half, 0, 0), p1 + Vector3(half, 0, 0), p0 + Vector3(half, 0, 0)],
			[n0, n1, n1, n0])
		for cap in [-1.0, 1.0]:
			var centre := Vector3(cap * half, 0.0, 0.0)
			var a := p0 + centre
			var b := p1 + centre
			var n := Vector3(cap, 0.0, 0.0)
			if cap > 0.0:
				_tri(tool, xform, [centre, a, b], n)
			else:
				_tri(tool, xform, [centre, b, a], n)


## Appends a vertical cylinder (Y axis), optionally tapered, without bottom cap.
static func cylinder_y(tool: SurfaceTool, bottom_radius: float, top_radius: float, height: float, xform: Transform3D, sides: int = 12) -> void:
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var slope := (bottom_radius - top_radius) / maxf(height, 0.0001)
		var n0 := (d0 + Vector3.UP * slope).normalized()
		var n1 := (d1 + Vector3.UP * slope).normalized()
		_quad(tool, xform,
			[d0 * bottom_radius, d0 * top_radius + Vector3.UP * height, d1 * top_radius + Vector3.UP * height, d1 * bottom_radius],
			[n0, n0, n1, n1])
		if top_radius > 0.0:
			_tri(tool, xform, [Vector3.UP * height, d1 * top_radius + Vector3.UP * height, d0 * top_radius + Vector3.UP * height], Vector3.UP)


## Quad with per-corner normals, emitted clockwise as seen from the outside.
static func _quad(tool: SurfaceTool, xform: Transform3D, p: Array, n: Array) -> void:
	var basis := xform.basis
	var normal_basis := basis.inverse().transposed()
	var order := [0, 1, 2, 0, 2, 3]
	# Decide winding from the geometric normal so callers need not care about order.
	var face: Vector3 = (p[1] - p[0]).cross(p[2] - p[0])
	var corner_normal: Vector3 = n[0] + n[2]
	if face.dot(corner_normal) > 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for k in order:
		tool.set_normal((normal_basis * n[k]).normalized())
		tool.add_vertex(xform * p[k])


static func _tri(tool: SurfaceTool, xform: Transform3D, p: Array, n: Vector3) -> void:
	var normal_basis := xform.basis.inverse().transposed()
	var face: Vector3 = (p[1] - p[0]).cross(p[2] - p[0])
	var order := [0, 1, 2]
	if face.dot(n) > 0.0:
		order = [0, 2, 1]
	for k in order:
		tool.set_normal((normal_basis * n).normalized())
		tool.add_vertex(xform * p[k])
