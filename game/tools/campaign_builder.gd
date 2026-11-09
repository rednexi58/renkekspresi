extends SceneTree
## Builds the 200-level campaign (development tool, not shipped).
##
## Train mix: from level 9 on, every third level has several trains — two up to level 30,
## then two or three, mixed. All other levels have one train.
##
## Levels 1-100 start from the recorded v0.34 designs (tests/fixtures/campaign_v034.json
## and tools/route_pool). A level keeps its original design when its train count is
## unchanged; otherwise its train is rebuilt for the new count from its authored solution.
## Levels 101-200 are generated: a yard is filled with collectors, a solution order is
## found by actually releasing collectors, and the train is laid out from that order.
##
## Every level is accepted only if SolutionPlayer wins it with the shipped RulesTuning
## and its ideal-play peak danger lies in a band that rises with the level; otherwise the
## approach speed (and for generated levels, the design seed) is adjusted and it retries.
##
##   godot --headless --path game --script res://tools/campaign_builder.gd

const SOURCE := "res://tests/fixtures/campaign_v034.json"
const POOL := "res://tools/route_pool/route_%03d.json"
const OUT_CAMPAIGN := "res://data/campaign.json"
const OUT_ROUTE := "res://data/routes/route_%03d.json"
const LEVELS := 200
const FIRST_MULTI := 9
const MULTI_EVERY := 3
const THREE_TRAINS_FROM := 31
const SEED := 20261109
const MAX_ATTEMPTS := 24
const PARAMS := {
	1: {"approach": 1.0, "recoil": 1.334, "loading": 0.675},
	2: {"approach": 0.8, "recoil": 0.9, "loading": 0.4},
	3: {"approach": 0.72, "recoil": 0.828, "loading": 0.5},
}

var _random := RandomNumberGenerator.new()
var _pool := {1: [], 2: [], 3: []}
var _pool_next := {1: 0, 2: 0, 3: 0}


func _initialize() -> void:
	_random.seed = SEED
	_load_pool()
	var source: Array = (JSON.parse_string(FileAccess.get_file_as_string(SOURCE)) as Dictionary)["levels"]
	var levels: Array = []
	var routes: Array = []
	var report := PackedStringArray()
	var only := 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = int(argument.get_slice("=", 1))
	for id in range(1, LEVELS + 1):
		if only > 0 and id != only and id <= source.size():
			continue
		var lanes := _lanes_for(id)
		var built: Array
		if id <= source.size():
			built = _from_source(source[id - 1], id, lanes)
		else:
			built = _generated(id, lanes)
		if built.is_empty():
			push_error("Level %d could not be built" % id)
			quit(1)
			return
		levels.append(built[0])
		routes.append(built[1])
		report.append("L%03d lanes %d wagons %3d danger %.2f %s" % [id, lanes, (built[0]["train"] as Array).size(), built[2], built[3]])
	if only > 0:
		quit()
		return
	_write(levels, routes)
	print("\n".join(report))
	print("built %d levels" % levels.size())
	quit()


## How many trains level `id` has (see the class comment).
func _lanes_for(id: int) -> int:
	if id < FIRST_MULTI or id % MULTI_EVERY != 0:
		return 1
	if id < THREE_TRAINS_FROM:
		return 2
	var mix := RandomNumberGenerator.new()
	mix.seed = SEED + id
	return 3 if mix.randf() < 0.5 else 2


# --- Levels 1-100 --------------------------------------------------------------------

func _from_source(original: Dictionary, id: int, lanes: int) -> Array:
	var original_lanes := int(original.get("train_count", 1))
	var original_route := _read_json(POOL % id)
	if original_lanes == lanes:
		var level := original.duplicate(true)
		var result := _accept(level, original_route, id, true)
		if not result.is_empty():
			return result + ["original"]
	var rebuilt := original.duplicate(true)
	return _relaid(rebuilt, id, lanes, "rebuilt from %d trains" % original_lanes)


## Lays the level's train out again for `lanes` trains from its authored solution, with a
## route of that many lanes, retrying stream splits and pacing until it is accepted.
func _relaid(level: Dictionary, id: int, lanes: int, note: String) -> Array:
	var route := _next_route(lanes)
	var solution: Array = level["design"]["solution"]
	for attempt in MAX_ATTEMPTS:
		_lay_train(level, solution, lanes, attempt)
		_apply_params(level, lanes, route, id)
		var result := _accept(level, route, id, false)
		if not result.is_empty():
			return result + [note]
		if attempt % 6 == 5:
			route = _next_route(lanes)
	return []


# --- Levels 101-200 ------------------------------------------------------------------

func _generated(id: int, lanes: int) -> Array:
	for design_try in MAX_ATTEMPTS:
		var level := _new_yard(id, design_try)
		if level.is_empty():
			continue
		var result := _relaid(level, id, lanes, "generated")
		if not result.is_empty():
			return result
	return []


## A yard sized and coloured for the level's place in the campaign, with a solution found
## by releasing collectors one by one (prefering ones that free others, so the order is
## not simply top-to-bottom). Empty when the random yard deadlocks.
func _new_yard(id: int, design_try: int) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = SEED * 7 + id * 131 + design_try
	var progress := float(id - 101) / 99.0
	var rows := 6
	var cols := 3 if progress < 0.5 else 4
	var colours := 4 if progress < 0.25 else (5 if progress < 0.75 else 6)
	var empty_cells := random.randi_range(0, 2)
	var cells: Array[Vector2i] = []
	for row in rows:
		for col in cols:
			cells.append(Vector2i(col, row))
	_shuffle(cells, random)
	cells.resize(cells.size() - empty_cells)
	var directions := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var parking: Array = []
	for i in cells.size():
		var direction: Vector2i = directions[random.randi_range(0, 3)]
		parking.append({"id": i, "row": cells[i].y, "col": cells[i].x, "dx": direction.x, "dz": direction.y,
			"color": i % colours, "capacity": random.randi_range(8 + int(progress * 2.0), 10 + int(progress * 2.0)), "requires": -1})
	_shuffle_colours(parking, random)
	if id >= 120 and random.randf() < 0.45:
		_add_key_lock(parking, random)
	var level := {
		"id": id, "rows": rows, "cols": cols, "parking": parking, "theme": random.randi_range(0, 5),
		"map_seed": random.randi_range(1000, 99999), "dispatch_seconds": 0.32, "collector_capacity": 5,
		"difficulty": 8 + int(progress * 4.0), "layout": 0, "shape": 0, "mode": "rescue", "match_scope": "zone",
		"name": "", "region": "", "lesson": "",
		"design": {"generation_seed": random.seed, "rules_version": "builder-1", "solution": []},
	}
	var solution := _release_order(parking, random)
	if solution.size() != parking.size():
		return {}
	level["design"]["solution"] = solution
	return level


## Order in which every collector can leave the yard. When the random arrows deadlock,
## one stuck collector is turned to a direction whose path is clear (the outermost
## collector always has one), so every generated yard is solvable. Mirrors the rules of
## CollectorYard; the result is still verified by playing it with the real engine.
func _release_order(parking: Array, random: RandomNumberGenerator) -> Array:
	var parked := {}
	for entry: Dictionary in parking:
		parked[int(entry["id"])] = true
	var order: Array = []
	while not parked.is_empty():
		var open: Array[int] = []
		for id: int in parked:
			if _can_leave(parking, parked, id, Vector2i(int(parking[id]["dx"]), int(parking[id]["dz"]))):
				open.append(id)
		if open.is_empty():
			open.append(_repair(parking, parked, random))
		if open[0] < 0:
			return order
		var pick: int = open[random.randi_range(0, open.size() - 1)]
		order.append(pick)
		parked.erase(pick)
	return order


func _can_leave(parking: Array, parked: Dictionary, id: int, direction: Vector2i) -> bool:
	var own: Dictionary = parking[id]
	var key := int(own.get("requires", -1))
	if key >= 0 and parked.has(key):
		return false
	for other: int in parked:
		if other == id:
			continue
		var x := int(parking[other]["col"]) - int(own["col"])
		var z := int(parking[other]["row"]) - int(own["row"])
		if x * direction.y == z * direction.x and x * direction.x + z * direction.y > 0:
			return false
	return true


## Turns one parked, unlocked collector towards a clear path; returns its id or -1.
func _repair(parking: Array, parked: Dictionary, random: RandomNumberGenerator) -> int:
	var ids: Array = parked.keys()
	_shuffle(ids, random)
	var directions: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for id: int in ids:
		_shuffle(directions, random)
		for direction: Vector2i in directions:
			if _can_leave(parking, parked, id, direction):
				parking[id]["dx"] = direction.x
				parking[id]["dz"] = direction.y
				return id
	return -1


func _add_key_lock(parking: Array, random: RandomNumberGenerator) -> void:
	var key := random.randi_range(0, parking.size() - 1)
	var locked := random.randi_range(0, parking.size() - 1)
	if key != locked:
		parking[key]["key"] = "A"
		parking[locked]["requires"] = key


# --- Train layout and acceptance ------------------------------------------------------

## Single train: each collector of the solution contributes its capacity of its colour.
## Several trains: each collector's wagons are cut into short runs dealt across the
## trains, so every train carries the colours in roughly solution order.
func _lay_train(level: Dictionary, solution: Array, lanes: int, attempt: int) -> void:
	var parking: Array = level["parking"]
	if lanes == 1:
		var train: Array = []
		for id: Variant in solution:
			for wagon in int(parking[int(id)]["capacity"]):
				train.append(int(parking[int(id)]["color"]))
		level["train"] = train
		level.erase("wagon_streams")
		level["train_count"] = 1
		return
	var random := RandomNumberGenerator.new()
	random.seed = SEED + int(level["id"]) * 977 + attempt
	var per_lane: Array = []
	for lane in lanes:
		per_lane.append([])
	var lane := random.randi_range(0, lanes - 1)
	for id: Variant in solution:
		var remaining := int(parking[int(id)]["capacity"])
		while remaining > 0:
			var run := mini(remaining, random.randi_range(2, 4))
			for wagon in run:
				per_lane[lane].append(int(parking[int(id)]["color"]))
			remaining -= run
			lane = (lane + 1) % lanes
	var train: Array = []
	var streams: Array = []
	for index in lanes:
		for colour: int in per_lane[index]:
			train.append(colour)
			streams.append(index)
	level["train"] = train
	level["wagon_streams"] = streams
	level["train_count"] = lanes


func _apply_params(level: Dictionary, lanes: int, route: Dictionary, id: int) -> void:
	var params: Dictionary = PARAMS[lanes]
	var era := clampf(float(id - 30) / 170.0, 0.0, 1.0)
	level["approach_speed"] = params["approach"] * (1.0 + 0.06 * era)
	level["recoil_per_unit"] = params["recoil"]
	level["loading_fraction"] = params["loading"]
	level["track_length"] = float(route["routes"][0]["length"])
	if lanes > 1:
		var shortest := INF
		for lane_route: Dictionary in route["routes"]:
			shortest = minf(shortest, float(lane_route["length"]))
		level["track_length"] = shortest


## Danger band the ideal run must land in: gentle early, tense late.
static func danger_band(id: int) -> Vector2:
	var t := clampf(float(id - 1) / 199.0, 0.0, 1.0)
	return Vector2(0.35 + 0.2 * t, 0.8 + 0.12 * t)


## Plays the level; nudges the approach speed into the danger band. Returns
## [level, route, peak danger] or [] if no speed within limits is accepted.
func _accept(level: Dictionary, route: Dictionary, id: int, keep_speed: bool) -> Array:
	var band := danger_band(id)
	for step in 8:
		var definition := LevelDefinition.from_dict(level)
		var result := SolutionPlayer.play(definition, level["design"]["solution"], RulesTuning.standard())
		if OS.get_cmdline_user_args().has("--verbose"):
			print("  L%d step %d speed %.3f won %s danger %.2f t %.0f" % [id, step, level["approach_speed"], result.won, result.peak_danger, result.seconds])
		if result.won and (keep_speed or (result.peak_danger >= band.x and result.peak_danger <= band.y)):
			return [level, route, result.peak_danger]
		if keep_speed and not result.won:
			return []
		var too_hard := not result.won or result.peak_danger > band.y
		level["approach_speed"] = float(level["approach_speed"]) * (0.9 if too_hard else 1.1)
	return []


# --- Data helpers --------------------------------------------------------------------

func _load_pool() -> void:
	for id in range(1, 101):
		var route := _read_json(POOL % id)
		var lanes := (route["routes"] as Array).size()
		if _pool.has(lanes):
			_pool[lanes].append(route)


func _next_route(lanes: int) -> Dictionary:
	var choices: Array = _pool[lanes]
	var route: Dictionary = choices[_pool_next[lanes] % choices.size()]
	_pool_next[lanes] += 1
	return route.duplicate(true)


func _shuffle(values: Array, random: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := random.randi_range(0, i)
		var held: Variant = values[i]
		values[i] = values[j]
		values[j] = held


func _shuffle_colours(parking: Array, random: RandomNumberGenerator) -> void:
	var colours: Array = []
	for entry: Dictionary in parking:
		colours.append(entry["color"])
	_shuffle(colours, random)
	for i in parking.size():
		parking[i]["color"] = colours[i]


func _read_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _write(levels: Array, routes: Array) -> void:
	var dir := DirAccess.open("res://data/routes")
	for file in dir.get_files():
		if file.begins_with("route_") and file.ends_with(".json"):
			dir.remove(file)
	for i in routes.size():
		var file := FileAccess.open(OUT_ROUTE % (i + 1), FileAccess.WRITE)
		file.store_string(JSON.stringify(routes[i]))
	var campaign := FileAccess.open(OUT_CAMPAIGN, FileAccess.WRITE)
	campaign.store_string(JSON.stringify({"levels": levels}, " "))
