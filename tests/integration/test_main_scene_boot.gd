extends TestCase
## The configured main scene can be instanced into a live tree.


func test_main_scene_enters_tree_and_builds_children() -> void:
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	var main := add_child_autofree(scene.instantiate())
	await wait_process_frames(2)
	assert_true(main.is_inside_tree())
	assert_gt(main.get_child_count(), 0)
