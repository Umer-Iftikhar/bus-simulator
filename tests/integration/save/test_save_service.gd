extends TestCase
## SaveService against the real user:// filesystem.

var service: SaveService


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	service = SaveService.new("user://test_saves/service_%d.json" % Time.get_ticks_usec())


func after_each() -> void:
	service.delete()


func test_missing_file_starts_a_new_game() -> void:
	assert_false(service.exists())
	assert_eq(service.load_or_new().to_dict(), SaveData.new_game().to_dict())


func test_save_then_load_round_trips() -> void:
	var save := SaveData.new_game()
	save.wallet.earn(777)
	save.owned["city"] = SaveData.default_owned_bus()
	save.selected_bus = "city"
	assert_eq(service.save(save), OK)
	assert_true(service.exists())
	var loaded := service.load_or_new()
	assert_eq(loaded.to_dict(), save.to_dict())


func test_save_is_atomic_and_leaves_no_temp_file() -> void:
	service.save(SaveData.new_game())
	var again := SaveData.new_game()
	again.wallet.earn(5)
	service.save(again)
	assert_false(FileAccess.file_exists(service.path + ".tmp"))
	assert_eq(service.load_or_new().money, 5, "second save replaced the first")


func test_saved_file_is_readable_json() -> void:
	service.save(SaveData.new_game())
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(service.path))
	assert_true(parsed is Dictionary)
	assert_eq(int(parsed["version"]), SaveData.VERSION)


func test_corrupt_file_is_backed_up_and_new_game_started() -> void:
	var file := FileAccess.open(service.path, FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	var loaded := service.load_or_new()
	assert_eq(loaded.money, 0)
	assert_true(FileAccess.file_exists(service.path + ".corrupt"), "kept for inspection")
	assert_false(service.exists(), "corrupt file moved aside")


func test_delete_removes_all_files() -> void:
	service.save(SaveData.new_game())
	service.delete()
	assert_false(service.exists())
