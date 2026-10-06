extends TestCase
## Guards against parse errors in scripts that no other test happens to load.

const ROOTS := ["res://src", "res://scenes"]


func test_every_script_loads_and_compiles() -> void:
	var scripts := _collect("res://src", ".gd")
	assert_gt(scripts.size(), 0, "expected scripts under res://src")
	for path in scripts:
		var script: Script = load(path)
		assert_not_null(script, "failed to load %s" % path)
		if script != null:
			assert_true(script.can_instantiate(), "%s does not compile" % path)


func test_every_scene_loads() -> void:
	for path in _collect("res://scenes", ".tscn"):
		var scene: PackedScene = load(path)
		assert_not_null(scene, "failed to load %s" % path)
		if scene != null:
			assert_true(scene.can_instantiate(), "%s cannot be instantiated" % path)


func test_main_scene_is_configured() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	assert_true(ResourceLoader.exists(main_scene), "main scene %s missing" % main_scene)


func _collect(dir_path: String, extension: String) -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub in dir.get_directories():
		found.append_array(_collect(dir_path.path_join(sub), extension))
	for file in dir.get_files():
		if file.ends_with(extension):
			found.append(dir_path.path_join(file))
	return found
