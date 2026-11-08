class_name LevelSession
extends Node
## Runs one level: owns the PuzzleEngine, advances it each frame while not paused, and
## turns rule outcomes into signals. The only object allowed to call rule actions, so
## views and HUD stay passive and every rule change has exactly one entry point.

signal collector_sent(collector_id: int, slot_index: int, color_id: int)
signal choice_rejected(collector_id: int, result: PuzzleEngine.ChooseResult, blockers: PackedInt32Array)
signal booster_used(kind: int, events: Array[MatchEvent])
signal booster_refused(kind: int, result: PuzzleEngine.BoosterResult)
signal matched(event: MatchEvent)
signal finished(won: bool)
signal ticked
signal slots_changed

## Longest frame the simulation accepts; a longer hitch (e.g. returning from background)
## is clamped so the train cannot jump past the loading zone in one frame.
const MAX_FRAME := 0.1

var engine: PuzzleEngine
var paused := true
var _finished := false


func begin(level: LevelDefinition, has_vip: bool) -> void:
	engine = PuzzleEngine.new(level, has_vip)
	engine.start()
	paused = false
	_finished = false


## Opens the permanent VIP slot for this level (the player owns VIP).
func unlock_vip_slot() -> bool:
	if engine == null or not engine.grant_vip():
		return false
	slots_changed.emit()
	return true


## Opens one more slot for this level after a rewarded ad was watched to the end.
func unlock_reward_slot() -> bool:
	if engine == null or not engine.grant_reward_slot():
		return false
	slots_changed.emit()
	return true


## Continue after a loss (paid with coins or a rewarded ad by the caller).
func revive() -> bool:
	if engine == null or not engine.revive():
		return false
	_finished = false
	paused = false
	return true


func is_active() -> bool:
	return engine != null and engine.is_playing() and not paused


func choose(collector_id: int) -> void:
	if not is_active() or collector_id < 0:
		return
	var result := engine.choose(collector_id)
	if result == PuzzleEngine.ChooseResult.OK:
		var slot_index := -1
		for i in engine.slots.size():
			if engine.slots[i].collector == collector_id:
				slot_index = i
		collector_sent.emit(collector_id, slot_index, engine.yard.at(collector_id).definition.color)
	else:
		choice_rejected.emit(collector_id, result, engine.yard.blockers(collector_id))


func use_booster(kind: int) -> void:
	if not is_active():
		return
	var events: Array[MatchEvent] = []
	var result := engine.use_booster(kind, events)
	if result != PuzzleEngine.BoosterResult.OK:
		booster_refused.emit(kind, result)
		return
	booster_used.emit(kind, events)
	for event in events:
		matched.emit(event)
	_check_finish()


func _process(delta: float) -> void:
	if not is_active():
		return
	for event in engine.tick(minf(delta, MAX_FRAME)):
		matched.emit(event)
	ticked.emit()
	_check_finish()


func _check_finish() -> void:
	if _finished or engine.is_playing():
		return
	_finished = true
	paused = true
	finished.emit(engine.status == PuzzleEngine.Status.WON)
