extends TestCase
## Design-watch tests from the GDD: with free maps and no fuel, all long-term
## pull rests on the bus/upgrade ladder, so it must always offer a next goal.

const SAMPLE_RUNS := 40


## Average payout of a perfect run (every stop served) with [param bus_id] on [param map].
func _expected_payout(bus_id: String, map: MapDef) -> float:
	var total := 0
	for seed_value in SAMPLE_RUNS:
		var riders := PassengerGenerator.generate(map.stops.size(), seed_value)
		var capacity := Catalog.bus_spec(bus_id).capacity
		var run := RouteRun.create(map.stops.size(), capacity, map.fare, riders)
		while not run.is_finished():
			run.serve_stop(run.next_stop)
		total += run.payout()
	return float(total) / SAMPLE_RUNS


func _best_map() -> MapDef:
	var best: MapDef = null
	for map in Maps.all():
		if best == null or map.fare > best.fare:
			best = map
	return best


func test_a_run_always_pays_something() -> void:
	for map in Maps.all():
		assert_gt(_expected_payout(Catalog.STARTER_BUS, map), 0.0, map.id)


func test_bigger_buses_earn_more_per_run() -> void:
	var map := _best_map()
	var minibus := _expected_payout("minibus", map)
	var city := _expected_payout("city", map)
	assert_gt(city, minibus * 1.3, "buying up must noticeably raise income")


func test_next_bus_always_takes_several_runs_to_afford() -> void:
	var map := _best_map()
	var buses := Catalog.BUSES
	for i in range(1, buses.size()):
		var income := _expected_payout(buses[i - 1]["id"], map)
		var runs_needed: float = buses[i]["price"] / income
		assert_between(
			runs_needed,
			4.0,
			60.0,
			"runs to go from %s to %s" % [buses[i - 1]["id"], buses[i]["id"]]
		)


func test_whole_ladder_is_a_long_chase() -> void:
	var total := 0
	for bus_id in Catalog.bus_ids():
		total += Catalog.bus_price(bus_id)
		for kind in Catalog.UPGRADE_KEYS:
			for level in Catalog.MAX_UPGRADE_LEVEL:
				total += Catalog.upgrade_price(kind, level, bus_id)
	var best_income := _expected_payout("coach", _best_map())
	assert_gt(total / best_income, 100.0, "hours of goals even with the best bus")
