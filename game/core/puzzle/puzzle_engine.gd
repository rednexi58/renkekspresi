class_name PuzzleEngine
extends RefCounted
## Deterministic rules of one level: train motion, station slots, matching and boosters.
##
## Pure logic with no Node or rendering dependency, advanced in fixed 0.025 s rule steps so
## outcomes never depend on frame rate. Presentation reads state and MatchEvents; it can
## never remove a wagon or grant a reward itself. Behaviour is verified against 116
## recorded traces of the original game (tests/fixtures).

enum Status { READY, PLAYING, WON, LOST }
enum ChooseResult { OK, NOT_PLAYING, LOCKED, BLOCKED, FULL }
enum BoosterResult { OK, NOT_PLAYING, ACTIVE, EMPTY, NO_TARGET, NO_STOCK }
enum Booster { FREEZE, BLAST, RECALL }
enum SlotKind { BASE, VIP, REWARD }

const GAP := 1.8
const FIRST_GAP := 2.2
const POST_TEMPO := 2.75
const START_DISTANCE := 0.8
const RULE_STEP := 0.025
const EPSILON := 0.000001
const FREEZE_SECONDS := 5.0
const SLOT_READY_DELAY := 0.26
const SLOT_RETRY_DELAY := 0.045
const BLAST_LIMIT := 5
const RECOIL_SPEED := 14.0
const OPEN_THRESHOLD := 0.75

var level: LevelDefinition
var policy: SlotPolicy
var yard: CollectorYard
var wagons: Array[WagonState] = []
var slots: Array[StationSlot] = []
## Kind of each slot, parallel to `slots`, so the shelf can draw VIP and reward slots in
## their fixed places whatever order they were unlocked in.
var slot_kinds: Array[SlotKind] = []
## Collector ids in the order they were sent to the station (oldest first).
var order: PackedInt32Array = PackedInt32Array()
var heads: PackedFloat64Array = PackedFloat64Array()
var recoils: PackedFloat64Array = PackedFloat64Array()
## Furthest head distance each lane has reached (recovery after a push-back runs up to it).
var peaks: PackedFloat64Array = PackedFloat64Array()
var tuning: RulesTuning
var opened: Array[bool] = []

var status: Status = Status.READY
var elapsed := 0.0
var freeze_left := 0.0
var start_distance := START_DISTANCE
var end_distance := 0.0
var loading_start := 0.0
var loading_end := 0.0
var brake_distance := 0.0
var dispatch_delay := 0.0
var head_distance := START_DISTANCE

var taps := 0
var blocked_taps := 0
var peak_slots := 0
var total_wagons := 0
var vip := false
var reward_slots_granted := 0
## True once any booster was used; such wins are recorded separately from clean wins.
var assisted := false
## Times the player continued after losing (each continue counts as assisted).
var revives := 0
## Chances left in this level (see RulesTuning.chances) and how many were used. A chance
## is used when the train reaches the final stop while another one is left.
var chances_left := 1
var chances_used := 0
## Uses left for [FREEZE, BLAST, RECALL].
var booster_stock: PackedInt32Array = PackedInt32Array([0, 0, 1])


func _init(level_definition: LevelDefinition, has_vip: bool = false, slot_policy: SlotPolicy = null, rules_tuning: RulesTuning = null) -> void:
	level = level_definition
	policy = slot_policy if slot_policy != null else SlotPolicy.standard()
	tuning = rules_tuning if rules_tuning != null else RulesTuning.standard()
	chances_left = maxi(1, tuning.chances)
	var lanes := maxi(1, level.train_count)
	heads.resize(lanes)
	recoils.resize(lanes)
	peaks.resize(lanes)
	opened.resize(lanes)
	for lane in lanes:
		heads[lane] = start_distance
		recoils[lane] = 0.0
		peaks[lane] = start_distance
		opened[lane] = false
	end_distance = level.track_length - 0.9
	loading_start = start_distance + (end_distance - start_distance) * minf(level.loading_fraction, tuning.zone_start)
	loading_end = end_distance - 0.2
	brake_distance = level.recoil_per_unit * 0.8
	dispatch_delay = level.dispatch_seconds / 1.75 * tuning.dispatch_factor
	yard = CollectorYard.new(level.parking)
	var ranks := PackedInt32Array()
	ranks.resize(lanes)
	for i in level.train.size():
		var lane := level.wagon_streams[i] if lanes > 1 else 0
		var distance := start_distance - FIRST_GAP - ranks[lane] * GAP
		ranks[lane] += 1
		wagons.append(WagonState.new(i, level.train[i], lane, distance))
	total_wagons = wagons.size()
	for i in policy.base_slots:
		_add_slot(SlotKind.BASE)
	if has_vip:
		grant_vip()


# --- Queries -------------------------------------------------------------------------

func start() -> void:
	if status == Status.READY:
		status = Status.PLAYING


func is_playing() -> bool:
	return status == Status.PLAYING


func is_multi() -> bool:
	return heads.size() > 1


func has_lane(lane: int) -> bool:
	for wagon in wagons:
		if wagon.lane == lane:
			return true
	return false


func lane_count() -> int:
	return heads.size()


func rescued_count() -> int:
	return total_wagons - wagons.size()


## The most advanced head among lanes that still carry wagons.
func active_head() -> float:
	if not is_multi():
		return heads[0]
	var best := -INF
	for lane in heads.size():
		if has_lane(lane):
			best = maxf(best, heads[lane])
	return start_distance if best == -INF else best


## 0 at the depot, 1 when the train reaches the final stop (level lost).
func danger() -> float:
	return clampf((active_head() - start_distance) / maxf(1.0, end_distance - start_distance), 0.0, 1.0)


func occupied_slots() -> int:
	var count := 0
	for slot in slots:
		if slot.is_occupied():
			count += 1
	return count


func can_collect(wagon: WagonState) -> bool:
	return (opened[wagon.lane] or tuning.collect_before_open) and wagon.distance >= loading_start - 0.00001 and wagon.distance <= loading_end


func find_wagon(id: int) -> WagonState:
	for wagon in wagons:
		if wagon.id == id:
			return wagon
	return null


func _first_free_slot() -> int:
	for i in slots.size():
		if not slots[i].is_occupied():
			return i
	return -1


func _slot_of_collector(collector_id: int) -> StationSlot:
	for slot in slots:
		if slot.collector == collector_id:
			return slot
	return null


func _is_targeted(wagon_id: int) -> bool:
	for slot in slots:
		if slot.target == wagon_id:
			return true
	return false


## Wagons in matching priority: lanes ordered by most advanced head (ties by lane index).
func candidates() -> Array[WagonState]:
	if not is_multi():
		return wagons.duplicate()
	var lanes: Array[int] = []
	for lane in heads.size():
		lanes.append(lane)
	lanes.sort_custom(_lane_before)
	var result: Array[WagonState] = []
	for lane in lanes:
		for wagon in wagons:
			if wagon.lane == lane:
				result.append(wagon)
	return result


func _lane_before(a: int, b: int) -> bool:
	if absf(heads[a] - heads[b]) < 0.00001 * maxf(1.0, absf(heads[a])):
		return a < b
	return heads[a] > heads[b]


# --- Player actions ------------------------------------------------------------------

func choose(collector_id: int) -> ChooseResult:
	if status != Status.PLAYING:
		return ChooseResult.NOT_PLAYING
	if yard.is_locked(collector_id):
		blocked_taps += 1
		return ChooseResult.LOCKED
	if not yard.is_available(collector_id):
		blocked_taps += 1
		return ChooseResult.BLOCKED
	var index := _first_free_slot()
	if index < 0:
		return ChooseResult.FULL
	var collector := yard.at(collector_id)
	collector.phase = CollectorState.Phase.QUEUED
	var slot := slots[index]
	slot.collector = collector_id
	slot.color = collector.definition.color
	slot.ready_at = elapsed + SLOT_READY_DELAY
	slot.target = StationSlot.EMPTY
	order.append(collector_id)
	taps += 1
	peak_slots = maxi(peak_slots, occupied_slots())
	return ChooseResult.OK


func _add_slot(kind: SlotKind) -> void:
	slots.append(StationSlot.new())
	slot_kinds.append(kind)


## Permanent extra slot from the VIP purchase. Returns false if already granted.
func grant_vip() -> bool:
	if vip:
		return false
	vip = true
	if policy.vip_slots > 0 and slots.size() < policy.max_slots():
		_add_slot(SlotKind.VIP)
	return true


## One more slot for this level only (a rewarded unlock). Returns false when every
## reward slot is already open or the level is not being played.
func grant_reward_slot() -> bool:
	if status != Status.PLAYING or reward_slots_granted >= policy.reward_slots or slots.size() >= policy.max_slots():
		return false
	reward_slots_granted += 1
	_add_slot(SlotKind.REWARD)
	return true


func can_grant_reward_slot() -> bool:
	return status == Status.PLAYING and reward_slots_granted < policy.reward_slots and slots.size() < policy.max_slots()


## Refills an empty booster by one use. Refuses while uses remain.
func grant_booster(kind: int) -> bool:
	if status != Status.PLAYING or kind < 0 or kind > 2 or booster_stock[kind] > 0:
		return false
	booster_stock[kind] += 1
	return true


## Adds boosters granted before play starts (win streak, star chest). Ignored once the
## level is over; counts below zero are ignored.
func add_starting_boosters(counts: PackedInt32Array) -> void:
	if status != Status.PLAYING:
		return
	for kind in mini(3, counts.size()):
		booster_stock[kind] += maxi(0, counts[kind])


## Applies a booster. Matches it creates are appended to `events`.
func use_booster(kind: int, events: Array[MatchEvent]) -> BoosterResult:
	if status != Status.PLAYING or kind < 0 or kind > 2:
		return BoosterResult.NOT_PLAYING
	if kind == Booster.FREEZE and freeze_left > 0:
		return BoosterResult.ACTIVE
	if kind == Booster.RECALL and order.is_empty():
		return BoosterResult.EMPTY
	var targets: Array = []
	if kind == Booster.BLAST:
		targets = _blast_targets()
		if targets.is_empty():
			return BoosterResult.NO_TARGET
	if booster_stock[kind] <= 0:
		return BoosterResult.NO_STOCK
	match kind:
		Booster.FREEZE:
			freeze_left = FREEZE_SECONDS
		Booster.RECALL:
			_recall_last()
		Booster.BLAST:
			for pair: Array in targets:
				var wagon: WagonState = pair[0]
				if wagons.has(wagon) and can_collect(wagon):
					_remove(wagon, pair[1], events, true)
	if wagons.is_empty():
		status = Status.WON
	booster_stock[kind] -= 1
	assisted = true
	return BoosterResult.OK


## Continue after a loss: pulls every lane back by `pushback_fraction` of the track and
## freezes the train for `freeze_seconds`, then resumes play. Wagons move back with
## their engine so the train stays intact.
func revive(pushback_fraction: float = 0.35, freeze_seconds: float = 3.0) -> bool:
	if status != Status.LOST:
		return false
	_push_back(pushback_fraction, freeze_seconds)
	chances_left = 1
	revives += 1
	assisted = true
	status = Status.PLAYING
	return true


## Pulls every lane back by `pushback_fraction` of the track and freezes the trains;
## wagons move with their engine so each train stays intact.
func _push_back(pushback_fraction: float, freeze_seconds: float) -> void:
	var span := end_distance - start_distance
	for lane in heads.size():
		var target := maxf(start_distance, heads[lane] - span * pushback_fraction)
		var delta := heads[lane] - target
		heads[lane] = target
		peaks[lane] = target
		for wagon in wagons:
			if wagon.lane == lane:
				wagon.distance -= delta
	head_distance = active_head()
	freeze_left = maxf(freeze_left, freeze_seconds)


func _recall_last() -> void:
	var collector_id := order[order.size() - 1]
	order.remove_at(order.size() - 1)
	yard.at(collector_id).phase = CollectorState.Phase.PARKED
	var slot := _slot_of_collector(collector_id)
	slot.clear()
	slot.ready_at = 0.0


## Up to BLAST_LIMIT (wagon, slot index) pairs that could be collected right now.
func _blast_targets() -> Array:
	var result: Array = []
	var capacities := PackedInt32Array()
	for slot in slots:
		capacities.append(yard.at(slot.collector).remaining if slot.is_occupied() else 0)
	for wagon in candidates():
		if not can_collect(wagon):
			continue
		for s in slots.size():
			var slot := slots[s]
			if slot.color != wagon.color or capacities[s] <= 0 or (elapsed < slot.ready_at and slot.target < 0):
				continue
			result.append([wagon, s])
			capacities[s] -= 1
			break
		if result.size() >= BLAST_LIMIT:
			break
	return result


# --- Simulation ----------------------------------------------------------------------

## Advances the simulation by `delta` seconds in fixed rule steps. Returns new matches.
func tick(delta: float) -> Array[MatchEvent]:
	var events: Array[MatchEvent] = []
	if status != Status.PLAYING:
		return events
	var remaining := maxf(0.0, delta)
	while remaining > EPSILON and status == Status.PLAYING:
		var step := minf(RULE_STEP, remaining)
		remaining -= step
		elapsed += step
		_step(step, events)
	return events


func _step(step: float, events: Array[MatchEvent]) -> void:
	var before := heads.duplicate()
	var frozen := freeze_left > 0
	freeze_left = maxf(0.0, freeze_left - step)
	_advance_heads(step, frozen)
	_advance_wagons(step, frozen, before)
	head_distance = active_head()
	_assign_targets()
	_collect(events)
	if wagons.is_empty():
		status = Status.WON
	elif danger() >= 1.0:
		_reach_end()


## The train reached the final stop: spend a chance and push it back, or lose.
func _reach_end() -> void:
	chances_left -= 1
	if chances_left <= 0:
		chances_left = 0
		status = Status.LOST
		return
	chances_used += 1
	_push_back(tuning.chance_pushback, tuning.chance_freeze)


func _advance_heads(step: float, frozen: bool) -> void:
	var span := end_distance - start_distance
	for lane in heads.size():
		if frozen or (is_multi() and not has_lane(lane)):
			continue
		var progress := (heads[lane] - start_distance) / maxf(1.0, span)
		var speed: float
		if opened[lane]:
			speed = level.approach_speed * 0.8 * POST_TEMPO
		else:
			speed = span * (0.5 / (3.0 / 1.15) if progress < 0.5 else 0.25 / (4.0 / 1.15))
		if opened[lane] and progress < OPEN_THRESHOLD:
			speed *= 1.15
		if is_multi():
			speed *= 0.88
		speed *= tuning.approach_factor
		var move := speed * step
		if tuning.recovery_boost > 1.0 and heads[lane] < peaks[lane]:
			move = minf(move * tuning.recovery_boost, peaks[lane] - heads[lane] + move)
		heads[lane] += move
		if recoils[lane] > 0:
			var recoil := minf(recoils[lane], RECOIL_SPEED * step)
			heads[lane] = maxf(start_distance, heads[lane] - recoil)
			recoils[lane] -= recoil
		if is_multi():
			heads[lane] = maxf(start_distance, heads[lane])
		peaks[lane] = maxf(peaks[lane], heads[lane])
		if (heads[lane] - start_distance) / span >= OPEN_THRESHOLD:
			opened[lane] = true


func _advance_wagons(step: float, frozen: bool, before: PackedFloat64Array) -> void:
	if frozen:
		return
	var ranks := PackedInt32Array()
	ranks.resize(heads.size())
	for wagon in wagons:
		var rank := ranks[wagon.lane]
		ranks[wagon.lane] += 1
		var carried := wagon.distance + heads[wagon.lane] - before[wagon.lane]
		var target := heads[wagon.lane] - FIRST_GAP - rank * GAP
		var closing := tuning.catch_up + tuning.catch_up_gain * absf(target - carried)
		wagon.distance = _move_toward(carried, target, step * closing)


static func _move_toward(from: float, to: float, max_delta: float) -> float:
	return minf(from + max_delta, to) if from < to else maxf(from - max_delta, to)


## Each ready slot picks the first collectible wagon of its colour, unless an older slot
## of the same colour is still waiting (first sent, first served).
func _assign_targets() -> void:
	if not opened.has(true) and not tuning.collect_before_open:
		return
	for slot in slots:
		if not slot.is_occupied() or slot.target >= 0 or elapsed + EPSILON < slot.ready_at:
			continue
		if _older_same_color_waiting(slot):
			continue
		for wagon in candidates():
			if can_collect(wagon) and wagon.color == slot.color and not _is_targeted(wagon.id):
				slot.target = wagon.id
				slot.ready_at = elapsed + dispatch_delay
				break


func _older_same_color_waiting(slot: StationSlot) -> bool:
	var own_rank := order.find(slot.collector)
	for other in slots:
		if other != slot and other.color == slot.color and other.is_occupied() and order.find(other.collector) < own_rank:
			return true
	return false


func _collect(events: Array[MatchEvent]) -> void:
	for s in slots.size():
		var slot := slots[s]
		if not slot.is_occupied() or elapsed + EPSILON < slot.ready_at:
			continue
		var wagon := find_wagon(slot.target)
		if wagon == null:
			continue
		if not can_collect(wagon):
			slot.target = StationSlot.EMPTY
			slot.ready_at = elapsed + SLOT_RETRY_DELAY
			continue
		_remove(wagon, s, events, false)


func _remove(wagon: WagonState, slot_index: int, events: Array[MatchEvent], blast: bool) -> void:
	var slot := slots[slot_index]
	var collector_id := slot.collector
	var collector := yard.at(collector_id)
	collector.remaining -= 1
	if blast:
		for other in slots:
			if other.target == wagon.id:
				other.target = StationSlot.EMPTY
	else:
		slot.target = StationSlot.EMPTY
	if collector.remaining <= 0:
		collector.phase = CollectorState.Phase.DONE
		var index := order.find(collector_id)
		if index >= 0:
			order.remove_at(index)
		slot.clear()
	else:
		slot.ready_at = elapsed + SLOT_RETRY_DELAY
	var event := MatchEvent.new(wagon, collector_id, slot_index)
	event.completes = collector.remaining <= 0
	events.append(event)
	wagons.erase(wagon)
	recoils[wagon.lane] += brake_distance
	# Only part of a push-back is won back quickly; the rest is permanent relief.
	peaks[wagon.lane] = maxf(start_distance, peaks[wagon.lane] - brake_distance * (1.0 - tuning.recovery_share))
