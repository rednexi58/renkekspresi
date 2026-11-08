class_name RewardGuard
extends RefCounted
## Ensures one asynchronous reward/purchase callback grants at most once, and that a
## callback arriving after the player left the level (stale generation) grants nothing.

var _generation := 0
var _pending := false


func begin() -> int:
	_pending = true
	_generation += 1
	return _generation


func cancel() -> void:
	_pending = false
	_generation += 1


func accept(token: int, earned: bool) -> bool:
	if not _pending or token != _generation:
		return false
	_pending = false
	return earned
