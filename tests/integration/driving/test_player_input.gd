extends TestCase
## PlayerInput merging keyboard actions and touch controls into bus commands.

var world: FlatWorld
var bus: Bus
var controls: TouchControls
var player: PlayerInput


func before_each() -> void:
	world = add_child_autofree(FlatWorld.create())
	bus = await world.spawn_bus(self)
	var layer := CanvasLayer.new()
	world.add_child(layer)
	controls = TouchControls.new()
	layer.add_child(controls)
	player = PlayerInput.new()
	player.bus = bus
	player.touch = controls
	world.add_child(player)
	await wait_physics_frames(1)


func after_each() -> void:
	for action in InputSetup.BINDINGS:
		Input.action_release(action)


func _touch(control: Control, pressed: bool, index := 0) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = Vector2(5, 5)
	control._gui_input(event)


func test_keyboard_actions_drive_the_bus() -> void:
	Input.action_press("accelerate")
	Input.action_press("steer_right")
	await wait_physics_frames(2)
	assert_eq(bus._target_throttle, 1.0)
	assert_eq(bus._target_steer, 1.0)
	await wait_seconds(3.0)
	assert_gt(bus.forward_speed(), 3.0)


func test_analog_action_strength_is_preserved() -> void:
	Input.action_press("steer_left", 0.4)
	await wait_physics_frames(2)
	assert_almost_eq(bus._target_steer, -0.4, 0.001)


func test_touch_pedals_drive_the_bus() -> void:
	_touch(controls.gas, true)
	await wait_seconds(3.0)
	assert_gt(bus.forward_speed(), 3.0)
	_touch(controls.gas, false)
	_touch(controls.brake_pedal, true)
	await wait_physics_frames(2)
	assert_eq(bus._target_brake, 1.0)
	assert_eq(bus._target_throttle, 0.0)


func test_stronger_steering_source_wins() -> void:
	Input.action_press("steer_left", 0.3)
	controls.wheel.wheel_angle = controls.wheel.max_angle
	await wait_physics_frames(2)
	assert_almost_eq(bus._target_steer, 1.0, 0.05, "full touch lock beats light key")


func test_one_shot_actions_emit_signals_via_viewport() -> void:
	watch_signals(player)
	for keycode in [KEY_C, KEY_H, KEY_ESCAPE]:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		event.pressed = true
		get_tree().root.push_input(event)
		var up := event.duplicate()
		up.pressed = false
		get_tree().root.push_input(up)
	await wait_process_frames(2)
	assert_signal_emit_count(player, "camera_requested", 1)
	assert_signal_emit_count(player, "horn_requested", 1)
	assert_signal_emit_count(player, "pause_requested", 1)


func test_touch_buttons_are_forwarded() -> void:
	watch_signals(player)
	_touch(controls.camera_button, true)
	_touch(controls.horn_button, true, 1)
	_touch(controls.menu_button, true, 2)
	assert_signal_emitted(player, "camera_requested")
	assert_signal_emitted(player, "horn_requested")
	assert_signal_emitted(player, "pause_requested")


func test_freed_bus_is_ignored() -> void:
	bus.free()
	await wait_physics_frames(2)
	assert_true(is_instance_valid(player))
