class_name DailyReward
extends RefCounted
## Seven-day login streak. Days are counted in whole days since the Unix epoch in the
## player's local time; missing a day restarts the streak at day one.


static func today() -> int:
	var bias_minutes := int(Time.get_time_zone_from_system().get("bias", 0))
	var now: float = Time.get_unix_time_from_system() + bias_minutes * 60.0
	return int(floor(now / 86400.0))


static func can_claim(progress: PlayerProgress, day: int) -> bool:
	return progress.daily_last_day != day


## Day of the streak a claim made on `day` would count as (1-based).
static func next_streak(progress: PlayerProgress, day: int) -> int:
	return progress.daily_streak + 1 if progress.daily_last_day == day - 1 else 1


## Applies the claim and returns the coins granted (0 if already claimed today).
static func claim(progress: PlayerProgress, day: int) -> int:
	if not can_claim(progress, day):
		return 0
	progress.daily_streak = next_streak(progress, day)
	progress.daily_last_day = day
	var coins := Economy.daily_reward(progress.daily_streak)
	progress.add_coins(coins)
	return coins
