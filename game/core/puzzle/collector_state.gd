class_name CollectorState
extends RefCounted
## Runtime state of a collector: where it is and how many wagons it can still take.

enum Phase { PARKED, QUEUED, DONE }

var definition: CollectorDefinition
var remaining: int
var phase: Phase = Phase.PARKED


func _init(source: CollectorDefinition) -> void:
	definition = source
	remaining = source.capacity


func is_parked() -> bool:
	return phase == Phase.PARKED
