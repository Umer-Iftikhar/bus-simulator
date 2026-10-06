extends TestCase
## End-to-end smoke test: the game boots and keeps running for a few seconds.


func test_game_runs_for_three_seconds_without_errors() -> void:
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	var main := add_child_autofree(scene.instantiate())
	await wait_seconds(3.0)
	assert_true(is_instance_valid(main) and main.is_inside_tree())
