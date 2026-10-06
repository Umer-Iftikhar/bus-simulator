extends TestCase


func test_from_dict_sets_known_fields_and_ignores_unknown() -> void:
	var spec := BusSpec.from_dict({"id": "x", "capacity": 40, "top_speed": 25.0, "bogus": 1})
	assert_eq(spec.id, "x")
	assert_eq(spec.capacity, 40)
	assert_eq(spec.top_speed, 25.0)
	assert_false("bogus" in spec)


func test_duplicate_is_independent_copy() -> void:
	var spec := BusSpec.from_dict({"capacity": 30, "color": Color.RED})
	var copy := spec.duplicate_spec()
	assert_eq(copy.capacity, 30)
	assert_eq(copy.color, Color.RED)
	copy.capacity = 99
	assert_eq(spec.capacity, 30)


func test_derived_values() -> void:
	var spec := BusSpec.from_dict({"length": 10.0, "top_speed": 20.0})
	assert_almost_eq(spec.wheelbase(), 6.2, 0.0001)
	assert_almost_eq(spec.top_speed_kmh(), 72.0, 0.0001)
