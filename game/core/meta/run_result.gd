class_name RunResult
extends RefCounted
## Scores one finished level: stars, coins and the bonuses that make a win feel earned
## (clean play, combos, near misses, hard levels). Pure arithmetic over a few facts the
## game flow collects, so balancing is tested without playing.

const NEAR_MISS_DANGER := 0.85
const NEAR_MISS_BONUS := 15
const COMBO_COINS_PER_STEP := 3
const COMBO_MIN := 3
const COMBO_COINS_MAX := 30

var stars := 1
var base_coins := 0
var combo_coins := 0
var near_miss_coins := 0
var hard_bonus := 0
var near_miss := false


## `assisted`: a booster was used; `revives`: continues taken; `peak_danger`: highest
## danger reached (0..1); `best_combo`: longest combo; `hard`: LevelTags.is_hard;
## `chances_used`: times the train reached the end and was pushed back.
## Three stars need a run with no booster, no chance used and no continue; two stars
## allow boosters and one used chance; anything else earns one star.
static func score(assisted: bool, revives: int, peak_danger: float, best_combo: int, hard: bool, chances_used: int = 0) -> RunResult:
	var result := RunResult.new()
	var clean := revives == 0 and chances_used == 0
	if clean and not assisted:
		result.stars = 3
	elif revives == 0 and chances_used <= 1:
		result.stars = 2
	else:
		result.stars = 1
	result.base_coins = Economy.win_coins(assisted)
	if best_combo >= COMBO_MIN:
		result.combo_coins = mini(COMBO_COINS_MAX, (best_combo - COMBO_MIN + 1) * COMBO_COINS_PER_STEP)
	result.near_miss = clean and peak_danger >= NEAR_MISS_DANGER
	if result.near_miss:
		result.near_miss_coins = NEAR_MISS_BONUS
	if hard:
		result.hard_bonus = result.base_coins * (LevelTags.HARD_REWARD_FACTOR - 1)
	return result


func total_coins() -> int:
	return base_coins + combo_coins + near_miss_coins + hard_bonus
