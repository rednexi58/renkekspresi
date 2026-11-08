extends RefCounted
## Replays the 116 recorded traces of the original v0.34 game (100 campaign solutions and
## 16 edge cases covering full slots, VIP/reward slots, refills and all boosters) and
## compares every snapshot: status, time, heads, wagon ids/distances, slots, capacities,
## and for edge cases booster stock, freeze, targets and ready times.

## The campaign as recorded in v0.34; later campaign rebalancing must not break replay.
const REFERENCE_CAMPAIGN := "res://tests/fixtures/campaign_v034.json"
const FIXTURES := ["res://tests/fixtures/godot_reference.json", "res://tests/fixtures/godot_edge_reference.json"]
const STATUS_NAMES := {
	PuzzleEngine.Status.READY: "ready", PuzzleEngine.Status.PLAYING: "playing",
	PuzzleEngine.Status.WON: "won", PuzzleEngine.Status.LOST: "lost",
}
const CHOOSE_NAMES := {
	PuzzleEngine.ChooseResult.OK: "", PuzzleEngine.ChooseResult.NOT_PLAYING: "not_playing",
	PuzzleEngine.ChooseResult.LOCKED: "locked", PuzzleEngine.ChooseResult.BLOCKED: "blocked",
	PuzzleEngine.ChooseResult.FULL: "full",
}
const BOOSTER_NAMES := {
	PuzzleEngine.BoosterResult.OK: "", PuzzleEngine.BoosterResult.NOT_PLAYING: "not_playing",
	PuzzleEngine.BoosterResult.ACTIVE: "active", PuzzleEngine.BoosterResult.EMPTY: "empty",
	PuzzleEngine.BoosterResult.NO_TARGET: "no_target", PuzzleEngine.BoosterResult.NO_STOCK: "no_stock",
}

var snapshots := 0
var cases := 0


func run(_campaign: Campaign, report: TestReport) -> void:
	var campaign := Campaign.load_from(REFERENCE_CAMPAIGN)
	for path: String in FIXTURES:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for test: Dictionary in data["cases"]:
			cases += 1
			if not _replay(campaign, test, report):
				return


func _replay(campaign: Campaign, test: Dictionary, report: TestReport) -> bool:
	var level_id := int(test["level"])
	var rules := PuzzleEngine.new(campaign.level_at(level_id - 1), false, SlotPolicy.legacy(), RulesTuning.legacy())
	rules.start()
	var actions: Array = test["actions"]
	var frames: Array = test["snapshots"]
	var act := 0
	var frame := 0
	var step := 0
	while frame < frames.size():
		while act < actions.size() and int(actions[act]["step"]) == step:
			if not _apply(rules, actions[act], level_id, step, report):
				return false
			act += 1
		rules.tick(0.05)
		step += 1
		if step != int(frames[frame]["step"]):
			continue
		if not _compare(rules, frames[frame], "L%d t%d" % [level_id, step], report):
			return false
		frame += 1
		snapshots += 1
	return true


func _apply(rules: PuzzleEngine, action: Dictionary, level_id: int, step: int, report: TestReport) -> bool:
	var kind: String = action.get("kind", "choose")
	var expected: String = action.get("error", "")
	var context := "L%d step %d %s" % [level_id, step, kind]
	match kind:
		"choose":
			return report.check(CHOOSE_NAMES[rules.choose(int(action["id"]))] == expected, context)
		"vip":
			return report.check(rules.grant_vip() == bool(action["ok"]), context)
		"slot":
			return report.check(rules.grant_reward_slot() == bool(action["ok"]), context)
		"refill":
			return report.check(rules.grant_booster(int(action["id"])) == bool(action["ok"]), context)
		"boost":
			var events: Array[MatchEvent] = []
			return report.check(BOOSTER_NAMES[rules.use_booster(int(action["id"]), events)] == expected, context)
	return report.check(false, "Unknown action " + kind)


func _compare(rules: PuzzleEngine, f: Dictionary, ctx: String, report: TestReport) -> bool:
	var ok := report.check(STATUS_NAMES[rules.status] == f["status"], ctx + " status")
	ok = ok and report.near(rules.elapsed, f["elapsed"], ctx + " elapsed")
	ok = ok and report.near(rules.head_distance, f["head"], ctx + " head")
	ok = ok and report.check(_ids(rules) == _ints(f["ids"]), ctx + " wagon ids")
	ok = ok and report.check(_slots(rules, "collector") == _ints(f["slots"]), ctx + " slots")
	ok = ok and report.check(_remaining(rules) == _ints(f["remaining"]), ctx + " capacities")
	var heads: Array = f["heads"]
	for i in heads.size():
		ok = ok and report.near(rules.heads[i], heads[i], "%s lane %d" % [ctx, i])
	if f.has("stock"):
		ok = ok and report.check(rules.booster_stock == _ints(f["stock"]), ctx + " stock")
		ok = ok and report.near(rules.freeze_left, f["freeze"], ctx + " freeze")
		ok = ok and report.check(_slots(rules, "target") == _ints(f["targets"]), ctx + " targets")
		var ready: Array = f["ready"]
		for i in ready.size():
			ok = ok and report.near(rules.slots[i].ready_at, ready[i], "%s ready %d" % [ctx, i])
	var distances: Array = f["distances"]
	for i in distances.size():
		ok = ok and report.near(rules.wagons[i].distance, distances[i], "%s wagon %d" % [ctx, i])
	return ok


static func _ints(values: Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	for v: Variant in values:
		result.append(int(v))
	return result


static func _ids(rules: PuzzleEngine) -> PackedInt32Array:
	var result := PackedInt32Array()
	for wagon in rules.wagons:
		result.append(wagon.id)
	return result


static func _slots(rules: PuzzleEngine, field: String) -> PackedInt32Array:
	var result := PackedInt32Array()
	for slot in rules.slots:
		result.append(slot.collector if field == "collector" else slot.target)
	return result


static func _remaining(rules: PuzzleEngine) -> PackedInt32Array:
	var result := PackedInt32Array()
	for collector in rules.yard.collectors:
		result.append(collector.remaining)
	return result
