extends TestCase
## Catalog data validation and pricing rules.


func test_bus_ids_are_unique_and_starter_is_free() -> void:
	var ids := Catalog.bus_ids()
	var seen := {}
	for bus_id in ids:
		assert_false(seen.has(bus_id), "duplicate bus %s" % bus_id)
		seen[bus_id] = true
	assert_has(ids, Catalog.STARTER_BUS)
	assert_eq(Catalog.bus_price(Catalog.STARTER_BUS), 0)


func test_every_bus_spec_is_physically_sensible() -> void:
	for bus_id in Catalog.bus_ids():
		var spec := Catalog.bus_spec(bus_id)
		var where := "bus %s" % bus_id
		assert_eq(spec.id, bus_id, where)
		assert_false(spec.display_name.is_empty(), where)
		assert_gt(spec.capacity, 0, where)
		assert_between(spec.mass, 2000.0, 20000.0, where)
		assert_between(spec.top_speed, 12.0, 35.0, where)
		assert_between(spec.max_steer, 0.3, 0.7, where)
		assert_between(spec.length, 5.0, 15.0, where)
		assert_between(spec.height, 2.0, 4.6, where)
		# Similar power-to-weight across the range keeps every bus drivable.
		assert_between(spec.engine_force / spec.mass, 2.0, 3.5, where + " accel")
		assert_between(spec.brake_force / spec.mass, 0.012, 0.025, where + " brakes")


func test_buses_are_sold_in_ascending_price_and_each_offers_more() -> void:
	var previous: Dictionary = {}
	for bus in Catalog.BUSES:
		if not previous.is_empty():
			assert_gt(bus["price"], previous["price"], "%s pricier than previous" % bus["id"])
			var better: bool = (
				bus["capacity"] > previous["capacity"] or bus["top_speed"] > previous["top_speed"]
			)
			assert_true(better, "%s must beat the previous bus at something" % bus["id"])
		previous = bus


func test_capacity_is_not_an_upgrade() -> void:
	for kind in Catalog.UPGRADE_KEYS:
		assert_ne(Catalog.upgrade_key(kind), "capacity")


func test_upgrade_prices_rise_with_level_and_stop_at_max() -> void:
	for bus_id in Catalog.bus_ids():
		for kind in Catalog.UPGRADE_KEYS:
			var last := 0
			for level in Catalog.MAX_UPGRADE_LEVEL:
				var price := Catalog.upgrade_price(kind, level, bus_id)
				assert_gt(price, last)
				assert_eq(price % 10, 0, "prices are round numbers")
				last = price
			assert_eq(Catalog.upgrade_price(kind, Catalog.MAX_UPGRADE_LEVEL, bus_id), -1)


func test_pricier_buses_have_pricier_upgrades() -> void:
	var cheap := Catalog.upgrade_price(Catalog.Upgrade.BRAKES, 0, "minibus")
	var dear := Catalog.upgrade_price(Catalog.Upgrade.BRAKES, 0, "coach")
	assert_gt(dear, cheap)


func test_upgrade_factor() -> void:
	assert_eq(Catalog.upgrade_factor(Catalog.Upgrade.TOP_SPEED, 0), 1.0)
	assert_almost_eq(Catalog.upgrade_factor(Catalog.Upgrade.TOP_SPEED, 5), 1.3, 0.0001)
	assert_almost_eq(Catalog.upgrade_factor(Catalog.Upgrade.HANDLING, 99), 1.6, 0.0001, "clamped")


func test_upgrade_key_round_trip() -> void:
	for kind in Catalog.UPGRADE_KEYS:
		assert_eq(Catalog.upgrade_from_key(Catalog.upgrade_key(kind)), kind)
	assert_eq(Catalog.upgrade_from_key("nope"), -1)


func test_paints() -> void:
	var ids := Catalog.paint_ids()
	assert_has(ids, "stock")
	assert_eq(Catalog.paint_entry("stock")["price"], 0)
	assert_eq(Catalog.paint_color("city", "stock"), Catalog.bus_entry("city")["color"])
	assert_eq(Catalog.paint_color("city", "ocean"), Catalog.paint_entry("ocean")["color"])
	assert_eq(Catalog.paint_color("city", "bogus"), Catalog.bus_entry("city")["color"])
	var seen := {}
	for paint_id in ids:
		assert_false(seen.has(paint_id))
		seen[paint_id] = true


func test_unknown_bus_lookups_are_safe() -> void:
	assert_false(Catalog.has_bus("zeppelin"))
	assert_eq(Catalog.bus_entry("zeppelin"), {})
	assert_eq(Catalog.bus_price("zeppelin"), 0)
