extends TestCase
## Indicators wired through the session: input -> state -> lamps, buttons, traffic.

var session: DriveSession


func before_each() -> void:
	session = DriveSession.create(Maps.harbor(), BusSpec.new(), {"seed": 2, "traffic": false})
	add_child_autofree(session)
	await wait_physics_frames(3)


func after_each() -> void:
	Input.action_release("accelerate")


func _touch(button: TouchButton) -> void:
	var event := InputEventScreenTouch.new()
	event.pressed = true
	event.position = Vector2(4, 4)
	button._gui_input(event)
	event = event.duplicate()
	event.pressed = false
	button._gui_input(event)


func test_left_button_signals_into_left_lane_and_tells_traffic() -> void:
	_touch(session.touch_controls.indicator_left_button)
	await wait_physics_frames(2)
	assert_eq(session.indicators.side, Indicators.Turn.LEFT)
	assert_eq(session.traffic.signal_lane, 1)


func test_lamps_and_button_blink_together() -> void:
	_touch(session.touch_controls.indicator_right_button)
	var lit_frames := 0
	var frames := int(Indicators.BLINK_PERIOD * 2 * 60)
	for i in frames:
		await get_tree().physics_frame
		var bus_lit := session.bus.is_lamp_lit("front_right")
		assert_eq(session.bus.is_lamp_lit("rear_right"), bus_lit)
		assert_false(session.bus.is_lamp_lit("front_left"))
		assert_eq(session.touch_controls.indicator_right_button.lit, bus_lit)
		lit_frames += 1 if bus_lit else 0
	assert_between(lit_frames, frames * 0.4, frames * 0.6)


func test_keyboard_toggles_indicator() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Q
	key.pressed = true
	get_tree().root.push_input(key)
	await wait_physics_frames(2)
	assert_eq(session.indicators.side, Indicators.Turn.LEFT)
	get_tree().root.push_input(key)
	await wait_physics_frames(2)
	assert_false(session.indicators.is_active(), "second press cancels")
	assert_eq(session.traffic.signal_lane, -1)
	assert_false(session.bus.is_lamp_lit("front_left"))


func test_signal_cancels_itself_after_changing_lane() -> void:
	_touch(session.touch_controls.indicator_left_button)
	var track := session.world.track
	var offset := track.closest_offset(session.bus.global_position)
	var xform := track.vehicle_transform(1, offset)
	xform.origin.y = 0.3
	session.bus.global_transform = xform
	await wait_seconds(Indicators.SETTLE_TIME + 0.5)
	assert_false(session.indicators.is_active())
	assert_eq(session.traffic.signal_lane, -1)
