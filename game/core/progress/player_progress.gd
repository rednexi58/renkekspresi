class_name PlayerProgress
extends RefCounted
## Everything the game remembers about the player, as plain data with explicit
## (de)serialisation. Unknown or malformed fields fall back to defaults, so an old or
## damaged save never crashes the game; the schema version allows future migrations.

const SCHEMA_VERSION := 1
const LEVEL_COUNT := 100

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
## remains the source of truth and restores them on launch.
var owns_vip := false
var owns_no_ads := false
var owns_starter := false


func _init() -> void:
	best_seconds.resize(LEVEL_COUNT)


func record_win(level_index: int, seconds: int) -> void:
	if level_index < 0 or level_index >= LEVEL_COUNT:
		return
	var previous := best_seconds[level_index]
	if previous == 0 or seconds < previous:
		best_seconds[level_index] = maxi(1, seconds)
	unlocked = clampi(maxi(unlocked, level_index + 2), 1, LEVEL_COUNT)
	current_level = mini(level_index + 1, LEVEL_COUNT - 1)


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
		"owns_vip": owns_vip,
		"owns_no_ads": owns_no_ads,
		"owns_starter": owns_starter,
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
	progress.owns_vip = bool(data.get("owns_vip", false))
	progress.owns_no_ads = bool(data.get("owns_no_ads", false))
	progress.owns_starter = bool(data.get("owns_starter", false))
	return progress
