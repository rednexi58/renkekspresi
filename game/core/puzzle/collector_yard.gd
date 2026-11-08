class_name CollectorYard
extends RefCounted
## The grid of parked collectors and the rules for which one may leave.
##
## Separated from PuzzleEngine because "which collector is free to move" is pure board
## geometry, independent of train timing. The hint system and the UI's blocked-highlight
## use it without touching the simulation.

var collectors: Array[CollectorState] = []


func _init(definitions: Array[CollectorDefinition]) -> void:
	for definition in definitions:
		collectors.append(CollectorState.new(definition))


func size() -> int:
	return collectors.size()


func has(id: int) -> bool:
	return id >= 0 and id < collectors.size()


func at(id: int) -> CollectorState:
	return collectors[id]


## A collector is locked while the key collector it requires is still parked.
func is_locked(id: int) -> bool:
	if not has(id):
		return false
	var requires := collectors[id].definition.requires
	return requires >= 0 and collectors[requires].is_parked()


## Collectors preventing `id` from leaving: its unreleased key, and every parked collector
## lying ahead on its arrow ray (same line, positive direction).
func blockers(id: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	if not has(id):
		return result
	var own := collectors[id].definition
	if is_locked(id):
		result.append(own.requires)
	if not own.has_direction():
		return result
	for other in collectors:
		var data := other.definition
		if not other.is_parked() or data.id == id or result.has(data.id):
			continue
		var x := data.col - own.col
		var z := data.row - own.row
		if x * own.dz == z * own.dx and x * own.dx + z * own.dz > 0:
			result.append(data.id)
	return result


func is_available(id: int) -> bool:
	return has(id) and collectors[id].is_parked() and blockers(id).is_empty()
