extends TestCase
## Purchase rules: buses, upgrades, paint, selection and banking runs.

var save: SaveData
var garage: Garage


func before_each() -> void:
	save = SaveData.new_game()
	garage = Garage.new(save)


func test_buy_bus_spends_price_and_grants_ownership() -> void:
	save.wallet.earn(5000)
	assert_eq(garage.buy_bus("city"), Garage.Result.OK)
	assert_true(save.owns("city"))
	assert_eq(save.money, 5000 - Catalog.bus_price("city"))


func test_buy_bus_failures() -> void:
	assert_eq(garage.buy_bus("city"), Garage.Result.CANT_AFFORD)
	assert_false(save.owns("city"))
	assert_eq(garage.buy_bus(Catalog.STARTER_BUS), Garage.Result.ALREADY_OWNED)
	assert_eq(garage.buy_bus("zeppelin"), Garage.Result.UNKNOWN_ITEM)


func test_select_bus_requires_ownership() -> void:
	assert_eq(garage.select_bus("city"), Garage.Result.NOT_OWNED)
	assert_eq(save.selected_bus, Catalog.STARTER_BUS)
	save.wallet.earn(10000)
	garage.buy_bus("city")
	assert_eq(garage.select_bus("city"), Garage.Result.OK)
	assert_eq(save.selected_bus, "city")


func test_select_map() -> void:
	assert_eq(garage.select_map("atlantis"), Garage.Result.UNKNOWN_ITEM)
	assert_eq(garage.select_map(Maps.ids()[0]), Garage.Result.OK)


func test_buy_upgrade_charges_next_level_price() -> void:
	save.wallet.earn(100000)
	var kind := Catalog.Upgrade.TOP_SPEED
	var expected := Catalog.upgrade_price(kind, 0, "minibus")
	assert_eq(garage.next_upgrade_price("minibus", kind), expected)
	assert_eq(garage.buy_upgrade("minibus", kind), Garage.Result.OK)
	assert_eq(save.upgrade_level("minibus", kind), 1)
	assert_eq(save.money, 100000 - expected)
	assert_eq(garage.next_upgrade_price("minibus", kind), Catalog.upgrade_price(kind, 1, "minibus"))


func test_upgrade_stops_at_max_level() -> void:
	save.wallet.earn(1000000)
	var kind := Catalog.Upgrade.HANDLING
	for i in Catalog.MAX_UPGRADE_LEVEL:
		assert_eq(garage.buy_upgrade("minibus", kind), Garage.Result.OK)
	var money := save.money
	assert_eq(garage.buy_upgrade("minibus", kind), Garage.Result.MAXED)
	assert_eq(save.money, money, "no charge when maxed")


func test_upgrade_failures() -> void:
	assert_eq(garage.buy_upgrade("coach", Catalog.Upgrade.BRAKES), Garage.Result.NOT_OWNED)
	assert_eq(garage.buy_upgrade("minibus", Catalog.Upgrade.BRAKES), Garage.Result.CANT_AFFORD)
	assert_eq(save.upgrade_level("minibus", Catalog.Upgrade.BRAKES), 0)


func test_upgrades_are_per_bus() -> void:
	save.wallet.earn(100000)
	garage.buy_bus("city")
	garage.buy_upgrade("city", Catalog.Upgrade.BRAKES)
	assert_eq(save.upgrade_level("city", Catalog.Upgrade.BRAKES), 1)
	assert_eq(save.upgrade_level("minibus", Catalog.Upgrade.BRAKES), 0)


func test_paint_is_bought_once_then_reapplied_free() -> void:
	save.wallet.earn(1000)
	assert_eq(garage.buy_paint("minibus", "ocean"), Garage.Result.OK)
	assert_eq(save.paint("minibus"), "ocean")
	var after_purchase := save.money
	assert_eq(after_purchase, 1000 - Catalog.paint_entry("ocean")["price"])
	garage.buy_paint("minibus", "stock")
	assert_eq(garage.buy_paint("minibus", "ocean"), Garage.Result.OK)
	assert_eq(save.money, after_purchase, "re-applying an owned paint is free")


func test_paint_failures() -> void:
	assert_eq(garage.buy_paint("minibus", "gold"), Garage.Result.CANT_AFFORD)
	assert_eq(garage.buy_paint("minibus", "plaid"), Garage.Result.UNKNOWN_ITEM)
	assert_eq(garage.buy_paint("coach", "stock"), Garage.Result.NOT_OWNED)
	assert_eq(save.paint("minibus"), "stock")


func test_performance_reflects_upgrade_levels() -> void:
	save.wallet.earn(100000)
	garage.buy_upgrade("minibus", Catalog.Upgrade.ACCELERATION)
	garage.buy_upgrade("minibus", Catalog.Upgrade.ACCELERATION)
	var factors := garage.performance("minibus")
	assert_almost_eq(factors["acceleration"], 1.2, 0.0001)
	assert_eq(factors["top_speed"], 1.0)
	assert_eq(factors.size(), Catalog.UPGRADE_KEYS.size())


func test_spec_for_applies_paint_without_touching_catalog() -> void:
	save.wallet.earn(1000)
	garage.buy_paint("minibus", "forest")
	assert_eq(garage.spec_for("minibus").color, Catalog.paint_entry("forest")["color"])
	assert_eq(Catalog.bus_spec("minibus").color, Catalog.bus_entry("minibus")["color"])


func test_record_run_banks_payout_and_stats() -> void:
	garage.record_run(240, 20)
	garage.record_run(0, 0)
	assert_eq(save.money, 240)
	assert_eq(save.stats, {"runs": 2, "delivered": 20, "earned": 240})


func _damage(bus_id: String, parts: Dictionary) -> void:
	save.owned[bus_id]["damage"] = parts


func test_repair_charges_cost_and_restores_bus() -> void:
	_damage("minibus", {"body_front": 0.4, "mirror_left": 0.0})
	var cost := garage.repair_cost("minibus")
	assert_gt(cost, 0)
	save.wallet.earn(cost + 5)
	assert_eq(garage.repair("minibus"), Garage.Result.OK)
	assert_eq(save.money, 5)
	assert_true(garage.damage_of("minibus").is_pristine())
	assert_eq(save.damage("minibus"), {})


func test_repair_failures() -> void:
	assert_eq(garage.repair("minibus"), Garage.Result.NOT_DAMAGED)
	assert_eq(garage.repair("coach"), Garage.Result.NOT_OWNED)
	_damage("minibus", {"body_rear": 0.1})
	assert_eq(garage.repair("minibus"), Garage.Result.CANT_AFFORD)
	assert_eq(save.damage("minibus"), {"body_rear": 0.1}, "unpaid repair changes nothing")


func test_store_damage_saves_only_damaged_parts() -> void:
	var model := DamageModel.new()
	model.apply_impact(DamageModel.BODY_LEFT, 5.0)
	garage.store_damage("minibus", model)
	assert_eq(save.damage("minibus").keys(), [DamageModel.BODY_LEFT])
	garage.store_damage("coach", model)
	assert_false(save.owns("coach"), "storing damage never grants a bus")


func test_cosmetics_start_at_defaults() -> void:
	for category in Catalog.cosmetic_categories():
		assert_eq(save.cosmetic("minibus", category), Catalog.cosmetic_default(category))
		assert_true(save.owns_cosmetic("minibus", category, Catalog.cosmetic_default(category)))


func test_buy_cosmetic_charges_once_then_reapplies_free() -> void:
	save.wallet.earn(2000)
	var price: int = Catalog.cosmetic_entry("rims", "chrome")["price"]
	assert_eq(garage.buy_cosmetic("minibus", "rims", "chrome"), Garage.Result.OK)
	assert_eq(save.cosmetic("minibus", "rims"), "chrome")
	assert_eq(save.money, 2000 - price)
	garage.buy_cosmetic("minibus", "rims", "steel")
	assert_eq(garage.buy_cosmetic("minibus", "rims", "chrome"), Garage.Result.OK)
	assert_eq(save.money, 2000 - price, "already owned: free")


func test_buy_cosmetic_failures() -> void:
	assert_eq(garage.buy_cosmetic("minibus", "rims", "gold"), Garage.Result.CANT_AFFORD)
	assert_eq(garage.buy_cosmetic("minibus", "rims", "spinners"), Garage.Result.UNKNOWN_ITEM)
	assert_eq(garage.buy_cosmetic("minibus", "wings", "big"), Garage.Result.UNKNOWN_ITEM)
	assert_eq(garage.buy_cosmetic("coach", "tint", "dark"), Garage.Result.NOT_OWNED)
	assert_eq(save.cosmetic("minibus", "rims"), "steel")


func test_cosmetics_are_per_bus() -> void:
	save.wallet.earn(10000)
	garage.buy_bus("city")
	garage.buy_cosmetic("city", "stripe", "red")
	assert_eq(save.cosmetic("city", "stripe"), "red")
	assert_eq(save.cosmetic("minibus", "stripe"), "none")
	assert_eq(save.cosmetics("city")["stripe"], "red")
