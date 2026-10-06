extends TestCase
## Metro-style boarding, alighting, capacity, missed stops and pay.

const FARE := 10


func _run(riders: Array, capacity := 10, stops := 4) -> RouteRun:
	var typed: Array[Passenger] = []
	for i in riders.size():
		typed.append(Passenger.make(i, riders[i][0], riders[i][1]))
	return RouteRun.create(stops, capacity, FARE, typed)


func test_passengers_board_and_alight_at_their_stops() -> void:
	var run := _run([[0, 2], [0, 3], [1, 3]])
	assert_eq(run.serve_stop(0), {"alighted": 0, "boarded": 2, "left_behind": 0})
	assert_eq(run.on_board_count(), 2)
	assert_eq(run.serve_stop(1), {"alighted": 0, "boarded": 1, "left_behind": 0})
	assert_eq(run.serve_stop(2), {"alighted": 1, "boarded": 0, "left_behind": 0})
	assert_eq(run.delivered, 1)
	assert_eq(run.serve_stop(3), {"alighted": 2, "boarded": 0, "left_behind": 0})
	assert_eq(run.delivered, 3)
	assert_true(run.is_finished())
	assert_eq(run.payout(), 3 * FARE)


func test_capacity_limits_boarding_and_leaves_rest_behind() -> void:
	var run := _run([[0, 3], [0, 3], [0, 3], [0, 1]], 2)
	var outcome := run.serve_stop(0)
	assert_eq(outcome["boarded"], 2)
	assert_eq(outcome["left_behind"], 2)
	assert_eq(run.stranded_count(), 2)
	assert_eq(run.waiting_at(0), 0)


func test_freed_seats_are_reused_later_on_the_route() -> void:
	var run := _run([[0, 1], [0, 1], [1, 3], [1, 3]], 2)
	run.serve_stop(0)
	var outcome := run.serve_stop(1)
	assert_eq(outcome, {"alighted": 2, "boarded": 2, "left_behind": 0})


func test_stops_must_be_served_in_order() -> void:
	var run := _run([[0, 2], [1, 3]])
	assert_eq(run.serve_stop(1)["boarded"], 0, "can't serve stop 1 before stop 0")
	assert_eq(run.next_stop, 0)
	run.serve_stop(0)
	assert_eq(run.serve_stop(0)["boarded"], 0, "can't serve the same stop twice")
	assert_eq(run.next_stop, 1)


func test_skipping_a_stop_strands_its_waiting_passengers() -> void:
	var run := _run([[0, 3], [1, 3], [1, 2]])
	run.serve_stop(0)
	assert_true(run.skip_stop(1))
	assert_eq(run.missed_stops, [1])
	assert_eq(run.waiting_at(1), 0)
	assert_eq(run.stranded_count(), 2)
	assert_eq(run.next_stop, 2)


func test_rider_whose_stop_was_missed_gets_off_next_without_paying() -> void:
	var run := _run([[0, 1], [0, 2]])
	run.serve_stop(0)
	run.skip_stop(1)
	var outcome := run.serve_stop(2)
	assert_eq(outcome["alighted"], 2)
	assert_eq(run.delivered, 1, "only the rider bound for stop 2 pays")
	assert_eq(run.stranded_count(), 1)


func test_terminals_cannot_be_skipped() -> void:
	var run := _run([[0, 3]])
	run.serve_stop(0)
	run.serve_stop(1)
	run.serve_stop(2)
	assert_false(run.skip_stop(3))
	assert_false(run.is_finished())


func test_skip_must_be_the_next_stop() -> void:
	var run := _run([[0, 3]])
	assert_false(run.skip_stop(2))
	assert_eq(run.next_stop, 0)


func test_payout_is_zero_until_finished_and_when_failed() -> void:
	var run := _run([[0, 1]], 10, 2)
	run.serve_stop(0)
	assert_eq(run.payout(), 0, "unfinished")
	assert_eq(run.earnings_so_far(), 0)
	run.serve_stop(1)
	assert_eq(run.payout(), FARE)
	assert_eq(run.earnings_so_far(), FARE)
	var wrecked := _run([[0, 1]], 10, 2)
	wrecked.serve_stop(0)
	wrecked.fail()
	assert_eq(wrecked.serve_stop(1)["alighted"], 0, "a failed run accepts no more stops")
	assert_eq(wrecked.payout(), 0)


func test_signals_report_each_stop_and_finish() -> void:
	var run := _run([[0, 2], [1, 2]], 10, 3)
	watch_signals(run)
	run.serve_stop(0)
	run.skip_stop(1)
	run.serve_stop(2)
	assert_signal_emit_count(run, "stop_served", 2)
	assert_eq(get_signal_parameters(run, "stop_served", 0), [0, 0, 1, 0])
	assert_eq(get_signal_parameters(run, "stop_missed"), [1])
	assert_signal_emit_count(run, "finished", 1)


func test_every_passenger_is_accounted_for_after_random_runs() -> void:
	for seed_value in 30:
		var riders := PassengerGenerator.generate(7, seed_value)
		var run := RouteRun.create(7, 12, FARE, riders)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		while not run.is_finished():
			if not run.is_terminal(run.next_stop) and rng.randf() < 0.2:
				run.skip_stop(run.next_stop)
			else:
				run.serve_stop(run.next_stop)
			assert_le(run.on_board_count(), 12, "never over capacity")
		var delivered := 0
		for p in riders:
			assert_true(
				p.state in [Passenger.State.DELIVERED, Passenger.State.STRANDED],
				"no one is left waiting or riding at the end"
			)
			delivered += 1 if p.state == Passenger.State.DELIVERED else 0
		assert_eq(run.delivered, delivered)
		assert_eq(run.payout(), delivered * FARE)
