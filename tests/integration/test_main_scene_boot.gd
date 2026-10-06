extends TestCase
## The configured main scene can be instanced into a live tree.


func test_main_scene_enters_tree_and_builds_children() -> void:
	var driver := GameDriver.new(self)
	var main := await driver.boot()
	assert_true(main.is_inside_tree())
	assert_gt(main.get_child_count(), 0)
	driver.cleanup_save()
