class_name GameCenterLeaderboards
extends LeaderboardService
## Game Center through the Godot iOS "GameCenter" plugin singleton. The plugin answers
## asynchronously through a pending-event queue, polled here. Times are posted in
## centiseconds so Game Center can format them as elapsed time (lower is better).

const SINGLETON := "GameCenter"

var _game_center: Object
var _authenticated := false


func _ready() -> void:
	_game_center = Engine.get_singleton(SINGLETON)
	if _game_center != null:
		_game_center.call("authenticate")


func _process(_delta: float) -> void:
	if _game_center == null:
		return
	while int(_game_center.call("get_pending_event_count")) > 0:
		var event: Variant = _game_center.call("pop_pending_event")
		if event is Dictionary and (event as Dictionary).get("type", "") == "authentication":
			_authenticated = (event as Dictionary).get("result", "") == "ok"


func is_available() -> bool:
	return _game_center != null and _authenticated


func submit_level_time(level_id: int, seconds: int) -> void:
	_post(level_board(level_id), maxi(1, seconds) * 100)


func submit_furthest(level: int) -> void:
	_post(FURTHEST_BOARD, level)


func show_board(board: String = "") -> void:
	if not is_available():
		return
	var options := {"view": "leaderboards"}
	if not board.is_empty():
		options["leaderboard_name"] = board
	_game_center.call("show_game_center", options)


func _post(board: String, score: int) -> void:
	if is_available():
		_game_center.call("post_score", {"score": score, "category_id": board})
