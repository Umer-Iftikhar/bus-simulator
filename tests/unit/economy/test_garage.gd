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
