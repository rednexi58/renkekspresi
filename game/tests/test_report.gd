class_name TestReport
extends RefCounted
## Minimal assertion collector shared by all suites. Fails fast per suite so the first
## divergence is reported with full context instead of thousands of follow-on errors.

var assertions := 0
var failures: PackedStringArray = PackedStringArray()
const NEAR_TOLERANCE := 0.00025


func check(ok: bool, message: String) -> bool:
	assertions += 1
	if not ok:
		failures.append(message)
	return ok


func near(actual: float, expected: float, message: String) -> bool:
	return check(absf(actual - expected) < NEAR_TOLERANCE, "%s: %s != %s" % [message, actual, expected])


func passed() -> bool:
	return failures.is_empty()
