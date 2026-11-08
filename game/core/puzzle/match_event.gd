class_name MatchEvent
extends RefCounted
## Emitted when a collector takes a wagon. Presentation uses it for effects only.

var wagon: int
var color: int
var lane: int
var collector: int
var slot: int
var distance: float
## True when this wagon filled the collector (it leaves its slot).
var completes := false


func _init(wagon_state: WagonState, collector_id: int, slot_index: int) -> void:
	wagon = wagon_state.id
	color = wagon_state.color
	lane = wagon_state.lane
	collector = collector_id
	slot = slot_index
	distance = wagon_state.distance
