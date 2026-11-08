extends SceneTree
## Development tool: compares rule tunings on every level. For each it auto-plays the
## authored solution (no boosters, 3 base slots) and then MISTAKE_RUNS runs where 30% of
## picks are a random collector that can leave the yard, the way a real player strays. The share
## of mistaken runs that still win measures how forgiving a tuning is; the clean run's
## peak danger measures pressure.
##
##   godot --headless --path game --script res://tools/balance_report.gd

const MISTAKE_RUNS := 12
const STRAY_CHANCE := 0.3


func _initialize() -> void:
	var campaign := Campaign.load_from()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Campaign.DEFAULT_PATH))
	var before := RulesTuning.standard()
	before.zone_start = 1.0
	before.collect_before_open = false
	before.approach_factor = 1.0
	var tunings := {"before": before, "standard": RulesTuning.standard()}
	var totals := {}
	for name: String in tunings:
		totals[name] = [0, 0, 0.0]
	for i in campaign.count():
		var solution: Array = data["levels"][i]["design"]["solution"]
		var line := "L%03d t%d" % [i + 1, campaign.level_at(i).train_count]
		for name: String in tunings:
			var clean := SolutionPlayer.play(campaign.level_at(i), solution, tunings[name])
			var forgiven := 0
			var random := RandomNumberGenerator.new()
			random.seed = 1000 + i
			for run in MISTAKE_RUNS:
				if SolutionPlayer.play(campaign.level_at(i), solution, tunings[name], null, STRAY_CHANCE, random).won:
					forgiven += 1
			line += "  %s %s danger %.2f mistakes won %2d/%d" % [name, "WIN " if clean.won else "LOSS", clean.peak_danger, forgiven, MISTAKE_RUNS]
			totals[name][0] += 1 if clean.won else 0
			totals[name][1] += forgiven
			totals[name][2] += clean.peak_danger
		print(line)
	for name: String in totals:
		print("%s: clean %d/%d, mistaken runs won %.0f%%, mean peak danger %.2f" % [name, totals[name][0], campaign.count(),
			100.0 * totals[name][1] / (campaign.count() * MISTAKE_RUNS), totals[name][2] / campaign.count()])
	quit()
