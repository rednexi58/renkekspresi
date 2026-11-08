class_name SolutionPlayer
extends RefCounted
## Plays a collector order the way a steady player would: the next collector is sent as
## soon as a slot is free. If it cannot leave the yard yet (a player's order may differ
## from the authored one), the first later collector that can is sent instead. Used by the balance tool and by the
## campaign test that every authored level stays winnable under the shipped tuning.

const STEP := 0.05
const TIME_LIMIT := 900.0

var won := false
var seconds := 0.0
var peak_danger := 0.0


## `stray_chance` (0..1) is how often the player sends a random collector that can leave
## the yard instead of the planned one, using `random` (deterministic when seeded).
static func play(level: LevelDefinition, solution: Array, tuning: RulesTuning, policy: SlotPolicy = null,
		stray_chance: float = 0.0, random: RandomNumberGenerator = null) -> SolutionPlayer:
	var result := SolutionPlayer.new()
	var rules := PuzzleEngine.new(level, false, policy, tuning)
	rules.booster_stock = PackedInt32Array([0, 0, 0])
	rules.start()
	var next := 0
	while rules.is_playing() and rules.elapsed < TIME_LIMIT:
		if next < solution.size() and rules.occupied_slots() < policy_slots(rules):
			var order := solution
			var pick := next
			if stray_chance > 0.0 and random != null and random.randf() < stray_chance:
				var open: Array[int] = []
				for i in range(next, order.size()):
					if rules.yard.is_available(int(order[i])):
						open.append(i)
				if not open.is_empty():
					pick = open[random.randi_range(0, open.size() - 1)]
			while pick < order.size() and not rules.yard.is_available(int(order[pick])):
				pick += 1
			if pick < order.size() and rules.choose(int(order[pick])) == PuzzleEngine.ChooseResult.OK:
				if pick != next:
					order = order.duplicate()
					var chosen: Variant = order[pick]
					order.remove_at(pick)
					order.insert(next, chosen)
					solution = order
				next += 1
		rules.tick(STEP)
		result.peak_danger = maxf(result.peak_danger, rules.danger())
	result.won = rules.status == PuzzleEngine.Status.WON
	result.seconds = rules.elapsed
	return result


## Slots usable without purchases or ads.
static func policy_slots(rules: PuzzleEngine) -> int:
	return rules.policy.base_slots
