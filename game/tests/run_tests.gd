extends SceneTree
## Headless test entry point (also used by CI):
##   godot --headless --path game --script res://tests/run_tests.gd
## Exits with code 0 on success and 1 on the first failing suite.

const SUITES := {
	"rules": "res://tests/suites/rules_suite.gd",
	"parity": "res://tests/suites/parity_suite.gd",
	"presentation": "res://tests/suites/presentation_suite.gd",
	"meta": "res://tests/suites/meta_suite.gd",
}


var _started := false


## Suites run on the first frame rather than in _initialize so that nodes added to the
## root are fully inside the scene tree (cameras can project, tweens can run).
func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run_all()
	return false


func _run_all() -> void:
	var campaign := Campaign.load_from()
	if campaign == null:
		printerr("FAIL: campaign could not be loaded")
		quit(1)
		return
	var total := 0
	for suite_name: String in SUITES:
		var script := load(SUITES[suite_name]) as GDScript
		if script == null or not script.can_instantiate():
			printerr("FAIL [%s] suite script failed to compile" % suite_name)
			quit(1)
			return
		var suite: RefCounted = script.new()
		if "tree" in suite:
			suite.tree = self
		var report := TestReport.new()
		var started := Time.get_ticks_msec()
		suite.run(campaign, report)
		total += report.assertions
		if not report.passed():
			printerr("FAIL [%s] %d failure(s). First: %s" % [suite_name, report.failures.size(), report.failures[0]])
			quit(1)
			return
		var extra := ""
		if suite_name == "parity":
			extra = " (%d traces, %d snapshots)" % [suite.cases, suite.snapshots]
		print("PASS [%s] %d assertions%s in %d ms" % [suite_name, report.assertions, extra, Time.get_ticks_msec() - started])
	print("ALL TESTS PASSED: %d assertions" % total)
	quit(0)
