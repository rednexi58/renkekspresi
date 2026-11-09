class_name Economy
extends RefCounted
## Every number of the in-game economy in one place: coin rewards, prices in coins,
## the piggy bank, daily rewards and ad pacing. Pure data and arithmetic so balancing
## never touches game flow and is covered by tests.

const WIN_COINS := 20
const CLEAN_WIN_BONUS := 10
const DOUBLE_REWARD_FACTOR := 2
const REVIVE_COST := 150
const REVIVE_LIMIT := 2
const BOOSTER_COSTS := [90, 120, 60]
const PIGGY_PER_WIN := 30
const PIGGY_CAPACITY := 1500
const PIGGY_MIN_TO_BREAK := 300
const DAILY_REWARDS := [50, 75, 100, 150, 200, 250, 500]
## Interstitials: one every INTERSTITIAL_EVERY_WINS wins, from level INTERSTITIAL_FROM_LEVEL+1.
## The first five levels stay ad-free because that is where most players decide whether to
## keep the game; an ad there costs more players than it earns.
const INTERSTITIAL_FROM_LEVEL := 5
const INTERSTITIAL_EVERY_WINS := 2


static func win_coins(assisted: bool) -> int:
	return WIN_COINS + (0 if assisted else CLEAN_WIN_BONUS)


static func booster_cost(kind: int) -> int:
	return BOOSTER_COSTS[clampi(kind, 0, BOOSTER_COSTS.size() - 1)]


static func piggy_after_win(current: int) -> int:
	return mini(PIGGY_CAPACITY, current + PIGGY_PER_WIN)


## Reward for the day of a streak (1-based); the streak repeats after seven days.
static func daily_reward(streak_day: int) -> int:
	return DAILY_REWARDS[(maxi(1, streak_day) - 1) % DAILY_REWARDS.size()]


static func interstitial_due(level_index: int, wins_since_last: int, no_ads: bool) -> bool:
	return not no_ads and level_index >= INTERSTITIAL_FROM_LEVEL and wins_since_last >= INTERSTITIAL_EVERY_WINS
