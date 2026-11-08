class_name StationSlot
extends RefCounted
## A station berth. Holds at most one collector; `target` is the wagon it is about to take
## and `ready_at` the rule time before which it may not act.

const EMPTY := -1

var collector: int = EMPTY
var color: int = EMPTY
var target: int = EMPTY
var ready_at: float = 0.0


func is_occupied() -> bool:
	return collector >= 0


func clear() -> void:
	collector = EMPTY
	color = EMPTY
	target = EMPTY
