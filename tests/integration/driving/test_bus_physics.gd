extends TestCase
## The Bus VehicleBody3D responding to commands in a real physics world.

var world: FlatWorld


func before_each() -> void:
	world = add_child_autofree(FlatWorld.create())


func test_bus_settles_upright_on_its_wheels() -> void:
	var bus := await world.spawn_bus(self)
	assert_almost_eq(bus.global_transform.basis.y.dot(Vector3.UP), 1.0, 0.01, "upright")
	assert_between(bus.global_position.y, -0.3, 0.4, "resting on suspension, not sunk")
	assert_lt(bus.linear_velocity.length(), 0.2, "at rest")
	for wheel_name in ["WheelFL", "WheelFR", "WheelRL", "WheelRR"]:
		var wheel: VehicleWheel3D = bus.get_node(wheel_name)
		assert_true(wheel.is_in_contact(), "%s touches the ground" % wheel_name)


func test_bus_builds_expected_parts() -> void:
	var bus := Bus.create(BusSpec.new())
	autofree(bus)
	assert_not_null(bus.get_node_or_null("Hull"))
	assert_not_null(bus.get_node_or_null("BodyMesh"))
	var steering := 0
	var traction := 0
	for child in bus.get_children():
		if child is VehicleWheel3D:
			steering += 1 if child.use_as_steering else 0
			traction += 1 if child.use_as_traction else 0
	assert_eq(steering, 2, "front wheels steer")
	assert_eq(traction, 2, "rear-wheel drive")
	assert_eq(bus.collision_layer, Layers.PLAYER)
	assert_eq(bus.mass, BusSpec.new().mass)


func test_throttle_accelerates_forward_along_plus_z() -> void:
	var bus := await world.spawn_bus(self)
	bus.set_command(1.0, 0.0, 0.0)
	await wait_seconds(4.0)
	assert_gt(bus.forward_speed(), 5.0)
	assert_gt(bus.global_position.z, 8.0)
	assert_almost_eq(bus.global_position.x, 0.0, 0.5, "drives straight")


func test_acceleration_is_bus_like_not_sports_car() -> void:
	var bus := await world.spawn_bus(self)
	bus.set_command(1.0, 0.0, 0.0)
	await wait_seconds(2.0)
	var speed := bus.forward_speed()
	assert_between(speed, 2.0, 7.0, "0-2s speed (m/s)")


func test_reaches_but_never_exceeds_top_speed() -> void:
	var bus := await world.spawn_bus(self)
	bus.set_command(1.0, 0.0, 0.0)
	var peak := 0.0
	for i in 60 * 30:
		await get_tree().physics_frame
		peak = maxf(peak, bus.forward_speed())
	assert_gt(peak, bus.spec.top_speed * 0.85, "gets close to top speed")
	assert_le(peak, bus.spec.top_speed * 1.01, "never exceeds top speed")


func test_top_speed_factor_limits_speed() -> void:
	var bus := await world.spawn_bus(self)
	bus.top_speed_factor = 0.5
	bus.set_command(1.0, 0.0, 0.0)
	await wait_seconds(20.0)
	assert_le(bus.forward_speed(), bus.spec.top_speed * 0.5 * 1.01)
	assert_gt(bus.forward_speed(), bus.spec.top_speed * 0.5 * 0.8)


func test_acceleration_factor_changes_acceleration() -> void:
	var slow := await world.spawn_bus(self)
	var fast := await world.spawn_bus(self, BusSpec.new(), Vector3(20, 0.3, 0))
	fast.acceleration_factor = 1.5
	slow.set_command(1.0, 0.0, 0.0)
	fast.set_command(1.0, 0.0, 0.0)
	await wait_seconds(3.0)
	assert_gt(fast.forward_speed(), slow.forward_speed() * 1.2)


func test_brake_stops_bus_within_reasonable_distance() -> void:
	var bus := await world.spawn_bus(self)
	bus.set_command(1.0, 0.0, 0.0)
	await wait_until(func() -> bool: return bus.forward_speed() > 13.0, 20.0)
	var start := bus.global_position
	bus.set_command(0.0, 1.0, 0.0)
	var stopped := await wait_until(func() -> bool: return bus.forward_speed() < 0.3, 10.0)
	assert_true(stopped, "bus stopped")
	var distance := bus.global_position.distance_to(start)
	assert_between(distance, 8.0, 45.0, "stopping distance from ~47 km/h")


func test_brake_factor_shortens_stopping_distance() -> void:
	var distances := []
	for factor in [1.0, 1.6]:
		var bus := await world.spawn_bus(
			self, BusSpec.new(), Vector3(40 * distances.size(), 0.3, 0)
		)
		bus.brake_factor = factor
		bus.set_command(1.0, 0.0, 0.0)
		await wait_until(func() -> bool: return bus.forward_speed() > 12.0, 20.0)
		var start := bus.global_position
		bus.set_command(0.0, 1.0, 0.0)
		await wait_until(func() -> bool: return bus.forward_speed() < 0.3, 10.0)
		distances.append(bus.global_position.distance_to(start))
	assert_lt(distances[1], distances[0])


func test_holding_brake_at_standstill_reverses_slowly() -> void:
	var bus := await world.spawn_bus(self)
	bus.set_command(0.0, 1.0, 0.0)
	await wait_seconds(6.0)
	assert_lt(bus.forward_speed(), -1.0, "moving backwards")
	assert_ge(bus.forward_speed(), -Drivetrain.REVERSE_TOP_SPEED * 1.05, "reverse is slow")
	assert_lt(bus.global_position.z, -2.0)


func test_steering_right_turns_clockwise_and_left_anticlockwise() -> void:
	var right_bus := await world.spawn_bus(self)
	var left_bus := await world.spawn_bus(self, BusSpec.new(), Vector3(60, 0.3, 0))
	right_bus.set_command(0.6, 0.0, 1.0)
	left_bus.set_command(0.6, 0.0, -1.0)
	await wait_seconds(3.0)
	# Bus +X is its left; turning right drifts toward world -X when starting along +Z.
	assert_lt(right_bus.global_position.x, -1.0, "right turn moves to -X")
	assert_gt(left_bus.global_position.x, 61.0, "left turn moves to +X")
	assert_lt(right_bus.rotation.y, 0.0, "clockwise yaw from above")
	assert_gt(left_bus.rotation.y, 0.0)


func test_bus_does_not_roll_over_in_full_lock_turn_at_speed() -> void:
	var bus := await world.spawn_bus(self)
	bus.set_command(1.0, 0.0, 0.0)
	await wait_until(func() -> bool: return bus.forward_speed() > 14.0, 20.0)
	bus.set_command(1.0, 0.0, 1.0)
	await wait_seconds(5.0)
	assert_gt(bus.global_transform.basis.y.dot(Vector3.UP), 0.9, "still upright")


func test_disabled_controls_hold_the_bus() -> void:
	var bus := await world.spawn_bus(self)
	bus.set_command(1.0, 0.0, 0.0)
	await wait_seconds(3.0)
	bus.controls_enabled = false
	await wait_seconds(6.0)
	assert_lt(absf(bus.forward_speed()), 0.3)
	assert_eq(bus.input.throttle, 0.0)


func test_command_changed_signal_fires_only_on_change() -> void:
	var bus := Bus.create(BusSpec.new())
	autofree(bus)
	watch_signals(bus)
	bus.set_command(1.0, 0.0, 0.0)
	bus.set_command(1.0, 0.0, 0.0)
	bus.set_command(0.0, 0.0, 0.0)
	assert_signal_emit_count(bus, "command_changed", 2)


func test_paint_can_be_changed() -> void:
	var bus := Bus.create(BusSpec.new())
	autofree(bus)
	bus.set_paint(Color.HOT_PINK)
	assert_eq(bus.get_paint(), Color.HOT_PINK)


func test_speed_kmh_matches_forward_speed() -> void:
	var bus := await world.spawn_bus(self)
	bus.set_command(1.0, 0.0, 0.0)
	await wait_seconds(3.0)
	assert_almost_eq(bus.speed_kmh(), absf(bus.forward_speed()) * 3.6, 0.001)
