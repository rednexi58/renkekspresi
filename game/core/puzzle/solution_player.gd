class_name SolutionPlayer
extends RefCounted
## Plays a collector order the way a steady player would: the next collector is sent as
## soon as a slot is free and it can leave the yard. Used by the balance tool and by the
## campaign test that every authored level stays winnable under the shipped tuning.

const STEP := 0.05
const TIME_LIMIT := 900.0

var won := false
var seconds := 0.0
var peak_danger := 0.0


static func play(level: LevelDefinition, solution: Array, tuning: RulesTuning, policy: SlotPolicy = null) -> SolutionPlayer:
	var result := SolutionPlayer.new()
	var rules := PuzzleEngine.new(level, false, policy, tuning)
	rules.booster_stock = PackedInt32Array([0, 0, 0])
	rules.start()
	var next := 0
	while rules.is_playing() and rules.elapsed < TIME_LIMIT:
		if next < solution.size() and rules.occupied_slots() < policy_slots(rules):
			if rules.choose(int(solution[next])) == PuzzleEngine.ChooseResult.OK:
				next += 1
		rules.tick(STEP)
		result.peak_danger = maxf(result.peak_danger, rules.danger())
	result.won = rules.status == PuzzleEngine.Status.WON
	result.seconds = rules.elapsed
	return result


## Slots usable without purchases or ads.
static func policy_slots(rules: PuzzleEngine) -> int:
	return rules.policy.base_slots
