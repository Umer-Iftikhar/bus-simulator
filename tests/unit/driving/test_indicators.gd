extends TestCase
## Turn-signal behaviour.

var ind: Indicators


func before_each() -> void:
	ind = Indicators.new()


func test_starts_off() -> void:
	assert_false(ind.is_active())
	assert_false(ind.lamp_on())
	assert_eq(ind.target_lane, -1)


func test_toggle_left_from_kerb_lane_targets_left_lane() -> void:
	ind.toggle_left(0)
	assert_eq(ind.side, Indicators.Turn.LEFT)
	assert_eq(ind.target_lane, 1)


func test_toggle_right_from_left_lane_targets_kerb_lane() -> void:
	ind.toggle_right(1)
	assert_eq(ind.side, Indicators.Turn.RIGHT)
	assert_eq(ind.target_lane, 0)


func test_signal_with_no_lane_that_way_still_blinks_without_target() -> void:
	ind.toggle_right(0)
	assert_true(ind.is_active())
	assert_eq(ind.target_lane, -1, "pulling toward the kerb, no lane to merge into")
	ind.toggle_left(1)
	assert_eq(ind.target_lane, -1)


func test_toggling_same_side_cancels_and_other_side_switches() -> void:
	watch_signals(ind)
	ind.toggle_left(0)
	ind.toggle_left(0)
	assert_false(ind.is_active())
	ind.toggle_left(0)
	ind.toggle_right(1)
	assert_eq(ind.side, Indicators.Turn.RIGHT)
	assert_signal_emit_count(ind, "changed", 4)


func test_lamps_blink_with_period() -> void:
	ind.toggle_left(0)
	var on_frames := 0
	var transitions := 0
	var previous := ind.lamp_on()
	var steps := int(Indicators.BLINK_PERIOD * 3 / 0.01)
	for i in steps:
		ind.update(0.01, 0)
		if ind.lamp_on():
			on_frames += 1
		if ind.lamp_on() != previous:
			transitions += 1
		previous = ind.lamp_on()
	assert_almost_eq(float(on_frames) / steps, 0.5, 0.05, "on half the time")
	assert_between(transitions, 5, 6, "three full blink cycles")


func test_only_the_signalled_side_lights() -> void:
	ind.toggle_right(1)
	assert_true(ind.right_lamp())
	assert_false(ind.left_lamp())


func test_auto_cancels_after_settling_in_target_lane() -> void:
	ind.toggle_left(0)
	ind.update(0.5, 0)
	ind.update(0.5, 1)
	assert_true(ind.is_active(), "just arrived")
	ind.update(Indicators.SETTLE_TIME * 0.6, 1)
	ind.update(Indicators.SETTLE_TIME * 0.6, 1)
	assert_false(ind.is_active(), "lane change complete")


func test_drifting_back_resets_settle_timer() -> void:
	ind.toggle_left(0)
	ind.update(Indicators.SETTLE_TIME * 0.8, 1)
	ind.update(0.1, 0)
	ind.update(Indicators.SETTLE_TIME * 0.8, 1)
	assert_true(ind.is_active())


func test_times_out_eventually() -> void:
	ind.toggle_right(0)
	for i in int(Indicators.TIMEOUT) + 1:
		ind.update(1.0, 0)
	assert_false(ind.is_active())


func test_lane_toward() -> void:
	assert_eq(Indicators.lane_toward(Indicators.Turn.LEFT, 0), 1)
	assert_eq(Indicators.lane_toward(Indicators.Turn.RIGHT, 1), 0)
	assert_eq(Indicators.lane_toward(Indicators.Turn.LEFT, 1), -1)
	assert_eq(Indicators.lane_toward(Indicators.Turn.RIGHT, 0), -1)
	assert_eq(Indicators.lane_toward(Indicators.Turn.LEFT, -1), -1, "off road")
