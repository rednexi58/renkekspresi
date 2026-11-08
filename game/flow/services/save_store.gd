class_name SaveStore
extends RefCounted
## Persists PlayerProgress as JSON in the app's private storage. Writes go to a
## temporary file that is then renamed over the old save, so a crash mid-write can never
## leave a half-written (corrupt) save behind.

const PATH := "user://progress.json"
const TEMP_PATH := "user://progress.tmp"


static func load_progress() -> PlayerProgress:
	if not FileAccess.file_exists(PATH):
		return PlayerProgress.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary:
		push_warning("Save file unreadable; starting fresh")
		return PlayerProgress.new()
	return PlayerProgress.from_dict(parsed)


static func save(progress: PlayerProgress) -> bool:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write save: %s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(progress.to_dict()))
	file.close()
	var directory := DirAccess.open("user://")
	if directory == null or directory.rename(TEMP_PATH.get_file(), PATH.get_file()) != OK:
		push_error("Cannot replace save file")
		return false
	return true
