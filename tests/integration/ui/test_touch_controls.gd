extends TestCase
## Touch widgets fed with real InputEventScreenTouch / ScreenDrag events.

var layer: CanvasLayer
var controls: TouchControls


func before_each() -> void:
	layer = add_child_autofree(CanvasLayer.new())
	controls = TouchControls.new()
	layer.add_child(controls)
	await wait_process_frames(2)


func _touch(control: Control, local: Vector2, pressed: bool, index := 0) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = local
	control._gui_input(event)


func _drag(control: Control, local: Vector2, index := 0) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = local
	control._gui_input(event)


func test_layout_keeps_every_control_on_screen_without_overlap() -> void:
	var screen := Rect2(Vector2.ZERO, controls.size)
	var widgets: Array[Control] = [
		controls.wheel,
		controls.gas,
		controls.brake_pedal,
		controls.camera_button,
		controls.horn_button,
		controls.menu_button,
		controls.indicator_left_button,
		controls.indicator_right_button,
	]
	for widget in widgets:
		var rect := Rect2(widget.position, widget.size)
		assert_true(screen.encloses(rect), "%s on screen" % widget.name)
	for i in widgets.size():
		for j in range(i + 1, widgets.size()):
			var a := Rect2(widgets[i].position, widgets[i].size)
			var b := Rect2(widgets[j].position, widgets[j].size)
			assert_false(a.intersects(b), "%s overlaps %s" % [widgets[i].name, widgets[j].name])


func test_gas_pedal_reports_value_while_held() -> void:
	assert_eq(controls.throttle(), 0.0)
	_touch(controls.gas, Vector2(10, 10), true)
	assert_eq(controls.throttle(), 1.0)
	_touch(controls.gas, Vector2(10, 10), false)
	assert_eq(controls.throttle(), 0.0)


func test_release_from_another_finger_does_not_lift_pedal() -> void:
	_touch(controls.brake_pedal, Vector2(10, 10), true, 0)
	_touch(controls.brake_pedal, Vector2(10, 10), false, 3)
	assert_eq(controls.brake(), 1.0)


func test_wheel_drag_clockwise_steers_right_and_springs_back() -> void:
	var wheel := controls.wheel
	var c := wheel.size / 2.0
	_touch(wheel, c + Vector2(0, -80), true)
	_drag(wheel, c + Vector2(80, 0))
	assert_almost_eq(wheel.wheel_angle, PI / 2.0, 0.01)
	assert_gt(controls.steer(), 0.5)
	_touch(wheel, c + Vector2(80, 0), false)
	assert_false(wheel.is_held())
	await wait_seconds(1.0)
	assert_almost_eq(controls.steer(), 0.0, 0.001, "self-centres")


func test_wheel_drag_anticlockwise_past_limit_clamps_to_full_left() -> void:
	var wheel := controls.wheel
	var c := wheel.size / 2.0
	_touch(wheel, c + Vector2(0, -80), true)
	for point in [Vector2(-80, 0), Vector2(0, 80), Vector2(80, 0), Vector2(0, -80)]:
		_drag(wheel, c + point)
	assert_eq(controls.steer(), -1.0)


func test_wheel_ignores_drags_from_other_fingers() -> void:
	var wheel := controls.wheel
	var c := wheel.size / 2.0
	_touch(wheel, c + Vector2(0, -80), true, 0)
	_drag(wheel, c + Vector2(80, 0), 1)
	assert_eq(wheel.wheel_angle, 0.0)


func test_wheel_and_pedal_work_simultaneously() -> void:
	var c := controls.wheel.size / 2.0
	_touch(controls.wheel, c + Vector2(0, -80), true, 0)
	_touch(controls.gas, Vector2(5, 5), true, 1)
	_drag(controls.wheel, c + Vector2(-80, 0), 0)
	assert_eq(controls.throttle(), 1.0)
	assert_lt(controls.steer(), -0.5)


func test_buttons_emit_their_signals() -> void:
	watch_signals(controls)
	_touch(controls.camera_button, Vector2(5, 5), true)
	_touch(controls.horn_button, Vector2(5, 5), true)
	_touch(controls.menu_button, Vector2(5, 5), true)
	assert_signal_emit_count(controls, "camera_requested", 1)
	assert_signal_emit_count(controls, "horn_requested", 1)
	assert_signal_emit_count(controls, "menu_requested", 1)


func test_indicator_buttons_emit_and_light() -> void:
	watch_signals(controls)
	_touch(controls.indicator_left_button, Vector2(5, 5), true)
	_touch(controls.indicator_right_button, Vector2(5, 5), true, 1)
	assert_signal_emitted(controls, "indicator_left_requested")
	assert_signal_emitted(controls, "indicator_right_requested")
	controls.show_indicators(true, false)
	assert_true(controls.indicator_left_button.lit)
	assert_false(controls.indicator_right_button.lit)


func test_hidden_button_releases_its_hold() -> void:
	_touch(controls.gas, Vector2(5, 5), true)
	controls.visible = false
	assert_eq(controls.throttle(), 0.0, "pedal released when overlay hides")


func test_touches_route_through_viewport_to_widgets() -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = true
	# push_input takes window coordinates; headless windows are tiny, so map canvas -> window.
	var canvas_point := controls.gas.get_global_rect().get_center()
	event.position = get_tree().root.get_final_transform() * canvas_point
	get_tree().root.push_input(event)
	await wait_process_frames(1)
	assert_eq(controls.throttle(), 1.0, "viewport delivered touch to the gas pedal")
	event = event.duplicate()
	event.pressed = false
	get_tree().root.push_input(event)
	await wait_process_frames(1)
	assert_eq(controls.throttle(), 0.0)
