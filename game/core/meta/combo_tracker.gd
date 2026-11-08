class_name ComboTracker
extends RefCounted
## Counts collectors completed in quick succession (each full collector is one step;
## single wagons arrive automatically and would make every chain a "combo"). Fed with rule time (not wall time) so
## pauses never break or extend a combo, and tests are deterministic.

const WINDOW_SECONDS := 4.0

var current := 0
var best := 0
var _last_time := -INF


## Registers a match at rule time `time`; returns the combo length it is part of.
func register(time: float) -> int:
	current = current + 1 if time - _last_time <= WINDOW_SECONDS else 1
	_last_time = time
	best = maxi(best, current)
	return current


func reset() -> void:
	current = 0
	best = 0
	_last_time = -INF
