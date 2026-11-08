class_name LevelTags
extends RefCounted
## Derived facts about a level's place in the campaign: whether it is a "hard" level
## (bigger reward, red label) and which new mechanic it introduces, if any. Computed
## from the authored data so designers never maintain a second list.

enum Intro { NONE, FIRST_TRAIN, MORE_COLORS, TWO_TRAINS, THREE_TRAINS, FOUR_TRAINS, BIG_YARD }

const INTRO_KEYS := {
	Intro.MORE_COLORS: "INTRO_MORE_COLORS",
	Intro.TWO_TRAINS: "INTRO_TWO_TRAINS",
	Intro.THREE_TRAINS: "INTRO_THREE_TRAINS",
	Intro.FOUR_TRAINS: "INTRO_FOUR_TRAINS",
	Intro.BIG_YARD: "INTRO_BIG_YARD",
}
const HARD_REWARD_FACTOR := 2


## Every fifth level from level 10 on is a hard one, except mechanic intros (a new idea
## should be learned on a fair level, not a spike).
static func is_hard(campaign: Campaign, index: int) -> bool:
	if index < 9 or (index + 1) % 5 != 0:
		return false
	return intro(campaign, index) == Intro.NONE


## The mechanic this level shows for the first time in the campaign.
static func intro(campaign: Campaign, index: int) -> Intro:
	if index <= 0 or index >= campaign.count():
		return Intro.NONE
	var level := campaign.level_at(index)
	var max_trains := 1
	var max_colors := 0
	var max_cells := 0
	for i in index:
		var previous := campaign.level_at(i)
		max_trains = maxi(max_trains, previous.train_count)
		max_colors = maxi(max_colors, _colors(previous))
		max_cells = maxi(max_cells, previous.rows * previous.cols)
	if level.train_count > max_trains:
		match level.train_count:
			2: return Intro.TWO_TRAINS
			3: return Intro.THREE_TRAINS
			_: return Intro.FOUR_TRAINS
	if _colors(level) > max_colors and max_colors > 0:
		return Intro.MORE_COLORS
	if level.rows * level.cols > max_cells and max_cells > 0 and level.rows >= 5:
		return Intro.BIG_YARD
	return Intro.NONE


static func _colors(level: LevelDefinition) -> int:
	var seen := {}
	for color in level.train:
		seen[color] = true
	return seen.size()
