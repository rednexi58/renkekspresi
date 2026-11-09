class_name TrackBuilder
extends RefCounted
## Builds one lane of railway the way a real track is layered: a soft shoulder on the
## ground, a raised gravel ballast bed, wooden sleepers laid square across it, and two
## steel rails with a polished running surface, at the gauge of the wagons' wheels.
##
## Heights are constants shared with TrainView (wheels stand on RAIL_TOP) and SceneView
## (the loading-zone glow lies on the ballast, under the sleepers). The ballast and the
## sleepers are lit, so the train's real shadow falls on the track; the shoulder is
## unshaded like the rest of the ground.

const SHOULDER_HALF_WIDTH := 1.15
const BALLAST_HALF_WIDTH := 0.82
const BALLAST_TOP_HALF_WIDTH := 0.68
const BALLAST_TOP := 0.075
const SLEEPER_SPACING := 0.5
const SLEEPER_SIZE := Vector3(1.16, 0.055, 0.2)
## Half the gauge: the wagons' wheels are 0.4 from the centre line at their drawn scale.
const RAIL_HALF_GAUGE := 0.4
const RAIL_WIDTH := 0.075
const RAIL_HEIGHT := 0.085
const RAIL_BASE := BALLAST_TOP + SLEEPER_SIZE.y - 0.01
const RAIL_TOP := RAIL_BASE + RAIL_HEIGHT
const SAMPLE_STEP := 0.15

const BALLAST: Array[Color] = [Color("6f675f"), Color("857c72"), Color("9c9287"), Color("7b7269")]
const WINTER_BALLAST: Array[Color] = [Color("8d949c"), Color("a3aab2"), Color("c4cad1"), Color("9aa1a9")]
const SLEEPER := Color("6e4f3a")
const WINTER_SLEEPER := Color("5d4a3e")
const STEEL := Color("9aa4b0")
const STEEL_SHINE := Color("eef2f6")

var _models: ModelLibrary
var _winter := false


func _init(models: ModelLibrary, winter: bool) -> void:
	_models = models
	_winter = winter


## Adds the whole track of `route` under `parent`.
func build(parent: Node3D, route: RailRoute) -> void:
	var path := _sample(route)
	var shoulder := PackedVector2Array([Vector2(-SHOULDER_HALF_WIDTH, 0.0), Vector2(-SHOULDER_HALF_WIDTH + 0.14, 0.015),
		Vector2(SHOULDER_HALF_WIDTH - 0.14, 0.015), Vector2(SHOULDER_HALF_WIDTH, 0.0)])
	_add(parent, "Shoulder", PathExtruder.extrude(path, shoulder), _models.ground(Palette.WINTER_PATH if _winter else Palette.PATH), false)
	var bed := PackedVector2Array([Vector2(-BALLAST_HALF_WIDTH, 0.01), Vector2(-BALLAST_TOP_HALF_WIDTH, BALLAST_TOP),
		Vector2(BALLAST_TOP_HALF_WIDTH, BALLAST_TOP), Vector2(BALLAST_HALF_WIDTH, 0.01)])
	var gravel := _models.textured("ballast", PackedColorArray(WINTER_BALLAST if _winter else BALLAST), 0.09, 0.9, 0.95, true)
	_add(parent, "Ballast", PathExtruder.extrude(path, bed), gravel, false)
	_add_sleepers(parent, route)
	for side: float in [-1.0, 1.0]:
		var x := side * RAIL_HALF_GAUGE
		var half := RAIL_WIDTH * 0.5
		var rail := PackedVector2Array([Vector2(x - half, 0.0), Vector2(x - half, RAIL_HEIGHT), Vector2(x + half, RAIL_HEIGHT), Vector2(x + half, 0.0)])
		_add(parent, "Rail", PathExtruder.extrude(path, rail, RAIL_BASE), _models.material(STEEL, 0.35, 0.25), true)
		var shine := PackedVector2Array([Vector2(x - half * 0.45, 0.0), Vector2(x + half * 0.45, 0.0)])
		_add(parent, "Rail shine", PathExtruder.extrude(path, shine, RAIL_TOP + 0.002), _models.flat_material(STEEL_SHINE), false)


func _sample(route: RailRoute) -> PackedVector3Array:
	var steps := maxi(1, ceili(route.length / SAMPLE_STEP))
	var path := PackedVector3Array()
	for i in steps + 1:
		path.append(route.point_at(route.length * i / steps))
	return path


## Sleepers square to the rail. The size is applied in the sleeper's own axes (basis *
## scale): scaling the rotated basis instead shears it into a slanted spike on curves.
func _add_sleepers(parent: Node3D, route: RailRoute) -> void:
	var count := int(route.length / SLEEPER_SPACING)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _models.primitive("rounded_box")
	multimesh.instance_count = count
	var size := Basis.from_scale(SLEEPER_SIZE)
	for i in count:
		var distance := (i + 0.5) * SLEEPER_SPACING
		var facing := Basis.looking_at(route.direction_at(distance), Vector3.UP)
		multimesh.set_instance_transform(i, Transform3D(facing * size, route.point_at(distance) + Vector3.UP * (BALLAST_TOP + SLEEPER_SIZE.y * 0.5 - 0.005)))
	var instance := MultiMeshInstance3D.new()
	instance.name = "Sleepers"
	instance.multimesh = multimesh
	instance.material_override = _models.material(WINTER_SLEEPER if _winter else SLEEPER, 0.85)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


func _add(parent: Node3D, label: String, mesh: ArrayMesh, material: Material, shadows: bool) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
