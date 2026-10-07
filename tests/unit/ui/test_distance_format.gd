extends TestCase
## How distances to the next stop read on screen.


func test_short_distances_in_metres() -> void:
	assert_eq(Hud.format_distance(0.0), "0 m")
	assert_eq(Hud.format_distance(37.4), "37 m")
	assert_eq(Hud.format_distance(99.0), "99 m")


func test_hundreds_round_to_ten_metres() -> void:
	assert_eq(Hud.format_distance(123.0), "120 m")
	assert_eq(Hud.format_distance(456.0), "460 m")
	assert_eq(Hud.format_distance(999.0), "1000 m")


func test_long_distances_in_kilometres() -> void:
	assert_eq(Hud.format_distance(1000.0), "1.0 km")
	assert_eq(Hud.format_distance(1260.0), "1.3 km")
	assert_eq(Hud.format_distance(3784.0), "3.8 km")


func test_negative_is_treated_as_arrived() -> void:
	assert_eq(Hud.format_distance(-5.0), "0 m")
