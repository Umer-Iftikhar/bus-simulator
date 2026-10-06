class_name GameDriver
extends RefCounted
## System-test helper that operates the real game like a player: it boots the
## main scene and feeds keyboard, mouse and touch events through
## Input.parse_input_event (the same pipeline the OS uses).

const MAIN_SCENE := "res://scenes/main.tscn"
const RUN_SEED := 1234

var test: TestCase
var main: Node
## Disposable save file for this test, never the player's real save.
var save_path := ""


func _init(owner_test: TestCase) -> void:
	test = owner_test


## Boots the main scene. Pass [param prepared_save] to start from a specific save state.
func boot(prepared_save: SaveData = null, keep_save_path := "") -> Node:
	save_path = keep_save_path
	if save_path.is_empty():
		save_path = "user://test_saves/save_%d.json" % Time.get_ticks_usec()
		DirAccess.make_dir_recursive_absolute("user://test_saves")
		SaveService.new(save_path).delete()
	if prepared_save != null:
		SaveService.new(save_path).save(prepared_save)
	var scene: PackedScene = load(MAIN_SCENE)
	main = scene.instantiate()
	main.save_path = save_path
	main.run_seed = RUN_SEED
	test.add_child_autofree(main)
	await test.wait_process_frames(2)
	return main


## Reads what is currently persisted on disk.
func saved_state() -> SaveData:
	return SaveService.new(save_path).load_or_new()


func cleanup_save() -> void:
	if not save_path.is_empty():
		SaveService.new(save_path).delete()


## Converts a canvas position (what Controls use) to window coordinates.
func to_window(canvas_point: Vector2) -> Vector2:
	return test.get_tree().root.get_final_transform() * canvas_point


func click(control: Control) -> void:
	var at := to_window(control.get_global_rect().get_center())
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)
		await test.wait_process_frames(1)


func key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func tap_key(keycode: Key) -> void:
	key(keycode, true)
	await test.wait_process_frames(1)
	key(keycode, false)
	await test.wait_process_frames(1)


func touch(control: Control, pressed: bool, index := 0) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = to_window(control.get_global_rect().get_center())
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func select_option(picker: OptionButton, metadata: Variant) -> void:
	for i in picker.item_count:
		if picker.get_item_metadata(i) == metadata:
			picker.select(i)
			picker.item_selected.emit(i)
			await test.wait_process_frames(1)
			return
	test.fail("option %s not found" % str(metadata))


func release_all() -> void:
	for action in InputSetup.BINDINGS:
		Input.action_release(action)
	Input.flush_buffered_events()
