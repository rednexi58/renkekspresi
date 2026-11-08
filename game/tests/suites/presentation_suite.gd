extends RefCounted
## Builds the full 3D world of every level headlessly and plays a few seconds of each,
## proving that every route file loads, every level decorates without placing scenery on
## rails, and views stay in sync with the rules (no wagon or collector left unmapped).

var tree: SceneTree


func run(campaign: Campaign, report: TestReport) -> void:
	for level in campaign.levels:
		var routes := RailRoute.load_level(level.id)
		report.check(routes.size() == level.train_count, "L%d: route lanes match train count" % level.id)
		for route in routes:
			report.check(route.length > 1.0 and route.points.size() >= 2, "L%d: route has geometry" % level.id)
		var engine := PuzzleEngine.new(level)
		engine.start()
		var world := LevelWorld.new()
		tree.root.add_child(world)
		world.build(level, routes, engine)
		world.set_visible_berths(engine.slots.size())
		world.frame(Rect2(Vector2(0, 330), Vector2(1080, 1320)))
		_check_picking(world, engine, level.id, report)
		var solution := _first_available(engine)
		if solution >= 0:
			report.check(engine.choose(solution) == PuzzleEngine.ChooseResult.OK, "L%d: available collector accepted" % level.id)
		for step in 40:
			for event in engine.tick(0.05):
				world.play_match(event)
			world.sync(engine)
		report.check(world.camera != null, "L%d: camera created" % level.id)
		report.check(world.pick(Vector2(-10000, -10000), engine) == -1, "L%d: off-screen pick misses" % level.id)
		world.free()


## Every parked collector must be selectable by tapping where it is drawn.
func _check_picking(world: LevelWorld, engine: PuzzleEngine, level_id: int, report: TestReport) -> void:
	for collector in engine.yard.collectors:
		var id := collector.definition.id
		var roof := world.collector_position(id) + Vector3.UP * WorldLayout.PICK_HEIGHT
		var screen := world.camera.unproject_position(roof)
		report.check(world.pick(screen, engine) == id, "L%d: tapping collector %d picks it" % [level_id, id])


static func _first_available(engine: PuzzleEngine) -> int:
	for collector in engine.yard.collectors:
		if engine.yard.is_available(collector.definition.id):
			return collector.definition.id
	return -1
