extends TestCase
## Which lanes a vehicle overlaps, from its lateral position and half-width.

const HALF_BUS := 1.25


func test_centred_in_a_lane_occupies_only_that_lane() -> void:
	assert_eq(TrafficManager.lanes_occupied(Track.lane_lateral(0), HALF_BUS), [0])
	assert_eq(TrafficManager.lanes_occupied(Track.lane_lateral(1), HALF_BUS), [1])


func test_straddling_the_divider_occupies_both() -> void:
	assert_eq(TrafficManager.lanes_occupied(0.0, HALF_BUS), [0, 1])
	assert_eq(TrafficManager.lanes_occupied(0.6, HALF_BUS), [0, 1])


func test_far_off_road_occupies_nothing() -> void:
	assert_eq(TrafficManager.lanes_occupied(15.0, HALF_BUS), [])
	assert_eq(TrafficManager.lanes_occupied(-15.0, HALF_BUS), [])
