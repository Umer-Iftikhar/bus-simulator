extends TestCase
## Intelligent Driver Model properties.

var idm: CarFollow


func before_each() -> void:
	idm = CarFollow.new()


func test_free_road_accelerates_from_rest_at_max() -> void:
	assert_almost_eq(idm.acceleration(0.0, 12.0, INF, 0.0), idm.max_accel, 0.0001)


func test_free_road_settles_at_desired_speed() -> void:
	assert_almost_eq(idm.acceleration(12.0, 12.0, INF, 0.0), 0.0, 0.0001)
	assert_lt(idm.acceleration(14.0, 12.0, INF, 0.0), 0.0, "too fast -> slow down")


func test_far_leader_barely_matters() -> void:
	var free := idm.acceleration(8.0, 12.0, INF, 0.0)
	var far := idm.acceleration(8.0, 12.0, 400.0, 8.0)
	assert_almost_eq(far, free, 0.05)


func test_closing_on_stopped_leader_brakes_hard() -> void:
	var accel := idm.acceleration(12.0, 12.0, 20.0, 0.0)
	assert_lt(accel, -idm.comfort_decel)


func test_braking_is_capped_at_emergency_limit() -> void:
	assert_eq(idm.acceleration(20.0, 20.0, 0.0, 0.0), -CarFollow.MAX_DECEL)


func test_standing_queue_stays_put() -> void:
	# Stopped car with a stopped leader exactly at minimum gap: no creeping forward.
	assert_le(idm.acceleration(0.0, 12.0, idm.min_gap, 0.0), 0.0)


func test_acceleration_never_exceeds_max_and_is_finite() -> void:
	for speed in [0.0, 5.0, 15.0, 30.0]:
		for gap in [0.0, 0.5, 5.0, 50.0, INF]:
			for leader in [0.0, 10.0, 30.0]:
				var a := idm.acceleration(speed, 12.0, gap, leader)
				assert_le(a, idm.max_accel)
				assert_ge(a, -CarFollow.MAX_DECEL)
				assert_false(is_nan(a))


func test_simulated_follower_never_hits_braking_leader() -> void:
	var dt := 1.0 / 60.0
	var leader_pos := 40.0
	var leader_speed := 12.0
	var pos := 0.0
	var speed := 12.0
	var min_gap := INF
	for i in 60 * 30:
		var t := i * dt
		if t > 5.0:
			leader_speed = maxf(0.0, leader_speed - 4.0 * dt)
		leader_pos += leader_speed * dt
		var gap := leader_pos - pos - 4.4
		speed = maxf(0.0, speed + idm.acceleration(speed, 13.0, gap, leader_speed) * dt)
		pos += speed * dt
		min_gap = minf(min_gap, leader_pos - pos - 4.4)
	assert_gt(min_gap, 1.0, "kept a safe gap")
	assert_lt(speed, 0.2, "stopped behind the stopped leader")
