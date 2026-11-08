extends SceneTree
## Development tool: runs the real game scene, optionally auto-plays a level's authored
## solution, and saves screenshots for visual review.
##
##   godot --path game --rendering-driver opengl3 --resolution 1080x1920 \
##     --script res://tools/capture.gd -- --level=12 --out=/tmp/shot --times=0.5,6,20 [--play]

var _main: Main
var _times: PackedFloat64Array = PackedFloat64Array([1.0])
var _out := "/tmp/capture"
var _play := false
var _solution: Array = []
var _next_pick := 0
var _clock := 0.0
var _shot := 0
var _unlock := 0
var _unlocked := false


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.get_slice("=", 1)
		elif argument.begins_with("--times="):
			_times = PackedFloat64Array()
			for part in argument.get_slice("=", 1).split(","):
				_times.append(float(part))
		elif argument.begins_with("--unlock="):
			_unlock = int(argument.get_slice("=", 1))
		elif argument == "--play":
			_play = true
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(delta: float) -> bool:
	_clock += delta
	if _unlock > 0 and not _unlocked and _main.session != null and _main.session.is_active():
		# Exercises the real offer flows (debug commerce grants instantly).
		_unlocked = true
		_main._offer_vip()
		_main.dialog.dismiss()
		for i in _unlock:
			_main._offer_reward_slot()
	if _play and _main.session != null and _main.session.is_active():
		if _solution.is_empty():
			_solution = _load_solution(_main.level_index)
		# Send the next collector of the solution as soon as a slot is free.
		if _next_pick < _solution.size() and _main.session.engine.occupied_slots() < _main.session.engine.slots.size():
			_main.session.choose(int(_solution[_next_pick]))
			_next_pick += 1
	if _shot < _times.size() and _clock >= _times[_shot]:
		var image := root.get_viewport().get_texture().get_image()
		image.save_png("%s_%d.png" % [_out, _shot])
		print("saved %s_%d.png at %.1fs" % [_out, _shot, _clock])
		_shot += 1
	return _shot >= _times.size()


func _load_solution(index: int) -> Array:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json"))
	return data["levels"][index]["design"]["solution"]
