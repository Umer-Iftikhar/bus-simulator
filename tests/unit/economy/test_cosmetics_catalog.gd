extends TestCase
## Cosmetic catalogue and bus styles.

const STYLES := ["minibus", "city", "double_decker", "coach"]


func test_every_category_has_a_free_default_first() -> void:
	for category in Catalog.cosmetic_categories():
		var first: Dictionary = Catalog.COSMETICS[category][0]
		assert_eq(first["price"], 0, "%s default is free" % category)
		assert_eq(Catalog.cosmetic_default(category), first["id"])
		assert_true(Catalog.COSMETIC_NAMES.has(category))


func test_ids_unique_names_present_prices_sane() -> void:
	for category in Catalog.cosmetic_categories():
		var seen := {}
		for item in Catalog.COSMETICS[category]:
			assert_false(seen.has(item["id"]), "%s duplicate %s" % [category, item["id"]])
			seen[item["id"]] = true
			assert_false(str(item["display_name"]).is_empty())
			assert_between(item["price"], 0, 5000, "%s:%s price" % [category, item["id"]])
		assert_ge(seen.size(), 3, "%s offers real choice" % category)


func test_items_carry_what_the_bus_needs_to_render_them() -> void:
	for item in Catalog.RIMS:
		for key in ["color", "metallic", "roughness"]:
			assert_true(item.has(key), "rims:%s %s" % [item["id"], key])
	var previous := -1.0
	for item in Catalog.TINTS:
		assert_gt(item["darkness"], previous, "tints get darker")
		previous = item["darkness"]
	for category in ["stripe", "roof"]:
		for item in Catalog.COSMETICS[category].slice(1):
			assert_true(item.get("color") is Color, "%s:%s colour" % [category, item["id"]])
		assert_null(
			Catalog.COSMETICS[category][0].get("color"), "%s default has no override" % category
		)


func test_unknown_lookups_are_safe() -> void:
	assert_eq(Catalog.cosmetic_entry("rims", "spinners"), {})
	assert_eq(Catalog.cosmetic_entry("wings", "big"), {})
	assert_eq(Catalog.cosmetic_ids("wings").size(), 0)


func test_four_distinct_bus_types() -> void:
	var styles := {}
	for bus_id in Catalog.bus_ids():
		var spec := Catalog.bus_spec(bus_id)
		assert_has(STYLES, spec.style, bus_id)
		styles[spec.style] = true
	assert_eq(styles.size(), 4, "minibus, city, double decker and coach")


func test_style_geometry_rules() -> void:
	var minibus := BusSpec.from_dict({"style": "minibus"})
	var city := BusSpec.from_dict({"style": "city"})
	var coach := BusSpec.from_dict({"style": "coach"})
	assert_gt(minibus.cab_offset(), 0.5, "minibus has a bonnet")
	assert_eq(city.cab_offset(), 0.0, "city bus is flat-fronted")
	assert_gt(coach.windscreen_rake(), 0.1)
	assert_eq(city.windscreen_rake(), 0.0)
	assert_gt(coach.belt_fraction(), city.belt_fraction(), "coach passengers sit high")
