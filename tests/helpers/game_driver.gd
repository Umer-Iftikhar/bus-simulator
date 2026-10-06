class_name GameDriver
extends RefCounted
## System-test helper that operates the real game like a player: it boots the
## main scene and feeds keyboard, mouse and touch events through
## Input.parse_input_event (the same pipeline the OS uses).

const MAIN_SCENE := "res://scenes/main.tscn"

var test: TestCase
var main: Node


func _init(owner_test: TestCase) -> void:
	test = owner_test


func boot() -> Node:
	var scene: PackedScene = load(MAIN_SCENE)
	main = test.add_child_autofree(scene.instantiate())
	await test.wait_process_frames(2)
	return main


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


func release_all() -> void:
	for action in InputSetup.BINDINGS:
		Input.action_release(action)
	Input.flush_buffered_events()
