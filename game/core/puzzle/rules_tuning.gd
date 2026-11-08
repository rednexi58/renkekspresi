class_name RulesTuning
extends RefCounted
## Pace of the rules, kept as data next to SlotPolicy for the same reason: the game can be
## tuned without touching the engine, and the original v0.34 timing stays available to
## replay its recorded traces exactly (legacy).
##
## Collecting a wagon pushes its train back (the reward); `recovery_boost` is how much
## faster the train rolls forward again while it is behind its furthest point, so after a
## burst of collections the next wagons reach the loading zone sooner instead of the
## board going quiet. `catch_up` is how fast trailing wagons close the gap left by a
## collected one; `recovery_share` is the part of each push-back that is won back quickly
## (the rest keeps the train further from the end, so collecting still buys time); `dispatch_factor` scales the short delay before a collector takes a wagon.

var recovery_boost := 2.2
var recovery_share := 0.5
var catch_up := 7.5
var dispatch_factor := 0.8


static func standard() -> RulesTuning:
	return RulesTuning.new()


static func legacy() -> RulesTuning:
	var tuning := RulesTuning.new()
	tuning.recovery_boost = 1.0
	tuning.recovery_share = 0.0
	tuning.catch_up = 5.45
	tuning.dispatch_factor = 1.0
	return tuning
