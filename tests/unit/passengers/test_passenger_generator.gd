extends TestCase


func test_same_seed_gives_same_passengers() -> void:
	var a := PassengerGenerator.generate(7, 42)
	var b := PassengerGenerator.generate(7, 42)
	assert_eq(a.size(), b.size())
	for i in a.size():
		assert_eq([a[i].board_stop, a[i].dest_stop], [b[i].board_stop, b[i].dest_stop])


func test_different_seeds_differ() -> void:
	var a := PassengerGenerator.generate(7, 1)
	var b := PassengerGenerator.generate(7, 2)
	var same := a.size() == b.size()
	if same:
		for i in a.size():
			same = same and a[i].dest_stop == b[i].dest_stop
	assert_false(same)


func test_destinations_are_after_boarding_stop_and_nobody_waits_at_terminal() -> void:
	for seed_value in 20:
		for p in PassengerGenerator.generate(6, seed_value):
			assert_between(p.board_stop, 0, 4)
			assert_between(p.dest_stop, p.board_stop + 1, 5)
			assert_eq(p.state, Passenger.State.WAITING)


func test_counts_per_stop_respect_bounds() -> void:
	var passengers := PassengerGenerator.generate(8, 9, 3, 5)
	var per_stop := {}
	for p in passengers:
		per_stop[p.board_stop] = per_stop.get(p.board_stop, 0) + 1
	assert_eq(per_stop.size(), 7, "every stop but the terminal has riders")
	for stop in per_stop:
		assert_between(per_stop[stop], 3, 5)


func test_ids_are_unique() -> void:
	var ids := {}
	for p in PassengerGenerator.generate(7, 3):
		assert_false(ids.has(p.id))
		ids[p.id] = true
