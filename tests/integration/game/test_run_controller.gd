extends TestCase
## RunController in a real world with a real bus: serving, missing and finishing.

var map: MapDef
var world: GameWorld
var bus: Bus
var run: RunController


func before_each() -> void:
	map = Maps.harbor()
	world = add_child_autofree(GameWorld.create(map))
	bus = Bus.create(Catalog.bus_spec("city"))
	world.add_child(bus)
	_place(0, 6.0)
	run = RunController.create(map, bus, 99)
	world.add_child(run)
	await wait_physics_frames(3)


func _place(lane: int, offset: float) -> void:
	var xform := map.track().vehicle_transform(lane, offset)
	xform.origin.y = 0.3
	bus.global_transform = xform
	bus.linear_velocity = Vector3.ZERO
	bus.angular_velocity = Vector3.ZERO


## Moves the bus forward in hops (so progress tracking sees the motion) and parks it.
func _park_at_stop(index: int) -> void:
	var target := map.stop_offset(index)
	var current := map.track().closest_offset(bus.global_position)
	while map.track().distance_ahead(current, target) > 20.0:
		current += 15.0
		_place(0, current)
		await wait_physics_frames(2)
	_place(0, target)
	await wait_seconds(run.dwell.dwell_time + 0.5)


func test_builds_one_stop_per_map_stop_with_waiting_passengers() -> void:
	assert_eq(run.stops.size(), map.stops.size())
	assert_true(run.stops[0].is_terminal)
	assert_true(run.stops[-1].is_terminal)
	assert_false(run.stops[1].is_terminal)
	assert_gt(run.stops[0].waiting(), 0)
	assert_eq(run.stops[-1].waiting(), 0, "no one waits at the end terminal")
	assert_eq(run.route.capacity, bus.spec.capacity)
	assert_eq(run.route.fare, map.fare)


func test_parking_at_next_stop_serves_it() -> void:
	watch_signals(run)
	await _park_at_stop(0)
	assert_signal_emit_count(run, "stop_served", 1)
	var params := get_signal_parameters(run, "stop_served")
	assert_eq(params[0], 0)
	assert_gt(params[2], 0, "passengers boarded")
	assert_eq(run.stops[0].waiting(), params[3], "only left-behind riders remain shown")
	assert_eq(run.route.next_stop, 1)


func test_rolling_through_a_stop_does_not_serve_it() -> void:
	watch_signals(run)
	_place(0, map.stop_offset(0))
	for i in 90:
		bus.linear_velocity = bus.global_transform.basis.z * 3.0
		await get_tree().physics_frame
	assert_signal_not_emitted(run, "stop_served")


func test_driving_past_a_stop_marks_it_missed() -> void:
	await _park_at_stop(0)
	watch_signals(run)
	var beyond := map.stop_offset(1) + BusStop.ZONE_LENGTH + bus.spec.length
	var current := map.track().closest_offset(bus.global_position)
	while current < beyond:
		current += 12.0
		_place(1, current)
		await wait_physics_frames(2)
	assert_signal_emit_count(run, "stop_missed", 1)
	assert_eq(get_signal_parameters(run, "stop_missed"), [1])
	assert_eq(run.stops[1].waiting(), 0)
	assert_eq(run.route.next_stop, 2)


func test_distance_to_next_stop_shrinks_as_bus_advances() -> void:
	var before := run.distance_to_next_stop()
	_place(0, 12.0)
	await wait_physics_frames(3)
	assert_lt(run.distance_to_next_stop(), before)
	assert_almost_eq(before - run.distance_to_next_stop(), 6.0, 1.0)


func test_serving_every_stop_finishes_with_payout() -> void:
	watch_signals(run)
	for i in map.stops.size():
		await _park_at_stop(i)
	assert_true(run.finished)
	assert_signal_emit_count(run, "run_finished", 1)
	var result: Dictionary = get_signal_parameters(run, "run_finished")[0]
	assert_true(result["completed"])
	assert_gt(result["delivered"], 0)
	assert_eq(result["payout"], result["delivered"] * map.fare)
	assert_eq(result["missed_stops"], 0)


func test_failed_run_pays_nothing() -> void:
	await _park_at_stop(0)
	watch_signals(run)
	run.fail_run()
	run.fail_run()
	assert_signal_emit_count(run, "run_finished", 1)
	var result: Dictionary = get_signal_parameters(run, "run_finished")[0]
	assert_true(result["failed"])
	assert_eq(result["payout"], 0)
