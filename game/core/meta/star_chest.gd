class_name StarChest
extends RefCounted
## Stars earned on wins fill a chest; a full chest opens for coins and boosters. Only
## stars improved over a level's previous best count, so replaying easy levels cannot
## farm chests.

const STARS_TO_OPEN := 15
const COINS := 150
const BOOSTERS := [1, 1, 1]


static func is_full(stars_in_chest: int) -> bool:
	return stars_in_chest >= STARS_TO_OPEN
