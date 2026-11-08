class_name LeaderboardService
extends Node
## Rankings: the fastest time for each level and the furthest level reached. The base
## class is the offline fallback (submissions are no-ops, personal records live in
## PlayerProgress); GameCenterLeaderboards posts to Apple Game Center when the native
## plugin is present. Game flow only calls this interface.

const BOARD_PREFIX := "com.bedogames.renkekspresi.lb."
const FURTHEST_BOARD := BOARD_PREFIX + "furthest"


static func level_board(level_id: int) -> String:
	return BOARD_PREFIX + "level%03d" % level_id


static func create() -> LeaderboardService:
	if Engine.has_singleton(GameCenterLeaderboards.SINGLETON):
		return GameCenterLeaderboards.new()
	return LeaderboardService.new()


## True when global rankings can be shown (signed in to a ranking service).
func is_available() -> bool:
	return false


func submit_level_time(_level_id: int, _seconds: int) -> void:
	pass


func submit_furthest(_level: int) -> void:
	pass


## Opens the system rankings UI on `board` (empty for the overview).
func show_board(_board: String = "") -> void:
	pass
