extends TestCase

var input: DriveInput


func before_each() -> void:
	input = DriveInput.new()


func test_pedals_ramp_in_quickly_but_not_instantly() -> void:
	input.update(1.0, 0.0, 0.0, 0.1)
	assert_almost_eq(input.throttle, 0.1 * DriveInput.PEDAL_RATE, 0.0001, "no instant jolt")
	input.update(1.0, 0.0, 0.0, 0.2)
	assert_eq(input.throttle, 1.0, "full pedal within a quarter second")


func test_pedals_release_faster_than_they_press() -> void:
	input.update(1.0, 1.0, 0.0, 1.0)
	input.update(0.0, 0.0, 0.0, 0.1)
	assert_almost_eq(input.throttle, 1.0 - 0.1 * DriveInput.PEDAL_RELEASE_RATE, 0.0001)
	assert_gt(DriveInput.PEDAL_RELEASE_RATE, DriveInput.PEDAL_RATE)


func test_pedals_settle_at_target_and_clamp() -> void:
	input.update(0.7, 0.3, 0.0, 1.0)
	assert_almost_eq(input.throttle, 0.7, 0.0001)
	assert_almost_eq(input.brake, 0.3, 0.0001)
	input.update(2.0, -1.0, 0.0, 1.0)
	assert_eq(input.throttle, 1.0)
	assert_eq(input.brake, 0.0)


func test_steering_never_exceeds_its_rate_and_reaches_full_lock() -> void:
	input.steer_rate = 2.0
	input.update(0, 0, 1.0, 0.1)
	assert_le(input.steer, 0.2 + 0.0001, "0.1s at no more than 2/s")
	assert_gt(input.steer, 0.0)
	for i in 120:
		input.update(0, 0, 1.0, 1.0 / 60.0)
	assert_eq(input.steer, 1.0, "full lock reached, never overshot")


func test_steering_eases_in_without_jumps() -> void:
	var previous := 0.0
	var biggest_step := 0.0
	for i in 90:
		input.update(0, 0, 1.0, 1.0 / 60.0)
		biggest_step = maxf(biggest_step, input.steer - previous)
		assert_ge(input.steer, previous, "monotonic, no overshoot")
		previous = input.steer
	assert_le(biggest_step, input.steer_rate / 60.0 + 0.0001)


func test_small_inputs_are_softened_for_fine_control() -> void:
	var expected := pow(0.25, DriveInput.RESPONSE_EXPONENT)
	assert_almost_eq(DriveInput.shape_steer(0.25), expected, 0.0001)
	assert_lt(DriveInput.shape_steer(0.25), 0.25)
	assert_eq(DriveInput.shape_steer(1.0), 1.0, "full lock preserved")
	assert_eq(DriveInput.shape_steer(-1.0), -1.0)
	assert_almost_eq(DriveInput.shape_steer(-0.5), -DriveInput.shape_steer(0.5), 0.0001)


func test_wheel_turns_slower_at_speed() -> void:
	var slow := DriveInput.new()
	var fast := DriveInput.new()
	slow.update(0, 0, 1.0, 0.2, 0.0)
	fast.update(0, 0, 1.0, 0.2, 1.0)
	assert_lt(fast.steer, slow.steer)


func test_steering_target_is_clamped() -> void:
	for i in 120:
		input.update(0, 0, -5.0, 1.0 / 60.0)
	assert_eq(input.steer, -1.0)


func test_released_wheel_self_centres() -> void:
	for i in 120:
		input.update(0, 0, 1.0, 1.0 / 60.0)
	input.return_rate = 3.0
	input.update(0, 0, 0.0, 0.1)
	assert_between(input.steer, 0.7 - 0.0001, 0.99, "centring at no more than 3/s")
	for i in 120:
		input.update(0, 0, 0.0, 1.0 / 60.0)
	assert_eq(input.steer, 0.0)


func test_reset_zeroes_everything() -> void:
	input.update(1, 1, 1, 10.0)
	input.reset()
	assert_eq([input.throttle, input.brake, input.steer], [0.0, 0.0, 0.0])
