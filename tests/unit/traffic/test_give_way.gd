extends TestCase
## Give-way decision and the virtual gap a yielding car acts on.

const BUS := 11.0


func test_yields_only_in_the_signalled_lane() -> void:
	assert_true(GiveWay.should_yield(1, 1, 20.0, BUS))
	assert_false(GiveWay.should_yield(0, 1, 20.0, BUS), "other lane ignores the signal")
	assert_false(GiveWay.should_yield(1, -1, 20.0, BUS), "no signal, no courtesy")


func test_only_cars_behind_the_bus_yield() -> void:
	assert_false(GiveWay.should_yield(1, 1, -2.0, BUS), "car already ahead")
	assert_false(GiveWay.should_yield(1, 1, 0.0, BUS))
	assert_true(GiveWay.should_yield(1, 1, 3.0, BUS), "just behind the bus centre")


func test_cars_far_behind_do_not_react_yet() -> void:
	assert_true(GiveWay.should_yield(1, 1, GiveWay.YIELD_ZONE + BUS - 1.0, BUS))
	assert_false(GiveWay.should_yield(1, 1, GiveWay.YIELD_ZONE + BUS + 1.0, BUS))


func test_virtual_gap_includes_courtesy_margin() -> void:
	var real_gap := 30.0 - BUS / 2.0 - TrafficCar.LENGTH / 2.0
	var gap := GiveWay.virtual_gap(30.0, BUS, TrafficCar.LENGTH)
	assert_almost_eq(gap, real_gap - GiveWay.EXTRA_GAP, 0.0001)


func test_virtual_gap_never_negative() -> void:
	assert_eq(GiveWay.virtual_gap(2.0, BUS, TrafficCar.LENGTH), 0.0)
