extends TestCase
## Data validation for every shipped map.


func test_there_is_at_least_one_map_and_ids_are_unique() -> void:
	var ids := Maps.ids()
	assert_gt(ids.size(), 0)
	var seen := {}
	for map_id in ids:
		assert_false(seen.has(map_id), "duplicate map id %s" % map_id)
		seen[map_id] = true


func test_get_map_finds_each_map_and_rejects_unknown() -> void:
	for map in Maps.all():
		assert_eq(Maps.get_map(map.id).display_name, map.display_name)
	assert_null(Maps.get_map("does-not-exist"))


func test_map_fields_are_valid() -> void:
	for map in Maps.all():
		var where := "map %s" % map.id
		assert_false(map.display_name.is_empty(), where)
		assert_gt(map.fare, 0, where)
		assert_ge(map.points.size(), 4, where)
		assert_ge(map.stops.size(), 3, where + ": needs terminals plus a stop")
		assert_ge(map.traffic_cars, 0, where)
		assert_gt(map.building_colors.size(), 0, where)
		assert_le(map.building_height.x, map.building_height.y, where)


func test_stops_are_ordered_inside_the_loop_and_spaced_apart() -> void:
	for map in Maps.all():
		var length := map.track().length()
		var previous := -1.0
		for fraction in map.stops:
			assert_between(fraction, 0.0, 1.0, "map %s stop fraction" % map.id)
			assert_gt(fraction, previous, "map %s stops must increase" % map.id)
			if previous >= 0.0:
				assert_gt((fraction - previous) * length, 60.0, "map %s stops too close" % map.id)
			previous = fraction


func test_loop_is_long_enough_for_a_route() -> void:
	for map in Maps.all():
		assert_between(map.track().length(), 600.0, 4000.0, "map %s" % map.id)


func test_road_never_overlaps_itself() -> void:
	# Points far apart along the loop must stay at least a road width apart in space.
	for map in Maps.all():
		var track := map.track()
		var samples: Array[Vector3] = []
		var step := 4.0
		var count := int(track.length() / step)
		for i in count:
			samples.append(track.position_at(i * step))
		var min_gap := track.half_width() * 2.0 + 4.0
		var worst := INF
		for i in count:
			for j in range(i + 1, count):
				var along := minf((j - i) * step, track.length() - (j - i) * step)
				if along < 60.0:
					continue
				worst = minf(worst, samples[i].distance_to(samples[j]))
		assert_gt(worst, min_gap, "map %s road comes within %.1fm of itself" % [map.id, worst])


func test_bends_are_drivable_by_a_bus() -> void:
	# Turning radius anywhere on the centre line must exceed ~15m.
	for map in Maps.all():
		var track := map.track()
		var tightest := INF
		var offset := 0.0
		while offset < track.length():
			var turn := track.forward_at(offset).angle_to(track.forward_at(offset + 4.0))
			if turn > 0.0001:
				tightest = minf(tightest, 4.0 / turn)
			offset += 2.0
		assert_gt(tightest, 15.0, "map %s tightest radius %.1fm" % [map.id, tightest])


func test_stop_offset_matches_fraction() -> void:
	var map := Maps.harbor()
	assert_almost_eq(map.stop_offset(1), map.stops[1] * map.track().length(), 0.001)


func test_a_handful_of_characterful_maps() -> void:
	var maps := Maps.all()
	assert_between(maps.size(), 4, 6, "quality over quantity")
	var grounds := {}
	var fares := {}
	var has_night := false
	for map in maps:
		grounds[map.ground_color] = true
		fares[map.fare] = true
		has_night = has_night or map.night
		assert_false(map.description.is_empty(), map.id)
	assert_eq(grounds.size(), maps.size(), "each map looks different")
	assert_gt(fares.size(), 2, "harder/prettier maps pay differently")
	assert_true(has_night, "at least one night map")


func test_busiest_map_pays_best() -> void:
	var busiest: MapDef = null
	var best_fare := 0
	for map in Maps.all():
		best_fare = maxi(best_fare, map.fare)
		if busiest == null or map.traffic_cars > busiest.traffic_cars:
			busiest = map
	assert_eq(busiest.fare, best_fare, "the hardest map rewards it")
