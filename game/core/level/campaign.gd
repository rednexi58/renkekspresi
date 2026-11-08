class_name Campaign
extends RefCounted
## Read-only access to the authored campaign. Loading is isolated here so rules and UI
## never touch file paths or JSON, and a future remote/updated campaign can replace it.

const DEFAULT_PATH := "res://data/campaign.json"

var levels: Array[LevelDefinition] = []


static func load_from(path: String = DEFAULT_PATH) -> Campaign:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Campaign file missing or empty: %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary or not (parsed as Dictionary).has("levels"):
		push_error("Campaign file is not valid: %s" % path)
		return null
	var campaign := Campaign.new()
	for entry: Dictionary in (parsed as Dictionary)["levels"]:
		campaign.levels.append(LevelDefinition.from_dict(entry))
	return campaign


func count() -> int:
	return levels.size()


## Level by zero-based index, clamped to the valid range.
func level_at(index: int) -> LevelDefinition:
	return levels[clampi(index, 0, levels.size() - 1)]
