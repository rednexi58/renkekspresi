class_name WinStreak
extends RefCounted
## Consecutive wins give free boosters at the start of the next level (Freeze, then
## Blast, then Recall), lost on the first defeat. The tier list is data so it can be
## tuned without touching flow code.

## Boosters granted at the start of a level for a streak of index+1 wins (capped at the last).
const TIERS := [
	[1, 0, 0],
	[1, 1, 0],
	[1, 1, 1],
]


static func boosters_for(streak: int) -> PackedInt32Array:
	if streak <= 0:
		return PackedInt32Array([0, 0, 0])
	return PackedInt32Array(TIERS[mini(streak, TIERS.size()) - 1])


static func tier(streak: int) -> int:
	return mini(maxi(streak, 0), TIERS.size())
