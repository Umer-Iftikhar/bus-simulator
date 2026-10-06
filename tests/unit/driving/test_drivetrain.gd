extends TestCase

const TOP := 20.0
const ENGINE := 5000.0
const BRAKE := 60.0


func _drive(throttle: float, brake: float, speed: float, reverse := false) -> Dictionary:
	return Drivetrain.compute(throttle, brake, speed, TOP, ENGINE, BRAKE, reverse)


func test_full_throttle_from_rest_gives_full_force() -> void:
	var out := _drive(1.0, 0.0, 0.0)
	assert_eq(out["engine_force"], ENGINE)
	assert_eq(out["brake"], 0.0)


func test_partial_throttle_scales_force() -> void:
	assert_almost_eq(_drive(0.5, 0.0, 2.0)["engine_force"], ENGINE * 0.5, 0.01)


func test_force_fades_near_top_speed_and_is_zero_beyond() -> void:
	var below_fade: float = _drive(1.0, 0.0, TOP * 0.8)["engine_force"]
	var in_fade: float = _drive(1.0, 0.0, TOP * 0.95)["engine_force"]
	var at_top: float = _drive(1.0, 0.0, TOP)["engine_force"]
	var beyond: float = _drive(1.0, 0.0, TOP * 1.2)["engine_force"]
	assert_eq(below_fade, ENGINE)
	assert_between(in_fade, 0.01, ENGINE * 0.5)
	assert_eq(at_top, 0.0)
	assert_eq(beyond, 0.0)


func test_torque_curve_is_monotonic_non_increasing() -> void:
	var previous := 2.0
	for i in 41:
		var value := Drivetrain.torque_curve(i * 0.5, TOP)
		assert_le(value, previous)
		assert_between(value, 0.0, 1.0)
		previous = value


func test_torque_curve_handles_zero_top_speed() -> void:
	assert_eq(Drivetrain.torque_curve(5.0, 0.0), 0.0)


func test_brake_while_moving_forward_brakes_without_engine() -> void:
	var out := _drive(0.0, 1.0, 10.0)
	assert_eq(out["brake"], BRAKE)
	assert_eq(out["engine_force"], 0.0)


func test_brake_pedal_overrides_throttle() -> void:
	var out := _drive(1.0, 0.5, 10.0)
	assert_eq(out["brake"], BRAKE * 0.5)
	assert_eq(out["engine_force"], 0.0)


func test_brake_at_standstill_holds_the_bus() -> void:
	var out := _drive(0.0, 1.0, 0.0)
	assert_eq(out["engine_force"], 0.0, "no creeping into reverse")
	assert_eq(out["brake"], BRAKE)


func test_reverse_gear_accelerator_drives_backwards() -> void:
	var out := _drive(1.0, 0.0, 0.0, true)
	assert_almost_eq(out["engine_force"], -ENGINE * Drivetrain.REVERSE_FORCE_RATIO, 0.01)
	assert_eq(out["brake"], 0.0)


func test_reverse_is_limited_to_reverse_top_speed() -> void:
	var out := _drive(1.0, 0.0, -Drivetrain.REVERSE_TOP_SPEED, true)
	assert_eq(out["engine_force"], 0.0)
	var half := _drive(1.0, 0.0, -Drivetrain.REVERSE_TOP_SPEED / 2.0, true)
	var expected := -ENGINE * Drivetrain.REVERSE_FORCE_RATIO * 0.5
	assert_almost_eq(half["engine_force"], expected, 0.01)


func test_reverse_gear_while_rolling_forward_brakes_first() -> void:
	var out := _drive(1.0, 0.0, 3.0, true)
	assert_eq(out["engine_force"], 0.0)
	assert_eq(out["brake"], BRAKE)


func test_brake_works_in_reverse_too() -> void:
	var out := _drive(0.0, 0.6, -2.0, true)
	assert_eq(out["brake"], BRAKE * 0.6)
	assert_eq(out["engine_force"], 0.0)


func test_gear_change_only_when_nearly_stopped() -> void:
	assert_true(Drivetrain.can_change_gear(0.0))
	assert_true(Drivetrain.can_change_gear(-0.5))
	assert_false(Drivetrain.can_change_gear(Drivetrain.GEAR_CHANGE_SPEED + 0.1))
	assert_false(Drivetrain.can_change_gear(-3.0))


func test_throttle_while_rolling_backwards_brakes_first() -> void:
	var out := _drive(1.0, 0.0, -3.0)
	assert_eq(out["engine_force"], 0.0)
	assert_eq(out["brake"], BRAKE)


func test_no_input_applies_light_rolling_brake() -> void:
	var out := _drive(0.0, 0.0, 5.0)
	assert_eq(out["engine_force"], 0.0)
	assert_almost_eq(out["brake"], BRAKE * Drivetrain.IDLE_BRAKE_RATIO, 0.0001)


func test_steer_limit_shrinks_with_speed() -> void:
	var still := Drivetrain.steer_limit(0.6, 0.0, TOP)
	var half := Drivetrain.steer_limit(0.6, TOP / 2.0, TOP)
	var full := Drivetrain.steer_limit(0.6, TOP, TOP)
	assert_eq(still, 0.6)
	assert_lt(half, still)
	assert_almost_eq(full, 0.6 * Drivetrain.MIN_STEER_RATIO, 0.0001)
	assert_eq(Drivetrain.steer_limit(0.6, -TOP, TOP), full, "reverse speed counts too")
