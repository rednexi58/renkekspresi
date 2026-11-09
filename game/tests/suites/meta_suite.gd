extends RefCounted
## Engagement systems: the world tour covers every level with unique cities, mechanic
## intros and hard levels are derived sensibly, run scoring, streak boosters, combos,
## the star chest, and the new progress fields survive a save round trip.

func run(campaign: Campaign, report: TestReport) -> void:
	_world_tour(campaign, report)
	_level_tags(campaign, report)
	_run_result(report)
	_streak_and_combo(report)
	_progress_fields(report)
	_campaign_balance(campaign, report)
	_train_stays_coupled(campaign, report)


## While collectors empty the middle of a train, the wagons behind must close up quickly:
## the hole left by collected wagons never grows beyond a couple of wagon lengths (it used
## to reach eight, tearing the train into a front piece and a far-behind rest).
func _train_stays_coupled(campaign: Campaign, report: TestReport) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Campaign.DEFAULT_PATH))
	for index: int in [3, 10, 16, 40, 120]:
		var level := campaign.level_at(index)
		var solution: Array = data["levels"][index]["design"]["solution"]
		var rules := PuzzleEngine.new(level)
		rules.booster_stock = PackedInt32Array([0, 0, 0])
		rules.start()
		var next := 0
		var worst := 0.0
		while rules.is_playing() and rules.elapsed < SolutionPlayer.TIME_LIMIT:
			if next < solution.size() and rules.occupied_slots() < rules.policy.base_slots:
				if rules.choose(int(solution[next])) == PuzzleEngine.ChooseResult.OK:
					next += 1
			rules.tick(SolutionPlayer.STEP)
			var ahead := {}
			for wagon in rules.wagons:
				if wagon.distance < 0.0:
					continue
				var front: float = ahead.get(wagon.lane, rules.heads[wagon.lane] - PuzzleEngine.FIRST_GAP + PuzzleEngine.GAP)
				worst = maxf(worst, front - wagon.distance - PuzzleEngine.GAP)
				ahead[wagon.lane] = wagon.distance
		report.check(worst <= PuzzleEngine.GAP * 2.5, "L%d: holes in the train stay under 2.5 wagons (%.1f)" % [level.id, worst / PuzzleEngine.GAP])


## Several trains every third level from level 9 (two, then two or three after level 30), and every level stays winnable by its
## authored solution under the shipped rule tuning with only the always-open slots.
func _campaign_balance(campaign: Campaign, report: TestReport) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Campaign.DEFAULT_PATH))
	for i in campaign.count():
		var level := campaign.level_at(i)
		var multi_slot := level.id >= 9 and level.id % 3 == 0
		report.check((level.train_count > 1) == multi_slot, "L%d: several trains exactly every third level from 9" % level.id)
		report.check(level.train_count <= (2 if level.id <= 30 else 3), "L%d: two trains up to 30, at most three after" % level.id)
		var result := SolutionPlayer.play(level, data["levels"][i]["design"]["solution"], RulesTuning.standard())
		report.check(result.won, "L%d: authored solution wins with standard tuning" % level.id)
		report.check(result.peak_danger < 0.99, "L%d: solution keeps a safety margin" % level.id)


func _world_tour(campaign: Campaign, report: TestReport) -> void:
	report.check(WorldTour.stop_count() >= campaign.count(), "World tour covers every level")
	var seen := {}
	var countries := {}
	for i in WorldTour.stop_count():
		var stop := WorldTour.stop(i, "en")
		report.check(stop[0] != "" and stop[1] != "", "Stop %d has city and country" % i)
		report.check(not seen.has(stop[0]), "City %s is unique" % stop[0])
		seen[stop[0]] = true
		countries[stop[1]] = true
		report.check(WorldTour.stop(i, "tr")[1] != "", "Stop %d has a Turkish country name" % i)
	report.check(countries.size() >= 50, "Tour visits at least 50 countries (%d)" % countries.size())


func _level_tags(campaign: Campaign, report: TestReport) -> void:
	var intros := 0
	var hard := 0
	for i in campaign.count():
		var intro := LevelTags.intro(campaign, i)
		if intro != LevelTags.Intro.NONE:
			intros += 1
			report.check(LevelTags.INTRO_KEYS.has(intro), "Intro %d has a text" % intro)
			report.check(not LevelTags.is_hard(campaign, i), "Intro level %d is not hard" % (i + 1))
		if LevelTags.is_hard(campaign, i):
			hard += 1
			report.check(i >= 9, "No hard level before 10")
	report.check(intros >= 3, "Campaign introduces at least three mechanics (%d)" % intros)
	report.check(hard >= campaign.count() / 10 and hard <= campaign.count() / 5, "Hard levels are occasional (%d)" % hard)
	report.check(LevelTags.intro(campaign, 0) == LevelTags.Intro.NONE, "Level 1 has the tutorial, not an intro")


func _run_result(report: TestReport) -> void:
	var clean := RunResult.score(false, 0, 0.3, 1, false)
	report.check(clean.stars == 3 and clean.total_coins() == Economy.win_coins(false), "Clean win: 3 stars, base coins")
	var boosted := RunResult.score(true, 0, 0.3, 1, false)
	report.check(boosted.stars == 2, "Booster win: 2 stars")
	var revived := RunResult.score(false, 1, 0.99, 1, false)
	report.check(revived.stars == 1 and not revived.near_miss, "Revived win: 1 star, no near miss")
	var close := RunResult.score(false, 0, 0.9, 5, true)
	report.check(close.near_miss and close.near_miss_coins == RunResult.NEAR_MISS_BONUS, "Near miss bonus")
	report.check(close.combo_coins == 3 * RunResult.COMBO_COINS_PER_STEP, "Combo x5 coins")
	report.check(close.hard_bonus == close.base_coins, "Hard level doubles base coins")


func _streak_and_combo(report: TestReport) -> void:
	report.check(WinStreak.boosters_for(0) == PackedInt32Array([0, 0, 0]), "No streak, no boosters")
	report.check(WinStreak.boosters_for(1) == PackedInt32Array([1, 0, 0]), "Streak 1: freeze")
	report.check(WinStreak.boosters_for(9) == PackedInt32Array([1, 1, 1]), "Long streak capped")
	var combo := ComboTracker.new()
	report.check(combo.register(1.0) == 1 and combo.register(3.0) == 2 and combo.register(6.5) == 3, "Quick completions chain")
	report.check(RunResult.score(false, 0, 0.1, 40, false).combo_coins == RunResult.COMBO_COINS_MAX, "Combo coins capped")
	report.check(combo.register(12.0) == 1 and combo.best == 3, "Slow match resets, best kept")


func _progress_fields(report: TestReport) -> void:
	var progress := PlayerProgress.new()
	report.check(progress.record_stars(4, 2) == 2, "First stars all count")
	report.check(progress.record_stars(4, 1) == 0 and progress.stars[4] == 2, "Worse result keeps best")
	report.check(progress.record_stars(4, 3) == 1 and progress.chest_stars == 3, "Only improvements fill the chest")
	progress.record_win(6, 40)
	progress.win_streak = 4
	progress.booster_bank = PackedInt32Array([1, 2, 0])
	progress.intros_seen.append(14)
	var copy := PlayerProgress.from_dict(progress.to_dict())
	report.check(copy.stars[4] == 3 and copy.chest_stars == 3 and copy.win_streak == 4, "Stars, chest and streak saved")
	report.check(copy.booster_bank == PackedInt32Array([1, 2, 0]) and copy.intros_seen.has(14), "Booster bank and intros saved")
	report.check(copy.furthest_level() == 7 and copy.total_stars() == 3, "Furthest level and star total")
	report.check(copy.take_booster_bank() == PackedInt32Array([1, 2, 0]) and copy.booster_bank == PackedInt32Array([0, 0, 0]), "Bank empties when taken")
	var rules := PuzzleEngine.new(Campaign.load_from().level_at(3))
	rules.start()
	var before := rules.booster_stock.duplicate()
	rules.add_starting_boosters(PackedInt32Array([1, 1, -5]))
	report.check(rules.booster_stock[0] == before[0] + 1 and rules.booster_stock[2] == before[2], "Starting boosters add, negatives ignored")
