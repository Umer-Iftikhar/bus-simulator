extends TestCase
## Automatic turn signals: when a careful driver would indicate, and that a
## manual press is never fought while the situation is unchanged.

const LEFT := Indicators.Turn.LEFT
const RIGHT := Indicators.Turn.RIGHT
const NONE := Indicators.Turn.NONE


func _wish(distance: float, lane: int, speed: float, drift := 0.0, since := INF) -> int:
	return AutoIndicator.desired(distance, lane, speed, drift, since)


func test_cruising_far_from_a_stop_needs_no_signal() -> void:
	assert_eq(_wish(500.0, 0, 12.0), NONE)
	assert_eq(_wish(500.0, 1, 12.0), NONE)


func test_signals_right_when_closing_on_the_next_stop() -> void:
	assert_eq(_wish(AutoIndicator.STOP_DISTANCE, 0, 10.0), RIGHT)
	assert_eq(_wish(30.0, 1, 8.0), RIGHT, "from the outer lane too")
	assert_eq(_wish(AutoIndicator.STOP_DISTANCE + 5.0, 0, 10.0), NONE, "not too early")
	assert_eq(_wish(0.0, 0, 0.0), NONE, "off once in the stop zone")


func test_signals_left_to_pull_out_after_a_stop() -> void:
	assert_eq(_wish(600.0, 0, 0.0, 0.0, 1.0), LEFT)
	assert_eq(_wish(600.0, 0, 3.0, 0.0, 5.0), LEFT, "still pulling out")
	assert_eq(
		_wish(600.0, 0, AutoIndicator.PULL_OUT_SPEED + 1.0, 0.0, 5.0), NONE, "back up to speed"
	)
	assert_eq(_wish(600.0, 0, 0.0, 0.0, AutoIndicator.PULL_OUT_TIME + 1.0), NONE, "window over")


func test_signals_toward_the_lane_it_drifts_into() -> void:
	assert_eq(_wish(500.0, 0, 12.0, 1.2), LEFT)
	assert_eq(_wish(500.0, 1, 12.0, -1.2), RIGHT)
	assert_eq(_wish(500.0, 0, 12.0, -1.2), NONE, "no lane to the right of the kerb lane")
	assert_eq(_wish(500.0, 1, 12.0, 1.2), NONE, "no lane left of the outer lane")
	assert_eq(_wish(500.0, 0, 12.0, 0.3), NONE, "ordinary wobble is not a lane change")
	assert_eq(_wish(500.0, 0, 2.0, 1.2), NONE, "manoeuvring slowly")


func test_off_road_never_signals() -> void:
	assert_eq(_wish(30.0, -1, 10.0), NONE)


func test_apply_switches_on_and_off_with_the_wish() -> void:
	var auto := AutoIndicator.new()
	var lights := Indicators.new()
	auto.apply(lights, RIGHT, 1)
	assert_eq(lights.side, RIGHT)
	assert_eq(lights.target_lane, 0)
	auto.apply(lights, RIGHT, 1)
	assert_eq(lights.side, RIGHT, "repeating the wish does not toggle it off")
	auto.apply(lights, NONE, 0)
	assert_eq(lights.side, NONE)


func test_manual_override_sticks_until_the_situation_changes() -> void:
	var auto := AutoIndicator.new()
	var lights := Indicators.new()
	auto.apply(lights, RIGHT, 0)
	lights.cancel()  # Driver switches it off by hand.
	auto.apply(lights, RIGHT, 0)
	assert_eq(lights.side, NONE, "not switched back on")
	lights.toggle_left(0)  # Driver signals left on their own.
	auto.apply(lights, NONE, 0)
	assert_eq(lights.side, LEFT, "the driver's own signal is left alone")


func test_switches_directly_between_sides() -> void:
	var auto := AutoIndicator.new()
	var lights := Indicators.new()
	auto.apply(lights, LEFT, 0)
	auto.apply(lights, RIGHT, 1)
	assert_eq(lights.side, RIGHT)
