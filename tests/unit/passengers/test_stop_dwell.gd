extends TestCase

var dwell: StopDwell


func before_each() -> void:
	dwell = StopDwell.new()
	dwell.dwell_time = 1.0


func test_serves_after_dwell_time_stationary_in_zone() -> void:
	assert_false(dwell.update(true, 0.0, 0.5))
	assert_almost_eq(dwell.progress(), 0.5, 0.001)
	assert_true(dwell.update(true, 0.0, 0.5))


func test_fires_only_once_per_dwell() -> void:
	dwell.update(true, 0.0, 1.0)
	assert_false(dwell.update(true, 0.0, 0.1), "timer restarted after serving")


func test_moving_or_leaving_resets_the_timer() -> void:
	dwell.update(true, 0.0, 0.9)
	assert_false(dwell.update(true, 3.0, 0.1), "rolling through doesn't count")
	assert_eq(dwell.progress(), 0.0)
	dwell.update(true, 0.0, 0.9)
	assert_false(dwell.update(false, 0.0, 0.2), "outside the zone")
	assert_eq(dwell.progress(), 0.0)


func test_slow_creep_counts_as_stopped() -> void:
	assert_true(dwell.update(true, StopDwell.STOPPED_SPEED * 0.5, 1.0))
	assert_true(dwell.update(true, -0.2, 1.0), "tiny reverse creep too")


func test_reset() -> void:
	dwell.update(true, 0.0, 0.7)
	dwell.reset()
	assert_eq(dwell.progress(), 0.0)
