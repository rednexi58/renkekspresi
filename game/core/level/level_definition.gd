class_name LevelDefinition
extends RefCounted
## Immutable description of one campaign level. Only parsing lives here; rules live in
## PuzzleEngine and presentation reads the cosmetic fields (theme, names, seed).

var id: int
var theme: int
var map_seed: int
var rows: int
var cols: int
var train_count: int
var name_tr: String
var name_en: String
var region_tr: String
var region_en: String
var lesson: String
var dispatch_seconds: float
var loading_fraction: float
var recoil_per_unit: float
var approach_speed: float
var track_length: float
var train: PackedInt32Array
var wagon_streams: PackedInt32Array
var parking: Array[CollectorDefinition] = []


static func from_dict(data: Dictionary) -> LevelDefinition:
	var level := LevelDefinition.new()
	level.id = int(data["id"])
	level.theme = int(data.get("theme", 0))
	level.map_seed = int(data.get("map_seed", 0))
	level.rows = int(data["rows"])
	level.cols = int(data["cols"])
	level.train_count = maxi(1, int(data.get("train_count", 1)))
	level.name_tr = str(data.get("name", ""))
	level.name_en = str(data.get("name_en", level.name_tr))
	level.region_tr = str(data.get("region", ""))
	level.region_en = str(data.get("region_en", level.region_tr))
	level.lesson = str(data.get("lesson", ""))
	level.dispatch_seconds = float(data["dispatch_seconds"])
	level.loading_fraction = float(data["loading_fraction"])
	level.recoil_per_unit = float(data["recoil_per_unit"])
	level.approach_speed = float(data["approach_speed"])
	level.track_length = float(data["track_length"])
	level.train = _ints(data["train"])
	level.wagon_streams = _ints(data.get("wagon_streams", []))
	for entry: Dictionary in data["parking"]:
		level.parking.append(CollectorDefinition.from_dict(entry))
	level._validate()
	return level


static func _ints(values: Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	for value: Variant in values:
		result.append(int(value))
	return result


func _validate() -> void:
	assert(not train.is_empty(), "Level %d has no wagons" % id)
	assert(train_count == 1 or wagon_streams.size() == train.size(), "Level %d: wagon_streams must match train" % id)
	for i in parking.size():
		assert(parking[i].id == i, "Level %d: collector ids must be contiguous" % id)
