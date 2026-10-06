extends TestCase
## End-to-end smoke test: the game boots and keeps running for a few seconds.


func test_game_runs_for_three_seconds_without_errors() -> void:
	var driver := GameDriver.new(self)
	var main := await driver.boot()
	await wait_seconds(3.0)
	assert_true(is_instance_valid(main) and main.is_inside_tree())
	assert_not_null(main.menu, "main menu visible")
	driver.cleanup_save()
