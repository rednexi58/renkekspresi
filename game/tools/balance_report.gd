extends SceneTree
## Development tool: auto-plays every level's authored solution (no boosters, 3 base
## slots) under the legacy and the standard rule tuning and prints win/loss, time and
## peak danger, to see how a tuning change shifts difficulty before it ships.
##
##   godot --headless --path game --script res://tools/balance_report.gd [-- --campaign=res://...]

func _initialize() -> void:
	var path := Campaign.DEFAULT_PATH
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--campaign="):
			path = argument.get_slice("=", 1)
	var campaign := Campaign.load_from(path)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var totals := {"legacy": [0, 0.0], "standard": [0, 0.0]}
	for i in campaign.count():
		var solution: Array = data["levels"][i]["design"]["solution"]
		var line := "L%03d t%d" % [i + 1, campaign.level_at(i).train_count]
		for name: String in ["legacy", "standard"]:
			var tuning := RulesTuning.legacy() if name == "legacy" else RulesTuning.standard()
			var result := SolutionPlayer.play(campaign.level_at(i), solution, tuning)
			line += "  %s %s %5.1fs danger %.2f" % [name, "WIN " if result.won else "LOSS", result.seconds, result.peak_danger]
			if result.won:
				totals[name][0] += 1
			totals[name][1] += result.peak_danger
		print(line)
	for name: String in totals:
		print("%s: %d/%d wins, mean peak danger %.2f" % [name, totals[name][0], campaign.count(), totals[name][1] / campaign.count()])
	quit()
