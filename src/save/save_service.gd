class_name SaveService
extends RefCounted
## Reads and writes [SaveData] as JSON under user:// (local only, no accounts).
## Writes go to a temporary file first and are then swapped in, so a crash
## mid-save never leaves a truncated save behind.

const DEFAULT_PATH := "user://save.json"

var path := DEFAULT_PATH


func _init(save_path := DEFAULT_PATH) -> void:
	path = save_path


func exists() -> bool:
	return FileAccess.file_exists(path)


func save(data: SaveData) -> Error:
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data.to_dict(), "\t"))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp_path, path)


## Loads the save, or starts a new game when there is none. A corrupt file is
## kept as `<path>.corrupt` for inspection and a fresh game is started.
func load_or_new() -> SaveData:
	if not exists():
		return SaveData.new_game()
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) == OK and json.data is Dictionary:
		return SaveData.from_dict(json.data)
	push_warning("Save file %s is corrupt; starting a new game." % path)
	DirAccess.rename_absolute(path, path + ".corrupt")
	return SaveData.new_game()


func delete() -> void:
	for file in [path, path + ".tmp", path + ".corrupt"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
