class_name LevelData
extends RefCounted
var levels: Array = []

func _init() -> void:
	var file = FileAccess.open("res://data/levels.json", FileAccess.READ)
	if file:
		levels = JSON.parse_string(file.get_as_text())

func get_level(index: int) -> Dictionary:
	return levels[clampi(index, 0, levels.size() - 1)].duplicate(true)

func count() -> int:
	return levels.size()

