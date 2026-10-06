extends TestCase

var input: DriveInput


func before_each() -> void:
	input = DriveInput.new()


func test_pedals_apply_immediately() -> void:
	input.update(0.7, 0.3, 0.0, 0.016)
	assert_almost_eq(input.throttle, 0.7, 0.0001)
	assert_almost_eq(input.brake, 0.3, 0.0001)


func test_pedals_are_clamped_to_unit_range() -> void:
	input.update(2.0, -1.0, 0.0, 0.016)
	assert_eq(input.throttle, 1.0)
	assert_eq(input.brake, 0.0)


func test_steering_moves_at_finite_rate() -> void:
	input.steer_rate = 2.0
	input.update(0, 0, 1.0, 0.1)
	assert_almost_eq(input.steer, 0.2, 0.0001, "0.1s at 2/s")
	input.update(0, 0, 1.0, 1.0)
	assert_eq(input.steer, 1.0, "never overshoots target")


func test_steering_target_is_clamped() -> void:
	input.update(0, 0, -5.0, 10.0)
	assert_eq(input.steer, -1.0)


func test_released_wheel_self_centres_at_return_rate() -> void:
	input.update(0, 0, 1.0, 10.0)
	input.return_rate = 3.0
	input.update(0, 0, 0.0, 0.1)
	assert_almost_eq(input.steer, 0.7, 0.0001)
	input.update(0, 0, 0.0, 1.0)
	assert_eq(input.steer, 0.0)


func test_reset_zeroes_everything() -> void:
	input.update(1, 1, 1, 10.0)
	input.reset()
	assert_eq([input.throttle, input.brake, input.steer], [0.0, 0.0, 0.0])
