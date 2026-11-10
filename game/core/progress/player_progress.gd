class_name PlayerProgress
extends RefCounted
## Everything the game remembers about the player, as plain data with explicit
## (de)serialisation. Unknown or malformed fields fall back to defaults, so an old or
## damaged save never crashes the game; the schema version allows future migrations.

const SCHEMA_VERSION := 1
const LEVEL_COUNT := 200
const DELIVERED_MEMORY := 64

var unlocked := 1
var current_level := 0
var best_seconds := PackedInt32Array()
var coins := 0
var piggy_coins := 0
var language := ""
var music_on := true
var sound_on := true
var haptics_on := true
var tutorial_done := false
var wins_since_interstitial := 0
var daily_last_day := -1
var daily_streak := 0
var skins_owned := PackedStringArray(["classic"])
var skin_selected := "classic"
## Mirrors of store entitlements so the game starts correctly offline; the store
## remains the source of truth and refreshes them on launch and on resume.
## `vip_until` is the end of the current VIP subscription period (Unix seconds).
var vip_until := 0
var owns_no_ads := false
var owns_starter := false
## StoreKit transaction ids already fulfilled, so a transaction reported again (e.g. by
## the next launch) is never granted twice. Only the newest DELIVERED_MEMORY are kept.
var delivered_transactions := PackedStringArray()
## Best stars (0-3) per level, stars waiting in the star chest, the current win streak,
## boosters banked for the next level, and the levels whose mechanic intro was shown.
var stars := PackedByteArray()
var chest_stars := 0
var win_streak := 0
var booster_bank := PackedInt32Array([0, 0, 0])
var intros_seen := PackedInt32Array()


func _init() -> void:
	best_seconds.resize(LEVEL_COUNT)
	stars.resize(LEVEL_COUNT)


func record_win(level_index: int, seconds: int) -> void:
	if level_index < 0 or level_index >= LEVEL_COUNT:
		return
	var previous := best_seconds[level_index]
	if previous == 0 or seconds < previous:
		best_seconds[level_index] = maxi(1, seconds)
	unlocked = clampi(maxi(unlocked, level_index + 2), 1, LEVEL_COUNT)
	current_level = mini(level_index + 1, LEVEL_COUNT - 1)


## Keeps the best star count of a level; returns how many stars were newly earned
## (those, and only those, go into the star chest).
func record_stars(level_index: int, earned: int) -> int:
	if level_index < 0 or level_index >= LEVEL_COUNT:
		return 0
	var gained := maxi(0, clampi(earned, 0, 3) - stars[level_index])
	if gained > 0:
		stars[level_index] = clampi(earned, 0, 3)
		chest_stars += gained
	return gained


func total_stars() -> int:
	var total := 0
	for value in stars:
		total += value
	return total


## Furthest level completed (1-based), 0 when none.
func furthest_level() -> int:
	for i in range(LEVEL_COUNT - 1, -1, -1):
		if best_seconds[i] > 0:
			return i + 1
	return 0


## Takes every banked booster out of the bank (they are granted at a level start).
func take_booster_bank() -> PackedInt32Array:
	var taken := booster_bank.duplicate()
	booster_bank = PackedInt32Array([0, 0, 0])
	return taken


## VIP is active while the subscription period has not ended.
func has_vip(now: int) -> bool:
	return vip_until > now


## No interstitials for No Ads owners and active VIP members.
func is_ad_free(now: int) -> bool:
	return owns_no_ads or has_vip(now)


## Records a fulfilled transaction; false if it was already fulfilled.
func mark_delivered(transaction_id: String) -> bool:
	if transaction_id.is_empty():
		return true
	if delivered_transactions.has(transaction_id):
		return false
	delivered_transactions.append(transaction_id)
	while delivered_transactions.size() > DELIVERED_MEMORY:
		delivered_transactions.remove_at(0)
	return true


func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)


## Spends coins if affordable; returns false (and changes nothing) otherwise.
func spend_coins(amount: int) -> bool:
	if amount < 0 or coins < amount:
		return false
	coins -= amount
	return true


func owns_skin(id: String) -> bool:
	return skins_owned.has(id)


func to_dict() -> Dictionary:
	return {
		"version": SCHEMA_VERSION,
		"unlocked": unlocked,
		"current_level": current_level,
		"best_seconds": Array(best_seconds),
		"coins": coins,
		"piggy_coins": piggy_coins,
		"language": language,
		"music_on": music_on,
		"sound_on": sound_on,
		"haptics_on": haptics_on,
		"tutorial_done": tutorial_done,
		"wins_since_interstitial": wins_since_interstitial,
		"daily_last_day": daily_last_day,
		"daily_streak": daily_streak,
		"skins_owned": Array(skins_owned),
		"skin_selected": skin_selected,
		"vip_until": vip_until,
		"delivered_transactions": Array(delivered_transactions),
		"owns_no_ads": owns_no_ads,
		"owns_starter": owns_starter,
		"stars": Array(stars),
		"chest_stars": chest_stars,
		"win_streak": win_streak,
		"booster_bank": Array(booster_bank),
		"intros_seen": Array(intros_seen),
	}


static func from_dict(data: Dictionary) -> PlayerProgress:
	var progress := PlayerProgress.new()
	progress.unlocked = clampi(int(data.get("unlocked", 1)), 1, LEVEL_COUNT)
	progress.current_level = clampi(int(data.get("current_level", 0)), 0, progress.unlocked - 1)
	var best: Variant = data.get("best_seconds", [])
	if best is Array:
		for i in mini(LEVEL_COUNT, (best as Array).size()):
			progress.best_seconds[i] = maxi(0, int((best as Array)[i]))
	progress.coins = maxi(0, int(data.get("coins", 0)))
	progress.piggy_coins = clampi(int(data.get("piggy_coins", 0)), 0, Economy.PIGGY_CAPACITY)
	progress.language = str(data.get("language", ""))
	progress.music_on = bool(data.get("music_on", true))
	progress.sound_on = bool(data.get("sound_on", true))
	progress.haptics_on = bool(data.get("haptics_on", true))
	progress.tutorial_done = bool(data.get("tutorial_done", false))
	progress.wins_since_interstitial = maxi(0, int(data.get("wins_since_interstitial", 0)))
	progress.daily_last_day = int(data.get("daily_last_day", -1))
	progress.daily_streak = maxi(0, int(data.get("daily_streak", 0)))
	var skins: Variant = data.get("skins_owned", ["classic"])
	if skins is Array:
		progress.skins_owned = PackedStringArray()
		for id: Variant in skins:
			progress.skins_owned.append(str(id))
	if not progress.skins_owned.has("classic"):
		progress.skins_owned.append("classic")
	var selected := str(data.get("skin_selected", "classic"))
	progress.skin_selected = selected if progress.skins_owned.has(selected) else "classic"
	progress.vip_until = maxi(0, int(data.get("vip_until", 0)))
	var delivered: Variant = data.get("delivered_transactions", [])
	if delivered is Array:
		for id: Variant in delivered:
			progress.delivered_transactions.append(str(id))
	progress.owns_no_ads = bool(data.get("owns_no_ads", false))
	progress.owns_starter = bool(data.get("owns_starter", false))
	var saved_stars: Variant = data.get("stars", [])
	if saved_stars is Array:
		for i in mini(LEVEL_COUNT, (saved_stars as Array).size()):
			progress.stars[i] = clampi(int((saved_stars as Array)[i]), 0, 3)
	progress.chest_stars = maxi(0, int(data.get("chest_stars", 0)))
	progress.win_streak = maxi(0, int(data.get("win_streak", 0)))
	var bank: Variant = data.get("booster_bank", [])
	if bank is Array:
		for i in mini(3, (bank as Array).size()):
			progress.booster_bank[i] = clampi(int((bank as Array)[i]), 0, 99)
	var seen: Variant = data.get("intros_seen", [])
	if seen is Array:
		for value: Variant in seen:
			progress.intros_seen.append(clampi(int(value), 0, LEVEL_COUNT - 1))
	return progress
