extends RefCounted
## Behavioural guarantees beyond trace parity: every level is lost when idle, blocked and
## locked choices are rejected, fresh wagons are not collectible, extra slots are granted
## exactly once, boosters start correctly, reward callbacks cannot double-grant, and the
## language policy honours explicit choice before device locale.

func run(campaign: Campaign, report: TestReport) -> void:
	_idle_always_loses(campaign, report)
	_blocked_choice(campaign, report)
	_slot_grants(campaign, report)
	_revive(campaign, report)
	_economy_and_progress(report)
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
	report.check(rules.slots.size() == 3, "Three slots are always open")
	report.check(rules.grant_vip() and not rules.grant_vip() and rules.slots.size() == 4, "VIP grants exactly one slot")
	for i in 4:
		report.check(rules.grant_reward_slot(), "Reward slot %d unlocks" % (i + 1))
	report.check(not rules.grant_reward_slot() and not rules.can_grant_reward_slot(), "No more than four reward slots")
	report.check(rules.slots.size() == 8, "Eight slots in total")
	report.check(rules.slot_kinds.count(PuzzleEngine.SlotKind.REWARD) == 4 and rules.slot_kinds.count(PuzzleEngine.SlotKind.VIP) == 1, "Slot kinds recorded")
	var ads_first := PuzzleEngine.new(rules.level)
	ads_first.start()
	ads_first.grant_reward_slot()
	ads_first.grant_vip()
	report.check(ads_first.slot_kinds[3] == PuzzleEngine.SlotKind.REWARD and ads_first.slot_kinds[4] == PuzzleEngine.SlotKind.VIP, "Unlock order is kept per slot")
	var fresh := PuzzleEngine.new(rules.level, true)
	report.check(fresh.slots.size() == 4 and fresh.reward_slots_granted == 0, "Reward slots reset per level, VIP persists")
	report.check(not fresh.grant_reward_slot(), "No reward slot before the level starts")
	report.check(fresh.booster_stock == PackedInt32Array([0, 0, 1]), "Initial booster stock")
	fresh.start()
	report.check(not fresh.grant_booster(2), "Refill refused while uses remain")
	report.check(fresh.grant_booster(0) and not fresh.grant_booster(0), "Empty booster refills exactly once")


func _revive(campaign: Campaign, report: TestReport) -> void:
	var rules := PuzzleEngine.new(campaign.level_at(4))
	report.check(not rules.revive(), "Cannot revive before losing")
	rules.start()
	while rules.is_playing():
		rules.tick(0.05)
	report.check(rules.status == PuzzleEngine.Status.LOST, "Idle level is lost")
	var wagons_before := rules.wagons.size()
	report.check(rules.revive() and rules.is_playing(), "Revive resumes play")
	report.check(rules.danger() < 0.7 and rules.freeze_left > 0.0 and rules.assisted, "Revive pushes back, freezes and counts as assisted")
	report.check(rules.wagons.size() == wagons_before, "Revive keeps every wagon")
	var head := rules.heads[0]
	var behind := true
	for wagon in rules.wagons:
		behind = behind and wagon.distance < head
	report.check(behind, "Wagons stay behind the engine after revive")


func _economy_and_progress(report: TestReport) -> void:
	report.check(Economy.win_coins(false) == 30 and Economy.win_coins(true) == 20, "Clean wins earn a bonus")
	report.check(Economy.piggy_after_win(Economy.PIGGY_CAPACITY - 5) == Economy.PIGGY_CAPACITY, "Piggy bank is capped")
	report.check(Economy.daily_reward(1) == 50 and Economy.daily_reward(7) == 500 and Economy.daily_reward(8) == 50, "Daily rewards cycle weekly")
	report.check(not Economy.interstitial_due(3, 5, false) and Economy.interstitial_due(10, 3, false) and not Economy.interstitial_due(10, 3, true), "Interstitial pacing and no-ads")
	var progress := PlayerProgress.new()
	progress.record_win(0, 42)
	progress.record_win(0, 50)
	report.check(progress.unlocked == 2 and progress.best_seconds[0] == 42 and progress.current_level == 1, "Wins unlock and keep best time")
	progress.add_coins(100)
	report.check(not progress.spend_coins(150) and progress.coins == 100 and progress.spend_coins(60) and progress.coins == 40, "Coins cannot go negative")
	var day := 20000
	report.check(DailyReward.claim(progress, day) == 50 and DailyReward.claim(progress, day) == 0, "One daily claim per day")
	report.check(DailyReward.claim(progress, day + 1) == 75 and DailyReward.claim(progress, day + 3) == 50, "Streak grows daily, resets after a gap")
	progress.skins_owned.append("crimson")
	progress.skin_selected = "crimson"
	var copy := PlayerProgress.from_dict(progress.to_dict())
	report.check(copy.to_dict() == progress.to_dict(), "Progress round-trips through serialisation")
	var buyer := PlayerProgress.new()
	report.check(PurchaseFulfillment.fulfil(ProductCatalog.STARTER, buyer) == 1500 and buyer.owns_vip and buyer.owns_skin("golden"), "Starter pack grants coins, VIP and livery")
	report.check(PurchaseFulfillment.fulfil(ProductCatalog.NO_ADS, buyer) == 2000 and buyer.owns_no_ads, "No Ads grants coins and removes interstitials")
	buyer.piggy_coins = 420
	report.check(PurchaseFulfillment.fulfil(ProductCatalog.PIGGY, buyer) == 420 and buyer.piggy_coins == 0, "Piggy bank pays out what it holds")
	var unavailable := UnavailableCommerce.new()
	report.check(not unavailable.can_purchase(ProductCatalog.VIP) and not unavailable.can_show_rewarded() and unavailable.price(ProductCatalog.VIP) == "", "Release default offers nothing")
	var damaged := PlayerProgress.from_dict({"unlocked": "x", "coins": -50, "skin_selected": "missing", "best_seconds": "bad"})
	report.check(damaged.unlocked == 1 and damaged.coins == 0 and damaged.skin_selected == "classic", "Damaged save falls back to defaults")


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
