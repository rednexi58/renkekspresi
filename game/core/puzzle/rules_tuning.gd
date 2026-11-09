class_name RulesTuning
extends RefCounted
## Pace of the rules, kept as data next to SlotPolicy for the same reason: the game can be
## tuned without touching the engine, and the original v0.34 timing stays available to
## replay its recorded traces exactly (legacy).
##
## Values were chosen with tools/balance_report.gd: every level must stay winnable by its
## authored solution, the ideal run's peak danger should stay near the original (~0.7),
## and a player who strays from the plan should rarely lose unfairly.

## Collecting a wagon pushes its train back (the reward). While a train is behind its
## furthest point it rolls forward this much faster, so after a burst of collections the
## next wagons reach the loading zone sooner instead of the board going quiet.
var recovery_boost := 2.2
## Part of each push-back that is won back quickly; the rest is permanent, so collecting
## still buys time.
var recovery_share := 0.5
## Latest point of the track (fraction of its length) where wagons become collectable; a
## level's own earlier value wins. The original late zone let a matching wagon sit in
## plain view behind a run of another colour while its collector stayed idle.
var zone_start := 0.35
## Collectors may take wagons before the train has rolled 75% of the way in (the original
## intro gate left early collectors idle next to matching wagons).
var collect_before_open := true
## How fast trains roll in: the main pressure knob, raised to keep the tension the
## earlier zone would otherwise remove.
var approach_factor := 1.3
## Speed at which trailing wagons close the gap left by a collected one.
var catch_up := 7.5
## Extra closing speed per unit of gap (1/s). With three collectors working at once gaps
## open several times faster than `catch_up` closes them, and the train used to tear
## into a front piece and a far-behind rest; a speed that grows with the gap keeps the
## train coupled (a gap halves about every 0.08 s) without snapping.
var catch_up_gain := 9.0
## Scales the short delay before a collector takes its target wagon.
var dispatch_factor := 0.8


static func standard() -> RulesTuning:
	return RulesTuning.new()


static func legacy() -> RulesTuning:
	var tuning := RulesTuning.new()
	tuning.recovery_boost = 1.0
	tuning.recovery_share = 0.0
	tuning.zone_start = 1.0
	tuning.collect_before_open = false
	tuning.approach_factor = 1.0
	tuning.catch_up = 5.45
	tuning.catch_up_gain = 0.0
	tuning.dispatch_factor = 1.0
	return tuning
