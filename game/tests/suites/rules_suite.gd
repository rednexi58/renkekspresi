extends RefCounted
## Behavioural guarantees beyond trace parity: every level is lost when idle, blocked and
## locked choices are rejected, fresh wagons are not collectible, extra slots are granted
## exactly once, boosters start correctly, reward callbacks cannot double-grant, and the
## language policy honours explicit choice before device locale.

func run(campaign: Campaign, report: TestReport) -> void:
	_idle_always_loses(campaign, report)
	_blocked_choice(campaign, report)
	_slot_grants(campaign, report)
	_reward_guard(report)
	_language_policy(report)
	_campaign_integrity(campaign, report)


func _idle_always_loses(campaign: Campaign, report: TestReport) -> void:
	for level in campaign.levels:
		var rules := PuzzleEngine.new(level)
		rules.start()
		var steps := 0
		while steps < 24000 and rules.is_playing():
			rules.tick(0.05)
			steps += 1
		report.check(rules.status == PuzzleEngine.Status.LOST, "Idle must lose L%d" % level.id)


func _blocked_choice(campaign: Campaign, report: TestReport) -> void:
	var rules := PuzzleEngine.new(campaign.level_at(20))
	rules.start()
	var blocked := -1
	for collector in rules.yard.collectors:
		if not rules.yard.is_available(collector.definition.id):
			blocked = collector.definition.id
			break
	report.check(blocked >= 0, "Level 21 has a blocked collector")
	var taps := rules.taps
	report.check(rules.choose(blocked) != PuzzleEngine.ChooseResult.OK, "Blocked choice rejected")
	report.check(rules.taps == taps, "Blocked choice is not counted as a tap")
	for wagon in rules.wagons:
		report.check(not rules.can_collect(wagon), "Fresh wagon is not collectible")
	var idle := PuzzleEngine.new(campaign.level_at(0))
	report.check(idle.choose(0) == PuzzleEngine.ChooseResult.NOT_PLAYING, "No choice before start")


func _slot_grants(campaign: Campaign, report: TestReport) -> void:
	var rules := PuzzleEngine.new(campaign.level_at(20))
	rules.start()
	report.check(rules.grant_vip() and not rules.grant_vip() and rules.slots.size() == 4, "VIP grants exactly one slot")
	report.check(rules.grant_reward_slot() and not rules.grant_reward_slot() and rules.slots.size() == 5, "Reward slot grants exactly one")
	var fresh := PuzzleEngine.new(rules.level, true)
	report.check(fresh.slots.size() == 4 and not fresh.reward_slot, "Reward slot resets per level, VIP persists")
	report.check(fresh.booster_stock == PackedInt32Array([0, 0, 1]), "Initial booster stock")
	fresh.start()
	report.check(not fresh.grant_booster(2), "Refill refused while uses remain")
	report.check(fresh.grant_booster(0) and not fresh.grant_booster(0), "Empty booster refills exactly once")


func _reward_guard(report: TestReport) -> void:
	var guard := RewardGuard.new()
	var token := guard.begin()
	report.check(guard.accept(token, true) and not guard.accept(token, true), "One reward per callback")
	token = guard.begin()
	guard.cancel()
	report.check(not guard.accept(token, true), "Stale callback rejected")
	token = guard.begin()
	report.check(not guard.accept(token, false), "Unearned reward rejected")


func _language_policy(report: TestReport) -> void:
	report.check(LanguagePolicy.resolve("", "tr_TR") == "tr", "Turkish device -> tr")
	report.check(LanguagePolicy.resolve("", "en_US") == "en", "English device -> en")
	report.check(LanguagePolicy.resolve("", "de_DE") == "en", "Other device -> en")
	report.check(LanguagePolicy.resolve("tr", "en_US") == "tr", "Explicit tr kept")
	report.check(LanguagePolicy.resolve("en", "tr_TR") == "en", "Explicit en kept")


func _campaign_integrity(campaign: Campaign, report: TestReport) -> void:
	report.check(campaign.count() == 100, "Campaign has 100 levels")
	for i in campaign.count():
		var level := campaign.levels[i]
		report.check(level.id == i + 1, "Level ids are sequential at %d" % i)
		report.check(FileAccess.file_exists("res://data/routes/route_%03d.json" % level.id), "Route file for L%d" % level.id)
