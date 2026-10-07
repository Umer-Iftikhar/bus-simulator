extends TestCase
## SaveData model, serialisation round-trips and defensive loading.


func test_new_game_owns_and_selects_the_starter_bus() -> void:
	var save := SaveData.new_game()
	assert_eq(save.money, 0)
	assert_true(save.owns(Catalog.STARTER_BUS))
	assert_eq(save.selected_bus, Catalog.STARTER_BUS)
	assert_eq(save.owned_ids(), PackedStringArray([Catalog.STARTER_BUS]))
	assert_not_null(Maps.get_map(save.selected_map))
	for kind in Catalog.UPGRADE_KEYS:
		assert_eq(save.upgrade_level(Catalog.STARTER_BUS, kind), 0)
	assert_eq(save.paint(Catalog.STARTER_BUS), "stock")


func test_round_trip_through_json_preserves_everything() -> void:
	var save := SaveData.new_game()
	save.wallet.earn(1234)
	save.owned["city"] = SaveData.default_owned_bus()
	save.owned["city"]["upgrades"]["brakes"] = 3
	save.owned["city"]["owned_cosmetics"]["paint"].append("ocean")
	save.owned["city"]["cosmetics"]["paint"] = "ocean"
	save.owned["city"]["damage"] = {"mirror_left": 0.0, "body_front": 0.6}
	save.selected_bus = "city"
	save.stats["runs"] = 7
	var text := JSON.stringify(save.to_dict())
	var loaded := SaveData.from_dict(JSON.parse_string(text))
	assert_eq(loaded.money, 1234)
	assert_eq(loaded.selected_bus, "city")
	assert_eq(loaded.upgrade_level("city", Catalog.Upgrade.BRAKES), 3)
	assert_eq(loaded.paint("city"), "ocean")
	assert_eq(loaded.damage("city"), {"mirror_left": 0.0, "body_front": 0.6})
	assert_eq(loaded.stats["runs"], 7)
	assert_eq(typeof(loaded.money), TYPE_INT, "JSON floats become ints again")
	assert_eq(loaded.to_dict(), save.to_dict())


func test_from_empty_dict_is_a_valid_new_game() -> void:
	var loaded := SaveData.from_dict({})
	assert_eq(loaded.to_dict(), SaveData.new_game().to_dict())


func test_negative_money_and_stats_are_clamped() -> void:
	var loaded := SaveData.from_dict({"money": -500, "stats": {"runs": -3}})
	assert_eq(loaded.money, 0)
	assert_eq(loaded.stats["runs"], 0)


func test_unknown_buses_are_dropped_and_starter_restored() -> void:
	var loaded := SaveData.from_dict({"owned": {"zeppelin": {}, "city": {}}})
	assert_false(loaded.owns("zeppelin"))
	assert_true(loaded.owns("city"))
	assert_true(loaded.owns(Catalog.STARTER_BUS))


func test_selection_falls_back_when_invalid() -> void:
	var loaded := SaveData.from_dict({"selected_bus": "coach", "selected_map": "atlantis"})
	assert_eq(loaded.selected_bus, Catalog.STARTER_BUS, "can't select a bus you don't own")
	assert_eq(loaded.selected_map, Maps.ids()[0])


func test_owned_bus_fields_are_sanitized() -> void:
	var raw := {
		"upgrades": {"top_speed": 99, "brakes": -2, "warp_drive": 3},
		"paints": ["ocean", "plaid", "ocean"],
		"paint": "plaid",
		"damage": {"body_front": 7.0, "mirror_left": -1},
	}
	var loaded := SaveData.from_dict({"owned": {"minibus": raw}})
	assert_eq(loaded.upgrade_level("minibus", Catalog.Upgrade.TOP_SPEED), Catalog.MAX_UPGRADE_LEVEL)
	assert_eq(loaded.upgrade_level("minibus", Catalog.Upgrade.BRAKES), 0)
	assert_false(loaded.owned["minibus"]["upgrades"].has("warp_drive"))
	assert_eq(loaded.owned["minibus"]["owned_cosmetics"]["paint"], ["stock", "ocean"])
	assert_eq(loaded.paint("minibus"), "stock", "unowned paint not applied")
	assert_eq(loaded.damage("minibus"), {"body_front": 1.0, "mirror_left": 0.0})


func test_wrong_types_do_not_crash() -> void:
	var loaded := SaveData.from_dict(
		{"owned": "lots", "stats": [], "money": "12", "selected_bus": 5}
	)
	assert_true(loaded.owns(Catalog.STARTER_BUS))
	assert_eq(loaded.money, 12)


func test_queries_on_unowned_bus_are_safe() -> void:
	var save := SaveData.new_game()
	assert_eq(save.upgrade_level("coach", Catalog.Upgrade.BRAKES), 0)
	assert_eq(save.paint("coach"), "stock")
	assert_eq(save.damage("coach"), {})


func test_graphics_setting_defaults_and_round_trips() -> void:
	var save := SaveData.new_game()
	assert_eq(save.graphics(), GraphicsSettings.DEFAULT)
	save.settings["graphics"] = "ultra"
	var loaded := SaveData.from_dict(JSON.parse_string(JSON.stringify(save.to_dict())))
	assert_eq(loaded.graphics(), "ultra")


func test_unknown_graphics_preset_falls_back_to_default() -> void:
	var loaded := SaveData.from_dict({"settings": {"graphics": "insane"}})
	assert_eq(loaded.graphics(), GraphicsSettings.DEFAULT)
	assert_eq(SaveData.from_dict({"settings": 7}).graphics(), GraphicsSettings.DEFAULT)


func test_old_battery_saver_mirror_setting_migrates_to_low_graphics() -> void:
	var loaded := SaveData.from_dict({"settings": {"mirror_quality": "low"}})
	assert_eq(loaded.graphics(), "low")
	var high := SaveData.from_dict({"settings": {"mirror_quality": "high"}})
	assert_eq(high.graphics(), GraphicsSettings.DEFAULT)


func test_cosmetics_round_trip_and_sanitize() -> void:
	var save := SaveData.new_game()
	save.owned["minibus"]["owned_cosmetics"]["rims"].append("gold")
	save.owned["minibus"]["cosmetics"]["rims"] = "gold"
	var loaded := SaveData.from_dict(JSON.parse_string(JSON.stringify(save.to_dict())))
	assert_eq(loaded.cosmetic("minibus", "rims"), "gold")
	var odd := (
		SaveData
		. from_dict(
			{
				"owned":
				{
					"minibus":
					{
						"cosmetics": {"rims": "spinners", "tint": "dark", "wings": "big"},
						"owned_cosmetics": {"rims": ["spinners"], "tint": ["dark"]},
					}
				}
			}
		)
	)
	assert_eq(odd.cosmetic("minibus", "rims"), "steel", "unknown item dropped")
	assert_eq(odd.cosmetic("minibus", "tint"), "dark", "valid owned item kept")
	assert_false(odd.owned["minibus"]["cosmetics"].has("wings"))


func test_old_paint_fields_migrate_into_cosmetics() -> void:
	var old := {"owned": {"minibus": {"paint": "ocean", "paints": ["stock", "ocean"]}}}
	var loaded := SaveData.from_dict(old)
	assert_eq(loaded.paint("minibus"), "ocean")
	assert_true(loaded.owns_cosmetic("minibus", "paint", "ocean"))
	assert_eq(loaded.cosmetic("minibus", "stripe"), "none")


func test_indicator_setting_defaults_to_manual_and_round_trips() -> void:
	var save := SaveData.new_game()
	assert_false(save.auto_indicators())
	save.settings["indicators"] = "auto"
	var loaded := SaveData.from_dict(JSON.parse_string(JSON.stringify(save.to_dict())))
	assert_true(loaded.auto_indicators())


func test_unknown_indicator_mode_falls_back_to_manual() -> void:
	var loaded := SaveData.from_dict({"settings": {"indicators": "telepathic"}})
	assert_eq(loaded.settings["indicators"], "manual")
	assert_false(SaveData.from_dict({"settings": {"graphics": "low"}}).auto_indicators())
