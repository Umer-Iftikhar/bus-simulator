extends TestCase

const C := Vector2(100, 100)


func test_pointer_angle_is_zero_at_top_and_clockwise_positive() -> void:
	assert_almost_eq(SteeringWheelMath.pointer_angle(C, Vector2(100, 0)), 0.0, 0.0001)
	assert_almost_eq(SteeringWheelMath.pointer_angle(C, Vector2(200, 100)), PI / 2, 0.0001)
	assert_almost_eq(SteeringWheelMath.pointer_angle(C, Vector2(0, 100)), -PI / 2, 0.0001)


func test_accumulate_adds_pointer_motion() -> void:
	var angle := SteeringWheelMath.accumulate(0.0, 0.0, 0.5, 3.0)
	assert_almost_eq(angle, 0.5, 0.0001)


func test_accumulate_handles_wrap_across_bottom_of_wheel() -> void:
	# Pointer moves from just left of the bottom (+PI - 0.1) to just right (-PI + 0.1).
	var angle := SteeringWheelMath.accumulate(1.0, PI - 0.1, -PI + 0.1, 4.0)
	assert_almost_eq(angle, 1.2, 0.0001)


func test_accumulate_clamps_to_max_angle() -> void:
	assert_eq(SteeringWheelMath.accumulate(2.0, 0.0, 1.0, 2.5), 2.5)
	assert_eq(SteeringWheelMath.accumulate(-2.0, 0.0, -1.0, 2.5), -2.5)


func test_angle_to_steer_maps_and_clamps() -> void:
	var max_angle := SteeringWheelMath.DEFAULT_MAX_ANGLE
	assert_eq(SteeringWheelMath.angle_to_steer(0.0, max_angle), 0.0)
	assert_almost_eq(SteeringWheelMath.angle_to_steer(max_angle / 2, max_angle), 0.5, 0.0001)
	assert_eq(SteeringWheelMath.angle_to_steer(-max_angle * 3, max_angle), -1.0)
	assert_eq(SteeringWheelMath.angle_to_steer(1.0, 0.0), 0.0)


func test_wheel_turns_two_full_turns_each_way_like_a_real_bus() -> void:
	assert_almost_eq(SteeringWheelMath.DEFAULT_MAX_ANGLE, deg_to_rad(720.0), 0.0001)
	# Hand over hand: a full circle of the pointer, done in small drags, twice.
	var angle := 0.0
	var pointer := 0.0
	for i in 160:
		var next := wrapf(pointer + 0.1, -PI, PI)
		angle = SteeringWheelMath.accumulate(
			angle, pointer, next, SteeringWheelMath.DEFAULT_MAX_ANGLE
		)
		pointer = next
	assert_almost_eq(angle, SteeringWheelMath.DEFAULT_MAX_ANGLE, 0.0001, "stops at 720 degrees")
	assert_almost_eq(
		SteeringWheelMath.angle_to_steer(TAU, SteeringWheelMath.DEFAULT_MAX_ANGLE),
		0.5,
		0.0001,
		"one turn is half lock"
	)


func test_cab_wheel_matches_the_on_screen_wheel() -> void:
	assert_almost_eq(BusBody.WHEEL_LOCK_TURNS * TAU, SteeringWheelMath.DEFAULT_MAX_ANGLE, 0.0001)
