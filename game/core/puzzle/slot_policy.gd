class_name SlotPolicy
extends RefCounted
## How many station slots exist and how each kind is unlocked.
##
## Standard game: 3 slots always open, 1 permanent slot for VIP buyers, and 4 more that
## rewarded ads unlock one at a time for the current level (8 in total). Kept as data so
## the economy can be tuned without touching the rules, and so the original game's
## recorded traces can still be replayed with its own limits (legacy: one reward slot,
## 5 in total).

var base_slots := 3
var vip_slots := 1
var reward_slots := 4


static func standard() -> SlotPolicy:
	return SlotPolicy.new()


static func legacy() -> SlotPolicy:
	var policy := SlotPolicy.new()
	policy.reward_slots = 1
	return policy


func max_slots() -> int:
	return base_slots + vip_slots + reward_slots
