class_name CollectorDefinition
extends RefCounted
## Immutable description of one collector in the puzzle yard, as authored in campaign.json.
##
## A collector sits on a (row, col) grid cell, points in direction (dx, dz) and can carry
## `capacity` wagons of `color`. `requires` links to a key collector that must leave the
## yard first (-1 = none). `key` is the label shown on a key collector ("" = not a key).

var id: int
var row: int
var col: int
var dx: int
var dz: int
var color: int
var capacity: int
var requires: int
var key: String


static func from_dict(data: Dictionary) -> CollectorDefinition:
	var definition := CollectorDefinition.new()
	definition.id = int(data["id"])
	definition.row = int(data["row"])
	definition.col = int(data["col"])
	definition.dx = int(data["dx"])
	definition.dz = int(data["dz"])
	definition.color = int(data["color"])
	definition.capacity = int(data["capacity"])
	definition.requires = int(data.get("requires", -1))
	var raw_key: Variant = data.get("key", "")
	definition.key = "" if raw_key == null else str(raw_key)
	return definition


func has_direction() -> bool:
	return dx != 0 or dz != 0
